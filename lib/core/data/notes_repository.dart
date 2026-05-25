import 'dart:async';

import 'package:flutter/material.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/data/app_settings_repository.dart';
import 'package:notepad/core/services/repo_services/backup_sync_service.dart';
import 'package:notepad/core/services/repo_services/index_cache_service.dart';
import 'package:notepad/core/services/repo_services/note_sort_service.dart';
import 'package:notepad/core/services/repo_services/pin_operations_service.dart';
import 'package:notepad/core/services/repo_services/recycle_operations_service.dart';
import 'package:notepad/core/services/repo_services/seed_data_service.dart';
import 'package:notepad/core/services/repo_services/selection_service.dart';
import 'package:notepad/core/services/storage_service.dart' as db;

/// ------------------------------------------------------------
/// NOTE REPOSITORY (Pure Data Engine)
/// Strictly manages CRUD operations, lists, and topological states.
/// ------------------------------------------------------------
class NoteRepository extends ChangeNotifier {
  factory NoteRepository() => _instance;
  NoteRepository._internal();
  static final NoteRepository _instance = NoteRepository._internal();

  @visibleForTesting
  NoteRepository.internalForTesting();

  final List<NotesSection> _activeNotes = [];
  final List<NotesSection> _deletedNotes = [];

  Map<String, int>? _activeIndexCache;
  final Map<String, NotesSection> _pendingPinnedWrites = {};

  final ValueNotifier<int> activeRevision = ValueNotifier(0);
  final ValueNotifier<int> deletedRevision = ValueNotifier(0);
  final ValueNotifier<int> pinnedRevision = ValueNotifier(0);
  final ValueNotifier<int> colorRevision = ValueNotifier(0);

  void _notifyActiveChanged({
    String? removedId,
    int? removedAtIndex,
    int? insertedAtIndex,
  }) {
    if (_activeIndexCache != null) {
      if (removedId != null && removedAtIndex != null) {
        IndexCacheService.removeEntry(_activeIndexCache!, removedId);
        IndexCacheService.shiftIndicesFrom(
          _activeIndexCache!,
          _activeNotes,
          removedAtIndex,
        );
      } else if (insertedAtIndex != null) {
        IndexCacheService.shiftIndicesFrom(
          _activeIndexCache!,
          _activeNotes,
          insertedAtIndex,
        );
      } else {
        _activeIndexCache = null;
        IndexCacheService.buildCacheInBackground(
          _activeNotes,
        ).then((newCache) => _activeIndexCache = newCache);
      }
    } else {
      IndexCacheService.buildCacheInBackground(
        _activeNotes,
      ).then((newCache) => _activeIndexCache = newCache);
    }
    activeRevision.value++;
  }

  List<NotesSection> get activeNotes => List.unmodifiable(_activeNotes);
  List<NotesSection> get deletedNotes => List.unmodifiable(_deletedNotes);

  // Stops checking the instant it hits an unpinned note (Massively faster)
  List<NotesSection> get pinnedNotes {
    // Assert that we never hit an unpinned note while pinning
    assert(
      _activeNotes.isEmpty ||
          !_activeNotes.any((n) => n.isPinned) ||
          _activeNotes.first.isPinned == true,
      "List not sorted!",
    );
    return _activeNotes.takeWhile((n) => n.isPinned).toList();
  }

  // Skips the pinned notes we already know about
  List<NotesSection> get unpinnedNotes =>
      _activeNotes.skipWhile((n) => n.isPinned).toList();

  static const int _currentSeedVersion = 1;

  Future<void> init() async {
    _activeNotes.clear();
    _deletedNotes.clear();

    final int installedSeedVersion = appSettingsRepository.settings.seedVersion;

    if (installedSeedVersion != _currentSeedVersion) {
      debugPrint('Migration: Resetting stale data...');
      await db.clearAllNotes();
      _activeNotes.addAll(SeedDataService.generateWelcomeNotes());
      await db.saveNotesBulk({for (var n in _activeNotes) n.id: n});
      await appSettingsRepository.setSeedVersion(_currentSeedVersion);
    } else {
      for (final note in db.loadAllNotes()) {
        note.isDeleted ? _deletedNotes.add(note) : _activeNotes.add(note);
      }
    }

    _sortAll();
    IndexCacheService.buildCacheInBackground(
      _activeNotes,
    ).then((c) => _activeIndexCache = c);

    final lastRun = appSettingsRepository.settings.lastMaintenanceDate;
    final now = DateTime.now();

    if (lastRun == null || now.difference(lastRun).inDays >= 7) {
      debugPrint(
        'Maintenance: 7-day timeline reached. Running Hive compaction...',
      );

      try {
        await db.performMaintenance(); // This triggers _notesBox.compact()
        await appSettingsRepository
            .recordMaintenanceCompleted(); // Reset the clock
      } catch (e) {
        debugPrint('Maintenance failed, will retry next launch: $e');
      }
    }
  }

  NotesSection? findById(String id) => db.getNoteById(id);

