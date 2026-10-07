import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/app_settings_repository.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/core/database/sqlite_fts.dart';
import 'package:notepad/core/database/storage_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
  Future<List<String>> searchIds(String query) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = await Directory.systemTemp.createTemp('notes_repo_deep_test_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          switch (call.method) {
            case 'getApplicationDocumentsDirectory':
            case 'getTemporaryDirectory':
              return tempDir.path;
            default:
              return null;
          }
        });
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

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

    test(
      'reorders pinned notes and recalculates every position index',
      () async {
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
      },
    );

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
        repository.pinnedNotes
            .map((note) => note.isPinned)
            .every((value) => value),
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

    test('injectSeedNotesBulk inserts notes and updates search index', () async {
      final seedNotes = [
        NotesSection(id: 'seed-1', title: 'Seed 1', content: 'Content 1'),
        NotesSection(id: 'seed-2', title: 'Seed 2', content: 'Content 2'),
      ];

      await repository.injectSeedNotesBulk(seedNotes);

      expect(repository.activeNotes, hasLength(2));
      expect(repository.findById('seed-1'), isNotNull);
    });

    test('deleteForever and deleteForeverBulk purges notes from storage', () async {
      final note1 = await repository.saveNote(noteId: null, title: 'Del 1', content: 'C1');
      final note2 = await repository.saveNote(noteId: null, title: 'Del 2', content: 'C2');

      await repository.toggleDeletedStatus(note1!.id, true);
      await repository.toggleDeletedStatus(note2!.id, true);

      await repository.deleteForever(note1.id);
      expect(repository.deletedNotes.any((n) => n.id == note1.id), isFalse);

      await repository.deleteForeverBulk({note2.id});
      expect(repository.deletedNotes.any((n) => n.id == note2.id), isFalse);
    });

    test('color selection, restore and bulk save operations update notes', () async {
      final note = await repository.saveNote(noteId: null, title: 'Color Note', content: 'Content');
      final noteId = note!.id;

      repository.applyColorToSelection({noteId}, const Color(0xFFFF0000));
      expect(repository.findById(noteId)?.cardColor, equals(const Color(0xFFFF0000)));

      repository.restoreColors({noteId: const Color(0xFF00FF00)});
      expect(repository.findById(noteId)?.cardColor, equals(const Color(0xFF00FF00)));

      await repository.saveColorsBulk({noteId});
      expect(storage.saveBulkCalls, isNotEmpty);
    });

    test('exportNotesToBackupString and importNotesFromBackupString roundtrip backup data', () async {
      await repository.saveNote(noteId: null, title: 'Export Title', content: 'Export Content');

      final (count, jsonString) = await repository.exportNotesToBackupString();
      expect(count, equals(1));
      expect(jsonString, contains('Export Title'));

      // Importing invalid json throws FormatException
      expect(
        () async => await repository.importNotesFromBackupString('invalid json'),
        throwsFormatException,
      );

      // Importing empty array throws FormatException
      expect(
        () async => await repository.importNotesFromBackupString('[]'),
        throwsFormatException,
      );
    });

    test('reorderUnpinnedNotes reorders unpinned notes zone', () async {
      await repository.saveNote(noteId: null, title: 'Unpinned 1', content: 'C1');
      await repository.saveNote(noteId: null, title: 'Unpinned 2', content: 'C2');

      repository.reorderUnpinnedNotes(0, 1);
      expect(repository.unpinnedNotes, isNotEmpty);
    });
  });
}
