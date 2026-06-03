// Repository logic keeps active, deleted, and cached note views in sync.
import 'dart:async';
import 'package:notepad/core/database/sqlite_fts_service.dart';
import 'package:flutter/material.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/app_settings_repository.dart';
import 'package:notepad/core/services/repo_services/backup_sync_service.dart';
import 'package:notepad/core/services/repo_services/note_sort_service.dart';
import 'package:notepad/core/services/repo_services/pin_operations_service.dart';
import 'package:notepad/core/services/repo_services/recycle_operations_service.dart';
import 'package:notepad/core/services/repo_services/seed_data_service.dart';
import 'package:notepad/core/database/storage_service.dart' as db;

class NoteRepository {
  factory NoteRepository() => _instance;
  NoteRepository._internal();
  static final NoteRepository _instance = NoteRepository._internal();

  @visibleForTesting
  NoteRepository.internalForTesting();

  final List<NotesSection> _activeNotes = [];
  final List<NotesSection> _deletedNotes = [];

  // Fast lookup cache for reads and cross-feature updates.
  final Map<String, NotesSection> _cacheMap = {};

  // These slices stay cached so list widgets do not rebuild them repeatedly.
  List<NotesSection> _cachedPinnedNotes = [];
  List<NotesSection> _cachedUnpinnedNotes = [];

  final ValueNotifier<int> activeRevision = ValueNotifier(0);
  final ValueNotifier<int> deletedRevision = ValueNotifier(0);

  List<NotesSection> get activeNotes => List.unmodifiable(_activeNotes);
  List<NotesSection> get deletedNotes => List.unmodifiable(_deletedNotes);

  List<NotesSection> get pinnedNotes => _cachedPinnedNotes;
  List<NotesSection> get unpinnedNotes => _cachedUnpinnedNotes;

  static const int _currentSeedVersion = 1;

  Future<void> init() async {
    _activeNotes.clear();
    _deletedNotes.clear();
    _cacheMap.clear();

    final int installedSeedVersion = appSettingsRepository.settings.seedVersion;

    if (installedSeedVersion != _currentSeedVersion) {
      // Replace stale seeded content rather than trying to migrate it in place.
      debugPrint('Migration: Resetting stale data...');
      await db.clearAllNotes();
      final welcomeNotes = SeedDataService.generateWelcomeNotes();

      for (int i = 0; i < welcomeNotes.length; i++) {
        welcomeNotes[i].positionIndex = i;
      }
      _activeNotes.addAll(welcomeNotes);

      for (final note in _activeNotes) {
        _cacheMap[note.id] = note;
        await SqliteFtsService.insertOrUpdate(
          note.id,
          note.title,
          note.content,
        );
      }

      await db.saveNotesBulk({for (var n in _activeNotes) n.id: n});
      await appSettingsRepository.setSeedVersion(_currentSeedVersion);
    } else {
      for (final note in db.loadAllNotes()) {
        _cacheMap[note.id] = note;
        note.isDeleted ? _deletedNotes.add(note) : _activeNotes.add(note);

        // Deleted notes stay out of FTS so search only scans active content.
        if (!note.isDeleted) {
          await SqliteFtsService.insertOrUpdate(
            note.id,
            note.title,
            note.content,
          );
        }
      }
    }

    // Rebuild the derived lists after the active/deleted split is loaded.
    _sortAndRebuildCache();

    final lastRun = appSettingsRepository.settings.lastMaintenanceDate;
    final now = DateTime.now();

    if (lastRun == null || now.difference(lastRun).inDays >= 7) {
      // Compact and record maintenance on a weekly cadence to keep storage healthy.
      debugPrint(
        'Maintenance: 7-day timeline reached. Running Hive compaction...',
      );
      try {
        await db.performMaintenance();
        await appSettingsRepository.recordMaintenanceCompleted();
      } catch (e) {
        debugPrint('Maintenance failed, will retry next launch: $e');
      }
    }
  }

  NotesSection? findById(String id) => _cacheMap[id] ?? db.getNoteById(id);

  void reorderPinnedNotes(int oldIndex, int newIndex) =>
      _reorderZone(pinnedNotes.toList(), oldIndex, newIndex, true);
  void reorderUnpinnedNotes(int oldIndex, int newIndex) =>
      _reorderZone(unpinnedNotes.toList(), oldIndex, newIndex, false);

