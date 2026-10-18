import 'dart:async';

import 'package:flutter/material.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/app_settings_repository.dart';
import 'package:notepad/core/database/sqlite_fts.dart';
import 'package:notepad/core/database/storage_service.dart';
import 'package:notepad/core/database/vector_storage.dart';
import 'package:notepad/core/services/repo_services/backup_sync.dart';
import 'package:notepad/core/services/repo_services/notes_initialization.dart';
import 'package:notepad/core/services/repo_services/notes_sort.dart';
import 'package:notepad/core/services/repo_services/pin_operations.dart';
import 'package:notepad/core/services/repo_services/recycle_operations.dart';
import 'package:notepad/core/services/search_indexer.dart';
import 'package:notepad/core/services/ui_management/scaffold_messenger_notifier.dart';

// Manages the core note data lifecycle, ensuring atomic state synchronization
// across memory, Hive storage, and SQLite search indices.
class NoteRepository {
  factory NoteRepository({
    StorageServiceApi? storageService,
    SqliteFtsServiceApi? sqliteFtsService,
    AppSettingsRepository? settingsRepository,
    SearchIndexerApi? searchIndexer,
  }) {
    if (storageService == null &&
        sqliteFtsService == null &&
        settingsRepository == null &&
        searchIndexer == null) {
      return _instance;
    }

    return NoteRepository.internalForTesting(
      storageService: storageService,
      sqliteFtsService: sqliteFtsService,
      settingsRepository: settingsRepository,
      searchIndexer: searchIndexer,
    );
  }

  NoteRepository._internal({
    StorageServiceApi? storageService,
    SqliteFtsServiceApi? sqliteFtsService,
    AppSettingsRepository? settingsRepository,
    SearchIndexerApi? searchIndexer,
  }) : _storageService = storageService ?? StorageService.to,
       _sqliteFtsService = sqliteFtsService ?? SqliteFtsService.to,
       _appSettingsRepository = settingsRepository ?? appSettingsRepository,
       _searchIndexerOverride = searchIndexer;

  static final NoteRepository _instance = NoteRepository._internal();

  @visibleForTesting
  NoteRepository.internalForTesting({
    StorageServiceApi? storageService,
    SqliteFtsServiceApi? sqliteFtsService,
    AppSettingsRepository? settingsRepository,
    SearchIndexerApi? searchIndexer,
  }) : this._internal(
         storageService: storageService,
         sqliteFtsService: sqliteFtsService,
         settingsRepository: settingsRepository,
         searchIndexer: searchIndexer,
       );

  final StorageServiceApi _storageService;
  final SqliteFtsServiceApi _sqliteFtsService;
  final AppSettingsRepository _appSettingsRepository;
  final SearchIndexerApi? _searchIndexerOverride;
  SearchIndexerApi get _searchIndexer =>
      _searchIndexerOverride ?? SearchIndexerApi.instance;

  final List<NotesSection> _activeNotes = [];
  final List<NotesSection> _deletedNotes = [];

  // Fast lookup cache for reads and cross-feature state updates.
  final Map<String, NotesSection> _cacheMap = {};

  // These slices stay cached so list widgets do not rebuild them repeatedly.
  List<NotesSection> _cachedPinnedNotes = [];
  List<NotesSection> _cachedUnpinnedNotes = [];