  int getActiveIndex(String id) {
    _activeIndexCache ??= IndexCacheService.buildCacheOnMainThread(
      _activeNotes,
    );
    return _activeIndexCache![id] ?? -1;
  }

  // Pinned local index matches global index exactly because they live at the start
  int getPinnedLocalIndex(String id) => getActiveIndex(id);

  // Unpinned local index subtracts the pinned count to normalize back to 0
  int getUnpinnedLocalIndex(String id) {
    final int globalIndex = getActiveIndex(id);
    if (globalIndex == -1) return -1;

    // Subtract the number of pinned notes to calculate the true local sub-list index
    return globalIndex - pinnedNotes.length;
  }

  void reorderPinnedNotes(int oldIndex, int newIndex) =>
      _reorderZone(pinnedNotes, oldIndex, newIndex);
  void reorderUnpinnedNotes(int oldIndex, int newIndex) =>
      _reorderZone(unpinnedNotes, oldIndex, newIndex);

  Future<void> _reorderZone(
    List<NotesSection> zoneList,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex < 0 || oldIndex >= zoneList.length || oldIndex == newIndex) {
      return;
    }

    final movingNote = zoneList.removeAt(oldIndex);
    zoneList.insert(newIndex, movingNote);

    final Map<String, NotesSection> bulkUpdates = {};
    for (int i = 0; i < zoneList.length; i++) {
      zoneList[i].positionIndex = i;
      bulkUpdates[zoneList[i].id] = zoneList[i];
    }

