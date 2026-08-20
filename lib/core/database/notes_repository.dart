import 'dart:async';

import 'package:flutter/material.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/app_settings_repository.dart';
import 'package:notepad/core/database/sqlite_fts_service.dart';
import 'package:notepad/core/database/storage_service.dart';
import 'package:notepad/core/services/repo_services/backup_sync_service.dart';
import 'package:notepad/core/services/repo_services/note_sort_service.dart';
import 'package:notepad/core/services/repo_services/notes_initialization_service.dart';
import 'package:notepad/core/services/repo_services/pin_operations_service.dart';
import 'package:notepad/core/services/repo_services/recycle_operations_service.dart';

// Manages the core note data lifecycle, ensuring atomic state synchronization
// across memory, Hive storage, and SQLite search indices.
class NoteRepository {
  factory NoteRepository({
    StorageServiceApi? storageService,
    SqliteFtsServiceApi? sqliteFtsService,
    AppSettingsRepository? settingsRepository,
  }) {
    if (storageService == null &&
        sqliteFtsService == null &&
        settingsRepository == null) {
      return _instance;
    }

    return NoteRepository.internalForTesting(
      storageService: storageService,
      sqliteFtsService: sqliteFtsService,
      settingsRepository: settingsRepository,
    );
  }

  NoteRepository._internal({
    StorageServiceApi? storageService,
    SqliteFtsServiceApi? sqliteFtsService,
    AppSettingsRepository? settingsRepository,
  })  : _storageService = storageService ?? StorageService.to,
        _sqliteFtsService = sqliteFtsService ?? SqliteFtsService.to,
        _appSettingsRepository = settingsRepository ?? appSettingsRepository;

  static final NoteRepository _instance = NoteRepository._internal();

  @visibleForTesting
  NoteRepository.internalForTesting({
    StorageServiceApi? storageService,
    SqliteFtsServiceApi? sqliteFtsService,
    AppSettingsRepository? settingsRepository,
  }) : this._internal(
          storageService: storageService,
          sqliteFtsService: sqliteFtsService,
          settingsRepository: settingsRepository,
        );

  final StorageServiceApi _storageService;
  final SqliteFtsServiceApi _sqliteFtsService;
  final AppSettingsRepository _appSettingsRepository;

  final List<NotesSection> _activeNotes = [];
  final List<NotesSection> _deletedNotes = [];

  // Fast lookup cache for reads and cross-feature state updates.
  final Map<String, NotesSection> _cacheMap = {};

  // These slices stay cached so list widgets do not rebuild them repeatedly.
  List<NotesSection> _cachedPinnedNotes = [];
  List<NotesSection> _cachedUnpinnedNotes = [];

  List<NotesSection> get activeNotes => List.unmodifiable(_activeNotes);
  List<NotesSection> get deletedNotes => List.unmodifiable(_deletedNotes);

  List<NotesSection> get pinnedNotes => _cachedPinnedNotes;
  List<NotesSection> get unpinnedNotes => _cachedUnpinnedNotes;

  final ValueNotifier<int> activeRevision = ValueNotifier(0);
  final ValueNotifier<int> deletedRevision = ValueNotifier(0);

  static const int _currentSeedVersion = 1;

  Future<void> init() async {
    final result = await NotesInitializationService.initializeData(
      installedSeedVersion: _appSettingsRepository.settings.seedVersion,
      currentSeedVersion: _currentSeedVersion,
    );

    _activeNotes
      ..clear()
      ..addAll(result.activeNotes);

    _deletedNotes
      ..clear()
      ..addAll(result.deletedNotes);

    _cacheMap
      ..clear()
      ..addAll(result.cacheMap);

    _sortAndRebuildCache();

    await NotesInitializationService.runMaintenanceTasks();
  }