  Future<void> _reorderZone(
    List<NotesSection> zoneList,
    int oldIndex,
    int newIndex,
    final bool pinnedZone,
  ) async {
    if (oldIndex < 0 || oldIndex >= zoneList.length || oldIndex == newIndex) {
      return;
    }

    final bulkUpdates = NoteSortService.reorderZone(
      activeNotes: _activeNotes,
      zoneList: zoneList,
      oldIndex: oldIndex,
      newIndex: newIndex,
      pinnedCount: _cachedPinnedNotes.length,
      isPinnedZone: pinnedZone,
    );

    _sortAndRebuildCache();
    activeRevision.value++;

    try {
      await db.saveNotesBulk(bulkUpdates);
    } catch (e) {
      debugPrint("Reorder Save Error: $e");
    }
  }

  void _sortAndRebuildCache() {
    // Sorting is centralized here so every derived view stays consistent.
    NoteSortService.sortActiveNotes(_activeNotes);

    _cachedPinnedNotes = List.unmodifiable(
      _activeNotes.takeWhile((n) => n.isPinned),
    );
    _cachedUnpinnedNotes = List.unmodifiable(
      _activeNotes.skipWhile((n) => n.isPinned),
    );
  }

  void _rebuildSubListPointersOnly() {
    // Use this when ordering already changed and only the cached slices need refresh.
    _cachedPinnedNotes = List.unmodifiable(
      _activeNotes.takeWhile((n) => n.isPinned),
    );
    _cachedUnpinnedNotes = List.unmodifiable(
      _activeNotes.skipWhile((n) => n.isPinned),
    );
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
        activeRevision.value++;
      }

      unawaited(
        db
            .saveNote(existingNote)
            .catchError((e) => debugPrint("Disk Write Error: $e")),
      );

      await SqliteFtsService.insertOrUpdate(existingNote.id, title, content);
      return existingNote;
    }

    final int topUnpinnedIndex = _cachedUnpinnedNotes.isNotEmpty
        ? _cachedUnpinnedNotes.first.positionIndex - 1
        : 0;

    // New notes are inserted ahead of the first unpinned note to preserve ordering.
    final newNote = NotesSection(
      title: title,
      content: content,
      richContent: richContent,
      createdAt: now,
      updatedAt: now,
      positionIndex: topUnpinnedIndex,
    );

    _cacheMap[newNote.id] = newNote;
    await SqliteFtsService.insertOrUpdate(newNote.id, title, content);
    NoteSortService.insertSorted(_activeNotes, newNote);

    _rebuildSubListPointersOnly();
    if (notify) {
      activeRevision.value++;
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
      // Deleted notes leave the active list and stop participating in search.
      _activeNotes.remove(note);
      NoteSortService.insertSorted(_deletedNotes, note);
      await SqliteFtsService.remove(noteId);
    } else {
      // Restoring puts the note back into the active ordering and search index.
      _deletedNotes.remove(note);
      NoteSortService.insertSorted(_activeNotes, note);
      await SqliteFtsService.insertOrUpdate(note.id, note.title, note.content);
    }

    _rebuildSubListPointersOnly();

    activeRevision.value++;
    deletedRevision.value++;

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

    _sortAndRebuildCache();
    NoteSortService.sortDeletedNotes(_deletedNotes);
    activeRevision.value++;

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

    note.isPinned = !note.isPinned;
    note.updatedAt = DateTime.now();

    _sortAndRebuildCache();
    activeRevision.value++;

    unawaited(db.saveNote(note));
  }

  Future<void> togglePinBulk(Set<String> noteIds, bool goalState) async {
    if (noteIds.isEmpty) return;

    final dbUpdates = PinOperationsService.processBulkPin(
      activeNotes: _activeNotes,
      targetIds: noteIds,
      goalState: goalState,
      currentPinnedCount: pinnedNotes.length,
    );

    _sortAndRebuildCache();
    activeRevision.value++;

    await db.saveNotesBulk(dbUpdates);
  }

  void applyColorToSelection(Set<String> selectedIds, Color newColor) {
    for (final id in selectedIds) {
      findById(id)?.cardColor = newColor;
    }
  }

  void restoreColors(Map<String, Color> originalColors) {
    for (final entry in originalColors.entries) {
      findById(entry.key)?.cardColor = entry.value;
    }
  }

  Future<void> saveColorsBulk(Set<String> noteIds) async {
    final Map<String, NotesSection> entries = {};

    for (final id in noteIds) {
      final note = findById(id);
      if (note != null) {
        entries[id] = note;
      }
    }

    if (entries.isNotEmpty) {
      await db.saveNotesBulk(entries);
    }
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

      for (final note in updates.values) {
        _cacheMap[note.id] = note;
      }

      _sortAndRebuildCache();
      activeRevision.value++;
      await db.saveNotesBulk(updates);
    }
  }
}

final NoteRepository noteRepository = NoteRepository();