    _sortAll();
    _notifyActiveChanged();
    try {
      await db.saveNotesBulk(bulkUpdates);
    } catch (e) {
      debugPrint("Reorder Save Error: $e");
    }
  }

  /*
  Future<void> _reorderZone(List<NotesSection> zoneList, int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= zoneList.length || oldIndex == newIndex) return;

    // 1. Get the actual global indices in _activeNotes before moving
    final globalOldIndex = _activeNotes.indexOf(zoneList[oldIndex]);
    
    // 2. Move the item in the sub-zone
    final movingNote = zoneList.removeAt(oldIndex);
    zoneList.insert(newIndex, movingNote);

    // 3. Move the item in the global active list
    _activeNotes.removeAt(globalOldIndex);
    final globalNewIndex = _activeNotes.indexOf(zoneList[newIndex]);
    _activeNotes.insert(globalNewIndex, movingNote);

    // 4. Update the position variables
    final Map<String, NotesSection> bulkUpdates = {};
    for (int i = 0; i < zoneList.length; i++) {
      zoneList[i].positionIndex = i;
      bulkUpdates[zoneList[i].id] = zoneList[i];
    }

    // 5. 🔥 SURGICAL CACHE PATCH: No _sortAll() or background isolates needed!
    if (_activeIndexCache != null) {
      final lowestImpactedIndex = globalOldIndex < globalNewIndex ? globalOldIndex : globalNewIndex;
      IndexCacheService.shiftIndicesFrom(_activeIndexCache!, _activeNotes, lowestImpactedIndex);
    }
    activeRevision.value++;

    try {
      await db.saveNotesBulk(bulkUpdates);
    } catch (e) {
      debugPrint("Reorder Save Error: $e");
    }
  }
  */

  void _sortAll() {
    NoteSortService.sortActiveNotes(_activeNotes);
    NoteSortService.sortDeletedNotes(_deletedNotes);
  }

  Future<NotesSection?> saveNote({
    required String? noteId,
    required String title,
    required String content,
    String richContent = '',
    final bool notify = false,
  }) async {
    final existingNote = noteId == null ? null : findById(noteId);
    final now = DateTime.now();

    if (existingNote != null) {
      existingNote
        ..title = title
        ..content = content
        ..richContent = richContent
        ..updatedAt = now;

      if (notify) {
        NoteSortService.sortActiveNotes(_activeNotes);
        _activeIndexCache = null;
        activeRevision.value++;
      }

      unawaited(
        db
            .saveNote(existingNote)
            .catchError((e) => debugPrint("Disk Write Error: $e")),
      );
      return existingNote;
    }

    final newNote = NotesSection(
      title: title,
      content: content,
      richContent: richContent,
      createdAt: now,
      updatedAt: now,
    );

    if (notify) {
      final landingIndex = NoteSortService.insertSorted(_activeNotes, newNote);
      _notifyActiveChanged(insertedAtIndex: landingIndex);
    }

    unawaited(
      db
          .saveNote(newNote)
          .catchError((e) => debugPrint("Disk Write Error: $e")),
    );
    return newNote;
  }

  Future<bool> toggleDeletedStatus(String noteId, bool isDeleted) async {
    final note = findById(noteId);
    if (note == null) return false;

    final now = DateTime.now();
    note
      ..isDeleted = isDeleted
      ..updatedAt = now;

    if (isDeleted) {
      final index = getActiveIndex(noteId);
      if (index != -1) {
        _activeNotes.removeAt(index);
        _notifyActiveChanged(removedId: noteId, removedAtIndex: index);
      }
      //  else {
      //   _activeNotes.remove(note);
      //   _notifyActiveChanged();
      // }
      _deletedNotes.add(note);
      deletedRevision.value++;
    } else {
      _deletedNotes.remove(note);
      deletedRevision.value++;

      final int landingIndex = NoteSortService.insertSorted(_activeNotes, note);
      _notifyActiveChanged(insertedAtIndex: landingIndex);
    }

    unawaited(db.saveNote(note));
    return true;
  }

  Future<void> toggleDeletedStatusBulk(
    Set<String> noteIds,
    bool isDeleted,
  ) async {
    if (noteIds.isEmpty) return;

    final result = RecycleOperationsService.processBulkMove(
      currentActive: _activeNotes,
      currentDeleted: _deletedNotes,
      targetIds: noteIds,
      toDelete: isDeleted,
    );

    _sortAll();
    _notifyActiveChanged();

    await db.saveNotesBulk(result.dbUpdates);
  }

  Future<void> deleteForever(String noteId) async {
    final note = findById(noteId);
    if (note == null) return;

    _deletedNotes.remove(note);
    deletedRevision.value++;

    await db.deleteNote(noteId);
  }

  Future<void> deleteForeverBulk(Set<String> noteIds) async {
    if (noteIds.isEmpty) return;

    _deletedNotes.removeWhere((note) => noteIds.contains(note.id));
    deletedRevision.value++;
    await db.deleteNotesBulk(noteIds);
  }

  Future<void> togglePinStatus(String noteId) async {
    final note = findById(noteId);
    if (note == null) return;

    // 1. Capture the old location BEFORE changing its status
    final oldIndex = getActiveIndex(noteId);

    note.isPinned = !note.isPinned;
    note.updatedAt = DateTime.now();

    if (oldIndex != -1) {
      // 2. SURGICAL MOVE: Yank it out and drop it in the new sorted slot
      _activeNotes.removeAt(oldIndex);
      final newIndex = NoteSortService.insertSorted(_activeNotes, note);

      // 3. SURGICAL CACHE PATCH: Shift only the affected index range instantly
      if (_activeIndexCache != null) {
        final lowestImpactedIndex = oldIndex < newIndex ? oldIndex : newIndex;
        IndexCacheService.shiftIndicesFrom(
          _activeIndexCache!,
          _activeNotes,
          lowestImpactedIndex,
        );
      }
      // Notify the UI to redraw the lists
      activeRevision.value++;
    } else {
      // Fallback just in case the cache was completely out of sync
      _activeNotes.remove(note);
      NoteSortService.insertSorted(_activeNotes, note);
      _notifyActiveChanged();
    }

    unawaited(db.saveNote(note));
  }

  Future<void> togglePinBulk(Set<String> noteIds, bool goalState) async {
    if (noteIds.isEmpty) return;

    // 1. Delegate the heavy logic to the service
    final dbUpdates = PinOperationsService.processBulkPin(
      activeNotes: _activeNotes,
      targetIds: noteIds,
      goalState: goalState,
      currentPinnedCount: pinnedNotes.length,
    );

    // 2. Orchestrate the UI and Cache
    _sortAll();
    _notifyActiveChanged();

    // 3. Write directly to the database
    await db.saveNotesBulk(dbUpdates);
  }

  Future<void> flushPendingPinnedWrites() async {
    if (_pendingPinnedWrites.isEmpty) return;
    await db.saveNotesBulk(_pendingPinnedWrites);
    _pendingPinnedWrites.clear();
  }

  void updateColorsBulk(Set<String> noteIds, Color color) {
    SelectionService.applyColorToSelection(
      selectedIds: noteIds,
      allNotes: _activeNotes,
      newColor: color,
    );
    activeRevision.value++;
  }

  void restoreColors(Map<String, Color> originalColors) {
    originalColors.forEach((id, color) {
      final note = findById(id);
      if (note != null) note.cardColor = color;
    });
    activeRevision.value++;
  }

  Future<void> saveColorsBulk(Set<String> noteIds) async {
    final entries = {
      for (final id in noteIds)
        if (findById(id) != null) id: findById(id)!,
    };
    await db.saveNotesBulk(entries);
  }

  Future<String> exportNotesToBackupString() async {
    if (_activeNotes.isEmpty) return "";
    try {
      return await db.exportNotesToJSON(_activeNotes);
    } catch (e) {
      debugPrint('Export failed: $e');
      return "";
    }
  }

  Future<void> importNotesFromBackupString(String jsonString) async {
    List<NotesSection> importedNotes;

    try {
      importedNotes = await db.importNotesFromJSON(jsonString);
    } catch (e) {
      throw const FormatException('Invalid backup format or corrupted data.');
    }

    if (importedNotes.isEmpty) {
      throw const FormatException('Backup contains no valid notes.');
    }

    final updates = BackupSyncService.calculateImportUpdates(
      cloudNotes: importedNotes,
      localNoteLookup: findById,
    );

    if (updates.isNotEmpty) {
      _activeNotes.addAll(updates.values);
      _sortAll();
      _notifyActiveChanged();
      await db.saveNotesBulk(updates);
    }
  }
}

final NoteRepository noteRepository = NoteRepository();