  NotesSection? findById(String id) =>
      _cacheMap[id] ?? _storageService.getNoteById(id);

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
      await _storageService.saveNotesBulk(bulkUpdates);
    } catch (e) {
      debugPrint('Reorder Save Error: $e');
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
    double scrollOffset = 0.0,
  }) async {
    final existingNote = noteId == null ? null : findById(noteId);
    final now = DateTime.now();

    if (existingNote != null) {
      existingNote
        ..title = title
        ..content = content
        ..richContent = richContent
        ..updatedAt = now
        ..scrollOffset = scrollOffset;

      if (notify) {
        activeRevision.value++;
      }

      unawaited(
        _storageService
            .saveNote(existingNote)
            .catchError((e) => debugPrint('Disk Write Error: $e')),
      );

      await _sqliteFtsService.insertOrUpdate(existingNote);
      return existingNote;
    }

    // New notes are inserted ahead of the first unpinned note to preserve ordering.
    final int topUnpinnedIndex = _cachedUnpinnedNotes.isNotEmpty
        ? _cachedUnpinnedNotes.first.positionIndex - 1
        : 0;

    final newNote = NotesSection(
      title: title,
      content: content,
      richContent: richContent,
      updatedAt: now,
      positionIndex: topUnpinnedIndex,
    )..scrollOffset = scrollOffset;

    _cacheMap[newNote.id] = newNote;
    await _sqliteFtsService.insertOrUpdate(newNote);

    // Optimization: New notes always start at the beginning of the "Others" section.
    // By passing the pinned count as the index, we skip the linear search.
    NoteSortService.insertSorted(
      _activeNotes,
      newNote,
      atIndex: _cachedPinnedNotes.length,
    );

    _rebuildSubListPointersOnly();
    if (notify) {
      activeRevision.value++;
    }

    unawaited(
      _storageService
          .saveNote(newNote)
          .catchError((e) => debugPrint('Disk Write Error: $e')),
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
      _activeNotes.remove(note);
      _deletedNotes.insert(0, note);
      await _sqliteFtsService.remove(noteId);
    } else {
      _deletedNotes.remove(note);
      NoteSortService.insertSorted(_activeNotes, note);
      await _sqliteFtsService.insertOrUpdate(note);
    }

    _rebuildSubListPointersOnly();
    activeRevision.value++;
    deletedRevision.value++;

    unawaited(_storageService.saveNote(note));
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

    await _storageService.saveNotesBulk(result.dbUpdates);

    // SQL Index Sync (Batch)
    if (isDeleted) {
      await _sqliteFtsService.removeBulk(noteIds);
    } else {
      await _sqliteFtsService.insertOrUpdateBulk(
        result.dbUpdates.values.toList(),
      );
    }
  }

  Future<void> deleteForever(String noteId) async {
    final note = findById(noteId);
    if (note == null) return;

    _deletedNotes.remove(note);
    deletedRevision.value++;

    await _storageService.deleteNote(noteId);
  }

  Future<void> deleteForeverBulk(Set<String> noteIds) async {
    if (noteIds.isEmpty) return;

    _deletedNotes.removeWhere((n) => noteIds.contains(n.id));
    noteIds.forEach(_cacheMap.remove);

    deletedRevision.value++;
    await _storageService.deleteNotesBulk(noteIds);
  }

  Future<void> togglePinStatus(String noteId) async {
    final note = findById(noteId);
    if (note == null) return;

    PinOperationsService.togglePinState(note);

    _sortAndRebuildCache();
    activeRevision.value++;

    unawaited(_storageService.saveNote(note));
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

    await _storageService.saveNotesBulk(dbUpdates);
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
      if (findById(id) case final note?) entries[id] = note;
    }

    if (entries.isNotEmpty) await _storageService.saveNotesBulk(entries);
  }

  Future<(int, String)> exportNotesToBackupString() async {
    if (_activeNotes.isEmpty) return (0, '');
    try {
      final jsonString = await _storageService.exportNotesToJSON(_activeNotes);

      return (_activeNotes.length, jsonString);
    } catch (e) {
      debugPrint('Export failed: $e');
      return (0, '');
    }
  }

  Future<(int restored, int skipped)> importNotesFromBackupString(
    String jsonString,
  ) async {
    List<NotesSection> importedNotes;

    try {
      importedNotes = await _storageService.importNotesFromJSON(jsonString);
    } catch (e) {
      throw const FormatException('Invalid backup format or corrupted data.');
    }

    if (importedNotes.isEmpty) {
      throw const FormatException('Backup contains no valid notes.');
    }

    final result = BackupSyncService.calculateImportUpdates(
      cloudNotes: importedNotes,
      localNoteLookup: findById,
    );

    if (result.updates.isNotEmpty) {
      _activeNotes.addAll(result.updates.values);

      for (final note in result.updates.values) {
        _cacheMap[note.id] = note;
      }

      _sortAndRebuildCache();
      activeRevision.value++;

      await _storageService.saveNotesBulk(result.updates);
      await _sqliteFtsService.reindexAllNotes(_activeNotes);
    }

    return (result.updates.length, result.skippedCount);
  }
}

final NoteRepository noteRepository = NoteRepository();
