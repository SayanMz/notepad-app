import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('notepad_storage_test_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(NotesSectionAdapter().typeId)) {
      Hive.registerAdapter(NotesSectionAdapter());
    }
    if (!Hive.isAdapterRegistered(AppSettingsAdapter().typeId)) {
      Hive.registerAdapter(AppSettingsAdapter());
    }

    await Hive.openBox<NotesSection>('notes_box');
    await Hive.openBox<AppSettings>('settings_box');
  });

  setUp(() async {
    await Hive.box<NotesSection>('notes_box').clear();
    await Hive.box<AppSettings>('settings_box').clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  NotesSection buildNote(
    String id, {
    required String title,
    required DateTime updatedAt,
  }) {
    return NotesSection(
      id: id,
      title: title,
      content: '$title content',
      updatedAt: updatedAt,
    );
  }

  group('StorageService', () {
    test('saveNote, getNoteById and deleteNote keep Hive in sync', () async {
      final note = buildNote(
        'note-1',
        title: 'First note',
        updatedAt: DateTime.utc(2024, 1, 1),
      );

      await StorageService.saveNote(note);

      expect(StorageService.getNoteById('note-1'), isNotNull);
      expect(StorageService.loadAllNotes(), hasLength(1));

      await StorageService.deleteNote('note-1');

      expect(StorageService.getNoteById('note-1'), isNull);
      expect(StorageService.loadAllNotes(), isEmpty);
    });

    test('saveNotesBulk, deleteNotesBulk and clearAllNotes handle batches safely',
        () async {
      final note1 = buildNote(
        'note-1',
        title: 'First note',
        updatedAt: DateTime.utc(2024, 1, 1),
      );
      final note2 = buildNote(
        'note-2',
        title: 'Second note',
        updatedAt: DateTime.utc(2024, 1, 2),
      );

      await StorageService.saveNotesBulk({
        note1.id: note1,
        note2.id: note2,
      });

      expect(StorageService.loadAllNotes(), hasLength(2));

      await StorageService.deleteNotesBulk({'note-2'});

      expect(StorageService.getNoteById('note-1'), isNotNull);
      expect(StorageService.getNoteById('note-2'), isNull);

      await StorageService.clearAllNotes();

      expect(StorageService.loadAllNotes(), isEmpty);
    });

    test('loadSettings returns defaults until settings are saved', () {
      final settings = StorageService.loadSettings();

      expect(settings.isDarkMode, isFalse);
      expect(settings.seedVersion, 0);
      expect(settings.lastMaintenanceDate, isNull);
      expect(settings.recentColorValues, hasLength(7));
    });

    test('saveSettings persists values that can be loaded later', () async {
      const settings = AppSettings(
        isDarkMode: true,
        userName: 'Sayan',
        seedVersion: 4,
        recentColorValues: [1, 2, 3],
      );

      await StorageService.saveSettings(settings);

      final loaded = StorageService.loadSettings();

      expect(loaded.isDarkMode, isTrue);
      expect(loaded.userName, 'Sayan');
      expect(loaded.seedVersion, 4);
      expect(loaded.recentColorValues, [1, 2, 3]);
    });

    test('exportNotesToJSON and importNotesFromJSON round trip note data',
        () async {
      final notes = List.generate(
        201,
        (index) => buildNote(
          'note-$index',
          title: 'Note $index',
          updatedAt: DateTime.utc(2024, 1, 1).add(Duration(days: index)),
        ),
      );

      final encoded = await StorageService.exportNotesToJSON(notes);
      final decoded = await StorageService.importNotesFromJSON(encoded);

      expect(decoded, hasLength(201));
      expect(decoded.first.id, 'note-0');
      expect(decoded.last.id, 'note-200');
      expect(jsonDecode(encoded), hasLength(201));
    });

    test('importNotesFromJSON throws a FormatException for invalid JSON',
        () async {
      // Silence expected FormatException logs
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {};

      try {
        await expectLater(
          () => StorageService.importNotesFromJSON('not valid json'),
          throwsFormatException,
        );
      } finally {
        debugPrint = originalDebugPrint;
      }
    });
  });
}