  Map<String, NotesSection> get cacheMap => Map.unmodifiable(_cacheMap);
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
  }

  Future<void> runPostStartupMaintenance() async {
    await Future.wait([
      NotesInitializationService.runMaintenanceTasks(),
      _searchIndexer.rebuildIndex(_activeNotes),
    ]);
    await _searchIndexer.runMaintenanceSweep(_activeNotes);
  }

  /// Programmatically injects new seed notes at runtime for Semantic Ai model testing.
  Future<void> injectSeedNotesBulk(List<NotesSection> seedNotes) async {
    if (seedNotes.isEmpty) return;

    final now = DateTime.now();
    final Map<String, NotesSection> notesToSave = {};

    for (final note in seedNotes) {
      note.updatedAt = now;
      notesToSave[note.id] = note;
    }

    try {
      await _storageService.saveNotesBulk(notesToSave);

      _cacheMap.addAll(notesToSave);
      _activeNotes.addAll(seedNotes);
      _sortAndRebuildCache();

      await _sqliteFtsService.insertOrUpdateBulk(seedNotes);
      await _searchIndexer.indexNotesBulk(seedNotes);
    } catch (e) {
      debugPrint('Bulk inject error: $e');
      showErrorSnackBar('Failed to save seed notes to storage.');
    }
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
    bool pinnedZone,
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

    try {
      await _storageService.saveNotesBulk(bulkUpdates);
    } catch (e) {
      debugPrint('Reorder Save Error: $e');
      showErrorSnackBar('Failed to save reordered note position.');
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

    activeRevision.value++;
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

  //Triggered when user presses back from the editor page
  Future<void> triggerDeferredEmbedding(String? noteId) async {
    if (findById(noteId ?? '') case final note?) {
      _searchIndexer.triggerDeferredEmbedding(note);
    }
  }

  Future<NotesSection?> saveNote({
    required String? noteId,
    required String title,
    required String content,
    String richContent = '',
    bool notify = false,
    double scrollOffset = 0.0,
  }) async {
    final existingNote = noteId == null ? null : findById(noteId);
    final now = DateTime.now();

    if (existingNote != null) {
      final oldTitle = existingNote.title;
      final oldContent = existingNote.content;
      final oldRichContent = existingNote.richContent;
      final oldUpdatedAt = existingNote.updatedAt;
      final oldScrollOffset = existingNote.scrollOffset;

      existingNote
        ..title = title
        ..content = content
        ..richContent = richContent
        ..updatedAt = now
        ..scrollOffset = scrollOffset;

      try {
        await _storageService.saveNote(existingNote);
      } catch (e) {
        // Rollback memory state on storage failure
        existingNote
          ..title = oldTitle
          ..content = oldContent
          ..richContent = oldRichContent
          ..updatedAt = oldUpdatedAt
          ..scrollOffset = oldScrollOffset;
        debugPrint('Disk Write Error (saveNote): $e');
        showErrorSnackBar('Failed to save note. Device storage error.');
        return null;
      }

      await _sqliteFtsService.insertOrUpdate(existingNote);
      _searchIndexer.indexNote(existingNote);

      if (notify) {
        activeRevision.value++;
      }
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

    try {
      await _storageService.saveNote(newNote);
    } catch (e) {
      debugPrint('Disk Write Error (saveNote newNote): $e');
      showErrorSnackBar('Failed to create note. Device storage error.');
      return null;
    }

    _cacheMap[newNote.id] = newNote;
    await _sqliteFtsService.insertOrUpdate(newNote);
    _searchIndexer.indexNote(newNote);

    NoteSortService.insertSorted(
      _activeNotes,
      newNote,
      atIndex: _cachedPinnedNotes.length,
    );

    _rebuildSubListPointersOnly();
    if (notify) {
      activeRevision.value++;
    }

    return newNote;
  }

  Future<bool> toggleDeletedStatus(String noteId, bool isDeleted) async {
    final note = findById(noteId);
    if (note == null) return false;

    final now = DateTime.now();
    final previousIsDeleted = note.isDeleted;
    final previousUpdatedAt = note.updatedAt;

    note
      ..isDeleted = isDeleted
      ..updatedAt = now;

    try {
      await _storageService.saveNote(note);
    } catch (e) {
      note
        ..isDeleted = previousIsDeleted
        ..updatedAt = previousUpdatedAt;
      debugPrint('Disk Write Error (toggleDeletedStatus): $e');
      showErrorSnackBar('Failed to update note status.');
      return false;
    }

    if (isDeleted) {
      _activeNotes.remove(note);
      _deletedNotes.insert(0, note);
      await _sqliteFtsService.remove(noteId);
      _searchIndexer.removeNote(noteId);
    } else {
      _deletedNotes.remove(note);
      NoteSortService.insertSorted(_activeNotes, note);
      await _sqliteFtsService.insertOrUpdate(note);
      _searchIndexer.indexNote(note);
    }

    _rebuildSubListPointersOnly();
    activeRevision.value++;
    deletedRevision.value++;

    _searchIndexer.invalidateTopicCache();

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

    try {
      await _storageService.saveNotesBulk(result.dbUpdates);
    } catch (e) {
      debugPrint('Disk Write Error (toggleDeletedStatusBulk): $e');
      showErrorSnackBar('Failed to save selected notes.');
      return;
    }

    _sortAndRebuildCache();
    NoteSortService.sortDeletedNotes(_deletedNotes);
    _searchIndexer.invalidateTopicCache();

    // SQL Index Sync (Batch)
    if (isDeleted) {
      await _sqliteFtsService.removeBulk(noteIds);
      _searchIndexer.removeNotesBulk(noteIds);
    } else {
      await _sqliteFtsService.insertOrUpdateBulk(
        result.dbUpdates.values.toList(),
      );
      _searchIndexer.indexNotesBulk(result.dbUpdates.values.toList());
    }
  }

  Future<void> deleteForever(String noteId) async {
    final note = findById(noteId);
    if (note == null) return;

    try {
      await _storageService.deleteNote(noteId);
    } catch (e) {
      debugPrint('Disk Delete Error (deleteForever): $e');
      showErrorSnackBar('Failed to delete note from device storage.');
      return;
    }

    _deletedNotes.remove(note);
    _cacheMap.remove(noteId);
    deletedRevision.value++;

    await VectorStorageService.to.remove(noteId);
  }

  Future<void> deleteForeverBulk(Set<String> noteIds) async {
    if (noteIds.isEmpty) return;

    try {
      await _storageService.deleteNotesBulk(noteIds);
    } catch (e) {
      debugPrint('Disk Delete Error (deleteForeverBulk): $e');
      showErrorSnackBar('Failed to delete selected notes from storage.');
      return;
    }

    _deletedNotes.removeWhere((n) => noteIds.contains(n.id));
    noteIds.forEach(_cacheMap.remove);

    deletedRevision.value++;
    await VectorStorageService.to.removeBulk(noteIds);
  }

  Future<void> togglePinStatus(String noteId) async {
    final note = findById(noteId);
    if (note == null) return;

    PinOperationsService.togglePinState(note);
    _sortAndRebuildCache();

    try {
      await _storageService.saveNote(note);
    } catch (e) {
      // Rollback memory state on storage failure
      PinOperationsService.togglePinState(note);
      _sortAndRebuildCache();
      debugPrint('Pin Save Error: $e');
      showErrorSnackBar('Failed to update pin status.');
    }
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
    try {
      await _storageService.saveNotesBulk(dbUpdates);
    } catch (e) {
      // Rollback bulk pin changes on storage failure
      PinOperationsService.processBulkPin(
        activeNotes: _activeNotes,
        targetIds: noteIds,
        goalState: !goalState,
        currentPinnedCount: pinnedNotes.length,
      );
      _sortAndRebuildCache();
      debugPrint('Pin Bulk Save Error: $e');
      showErrorSnackBar('Failed to update pin status.');
    }
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

  Future<void> saveColorsBulk(
    Set<String> noteIds, [
    Map<String, Color>? originalColors,
  ]) async {
    final Map<String, NotesSection> entries = {};
    for (final id in noteIds) {
      if (findById(id) case final note?) entries[id] = note;
    }

    if (entries.isNotEmpty) {
      try {
        await _storageService.saveNotesBulk(entries);
      } catch (e) {
        if (originalColors != null) {
          restoreColors(originalColors);
          _sortAndRebuildCache();
        }
        debugPrint('Save Colors Error: $e');
        showErrorSnackBar('Failed to save color changes.');
      }
    }
  }

  Future<(int, String)> exportNotesToBackupString() async {
    if (_activeNotes.isEmpty) return (0, '');
    try {
      final jsonString = await _storageService.exportNotesToJSON(_activeNotes);

      return (_activeNotes.length, jsonString);
    } catch (e) {
      debugPrint('Export failed: $e');
      showErrorSnackBar('Export failed. Storage Service error.');
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
      try {
        await _storageService.saveNotesBulk(result.updates);
      } catch (e) {
        debugPrint('Import save error: $e');
        showErrorSnackBar('Failed to import backup. Storage Service error.');
        return (0, 0);
      }

      _activeNotes.addAll(result.updates.values);
      for (final note in result.updates.values) {
        _cacheMap[note.id] = note;
      }

      _sortAndRebuildCache();
      await _sqliteFtsService.reindexAllNotes(_activeNotes);
      _searchIndexer.runMaintenanceSweep(_activeNotes);
      _searchIndexer.rebuildIndex(_activeNotes);
    }

    return (result.updates.length, result.skippedCount);
  }
}

final NoteRepository noteRepository = NoteRepository();
