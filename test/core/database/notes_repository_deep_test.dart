import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/app_settings_repository.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/core/database/sqlite_fts_service.dart';
import 'package:notepad/core/database/storage_service.dart';
import 'package:sqflite/sqflite.dart';

class RecordingStorageService extends Fake implements StorageServiceApi {
  final Map<String, NotesSection> notesById = {};
  final List<Map<String, NotesSection>> saveBulkCalls = [];
  final List<String> deletedIds = [];
  final List<Set<String>> deletedBulkCalls = [];
  int saveNoteCalls = 0;

  AppSettings currentSettings = const AppSettings();

  void resetCounters() {
    saveBulkCalls.clear();
    deletedIds.clear();
    deletedBulkCalls.clear();
    saveNoteCalls = 0;
  }

  @override
  Future<void> initializeEncryptedStorage() async {}

  @override
  Future<void> performMaintenance() async {}

  @override
  Future<String> exportNotesToJSON(List<NotesSection> notes) async =>
      jsonEncode(notes.map((note) => note.toJson()).toList());

  @override
  Future<List<NotesSection>> importNotesFromJSON(String jsonString) async {
    final decoded = jsonDecode(jsonString) as List<dynamic>;
    return decoded
        .cast<Map<String, dynamic>>()
        .map(NotesSection.fromJson)
        .toList();
  }

  @override
  List<NotesSection> loadAllNotes() => notesById.values.toList();

  @override
  NotesSection? getNoteById(String id) => notesById[id];

  @override
  Future<void> saveNote(NotesSection note) async {
    saveNoteCalls++;
    notesById[note.id] = note;
  }

  @override
  Future<void> saveNotesBulk(Map<String, NotesSection> notes) async {
    saveBulkCalls.add(Map<String, NotesSection>.from(notes));
    notesById.addAll(notes);
  }

  @override
  Future<void> deleteNote(String id) async {
    deletedIds.add(id);
    notesById.remove(id);
  }

  @override
  Future<void> deleteNotesBulk(Set<String> ids) async {
    deletedBulkCalls.add(Set<String>.from(ids));
    for (final id in ids) {
      notesById.remove(id);
    }
  }

  @override
  Future<void> clearAllNotes() async {
    notesById.clear();
  }

  @override
  AppSettings loadSettings() => currentSettings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    currentSettings = settings;
  }
}

class RecordingSqliteFtsService extends Fake implements SqliteFtsServiceApi {
  int insertOrUpdateBulkCalls = 0;
  int removeBulkCalls = 0;
  int reindexAllCalls = 0;
  final List<List<NotesSection>> insertedBulkNotes = [];

  @override
  Future<Database> get database async => throw UnimplementedError();

  @override
  Future<void> close() async {}

  @override
  Future<void> insertOrUpdate(NotesSection note) async {}

  @override
  Future<void> insertOrUpdateBulk(List<NotesSection> notes) async {
    insertOrUpdateBulkCalls++;
    insertedBulkNotes.add(List<NotesSection>.from(notes));
  }

  @override
  Future<void> remove(String id) async {}

  @override
  Future<void> removeBulk(Set<String> ids) async {
    removeBulkCalls++;
  }

  @override
  Future<void> reindexAllNotes(List<NotesSection> allNotes) async {
    reindexAllCalls++;
  }

  @override
  Future<Set<String>> searchIds(String query) async => <String>{};

  @override
  Future<Set<String>> searchIdsWithDateRange(
    String query,
    DateTime start,
    DateTime end,
  ) async =>
      <String>{};
}

void main() {
  group('NoteRepository deep coordination', () {
    late RecordingStorageService storage;
    late RecordingSqliteFtsService sqlite;
    late AppSettingsRepository settingsRepository;
    late NoteRepository repository;

    setUp(() {
      storage = RecordingStorageService();
      sqlite = RecordingSqliteFtsService();
      settingsRepository = AppSettingsRepository(storageService: storage);
      repository = NoteRepository.internalForTesting(
        storageService: storage,
        sqliteFtsService: sqlite,
        settingsRepository: settingsRepository,
      );
    });

    test('reorders pinned notes and recalculates every position index', () async {
      final createdIds = <String>[];

      for (var i = 0; i < 10; i++) {
        final note = await repository.saveNote(
          noteId: null,
          title: 'Note $i',
          content: 'Content $i',
          notify: false,
        );
        createdIds.add(note!.id);
      }

      storage.resetCounters();
      await repository.togglePinBulk(createdIds.toSet(), true);
      storage.resetCounters();

      final beforeMoveId = repository.pinnedNotes[5].id;
      repository.reorderPinnedNotes(5, 0);

      expect(repository.pinnedNotes.first.id, beforeMoveId);
      expect(
        repository.pinnedNotes.map((note) => note.positionIndex).toList(),
        List<int>.generate(10, (index) => index),
      );
      expect(storage.saveBulkCalls, hasLength(1));
      expect(storage.saveBulkCalls.single.keys, contains(beforeMoveId));
    });

    test('bulk pinning and recycling use batched persistence paths', () async {
      final ids = <String>{};

      for (var i = 0; i < 50; i++) {
        final note = await repository.saveNote(
          noteId: null,
          title: 'Bulk $i',
          content: 'Bulk content $i',
        );
        ids.add(note!.id);
      }

      storage.resetCounters();
      sqlite.insertOrUpdateBulkCalls = 0;
      sqlite.removeBulkCalls = 0;

      await repository.togglePinBulk(ids, true);

      expect(storage.saveBulkCalls, hasLength(1));
      expect(storage.saveBulkCalls.single, hasLength(50));
      expect(
        repository.pinnedNotes.map((note) => note.isPinned).every((value) => value),
        isTrue,
      );
      expect(
        repository.pinnedNotes.map((note) => note.positionIndex).toList(),
        List<int>.generate(50, (index) => index),
      );

      storage.resetCounters();
      await repository.toggleDeletedStatusBulk(ids, true);

      expect(storage.saveBulkCalls, hasLength(1));
      expect(sqlite.removeBulkCalls, 1);
      expect(repository.deletedNotes, hasLength(50));

      storage.resetCounters();
      await repository.toggleDeletedStatusBulk(ids, false);

      expect(storage.saveBulkCalls, hasLength(1));
      expect(sqlite.insertOrUpdateBulkCalls, 1);
      expect(repository.activeNotes, hasLength(50));
    });
  });
}
