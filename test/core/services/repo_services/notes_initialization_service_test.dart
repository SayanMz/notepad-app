import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/app_settings_repository.dart';
import 'package:notepad/core/database/sqlite_fts_service.dart';
import 'package:notepad/core/database/storage_service.dart';
import 'package:notepad/core/services/repo_services/notes_initialization_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  NotesSection buildNote(
    String id, {
    required String title,
    required bool deleted,
    required DateTime updatedAt,
  }) {
    return NotesSection(
      id: id,
      title: title,
      content: '$title content',
      isDeleted: deleted,
      updatedAt: updatedAt,
    );
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('notepad_init_test_');
    Hive.init(tempDir.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    if (!Hive.isAdapterRegistered(NotesSectionAdapter().typeId)) {
      Hive.registerAdapter(NotesSectionAdapter());
    }
    if (!Hive.isAdapterRegistered(AppSettingsAdapter().typeId)) {
      Hive.registerAdapter(AppSettingsAdapter());
    }

    await Hive.openBox<NotesSection>('notes_box');
    await Hive.openBox<AppSettings>('settings_box');

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

  setUp(() async {
    await Hive.box<NotesSection>('notes_box').clear();
    await Hive.box<AppSettings>('settings_box').clear();
    await SqliteFtsService.reindexAllNotes(const <NotesSection>[]);
    await appSettingsRepository.update(const AppSettings());
  });

  tearDownAll(() async {
    final db = await SqliteFtsService.database;
    await db.close();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('NotesInitializationService', () {
    test('initializeData seeds welcome notes on version changes', () async {
      await StorageService.saveNote(
        buildNote(
          'legacy-note',
          title: 'Legacy note',
          deleted: false,
          updatedAt: DateTime.utc(2024, 1, 1),
        ),
      );
      await appSettingsRepository.setSeedVersion(0);

      final result = await NotesInitializationService.initializeData(
        installedSeedVersion: 0,
        currentSeedVersion: 1,
      );

      expect(result.activeNotes, hasLength(3));
      expect(result.deletedNotes, isEmpty);
      expect(result.cacheMap, hasLength(3));
      expect(StorageService.getNoteById('legacy-note'), isNull);
      expect(StorageService.loadAllNotes(), hasLength(3));
      expect(appSettingsRepository.settings.seedVersion, 1);
    });

    test('initializeData loads active notes and purges expired trash', () async {
      final activeNote = buildNote(
        'active-note',
        title: 'Active note',
        deleted: false,
        updatedAt: DateTime.utc(2024, 1, 10),
      );
      final freshTrash = buildNote(
        'fresh-trash',
        title: 'Fresh trash',
        deleted: true,
        updatedAt: DateTime.now().subtract(const Duration(days: 10)),
      );
      final expiredTrash = buildNote(
        'expired-trash',
        title: 'Expired trash',
        deleted: true,
        updatedAt: DateTime.now().subtract(const Duration(days: 31)),
      );

      await StorageService.saveNotesBulk({
        activeNote.id: activeNote,
        freshTrash.id: freshTrash,
        expiredTrash.id: expiredTrash,
      });
      await appSettingsRepository.setSeedVersion(1);

      final result = await NotesInitializationService.initializeData(
        installedSeedVersion: 1,
        currentSeedVersion: 1,
      );

      expect(result.activeNotes.map((note) => note.id), ['active-note']);
      expect(result.deletedNotes.map((note) => note.id), ['fresh-trash']);
      expect(result.cacheMap.keys, {'active-note', 'fresh-trash'});
      expect(StorageService.getNoteById('expired-trash'), isNull);
      expect(
        StorageService.loadAllNotes().map((note) => note.id).toSet(),
        {'active-note', 'fresh-trash'},
      );
    });

    test('runMaintenanceTasks refreshes the saved maintenance timestamp',
        () async {
      final staleDate = DateTime.utc(2024, 1, 1, 12);
      await appSettingsRepository.update(
        AppSettings(lastMaintenanceDate: staleDate),
      );

      await NotesInitializationService.runMaintenanceTasks();

      final updated = appSettingsRepository.settings.lastMaintenanceDate;
      expect(updated, isNotNull);
      expect(updated!.isAfter(staleDate), isTrue);
    });
  });
}
