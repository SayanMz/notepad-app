import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:notepad/core/database/app_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late List<int> encryptionKey;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_ce_compat_test_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(NotesSectionAdapter().typeId)) {
      Hive.registerAdapter(NotesSectionAdapter());
    }
    if (!Hive.isAdapterRegistered(AppSettingsAdapter().typeId)) {
      Hive.registerAdapter(AppSettingsAdapter());
    }

    encryptionKey = Hive.generateSecureKey();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Hive CE AES-256 Encryption & Data Schema Compatibility', () {
    test('Encrypted boxes open successfully with HiveAesCipher and persist schema', () async {
      // 1. Open encrypted boxes with AES-256 cipher
      final notesBox = await Hive.openBox<NotesSection>(
        'notes_box_encrypted_test',
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
      final settingsBox = await Hive.openBox<AppSettings>(
        'settings_box_encrypted_test',
        encryptionCipher: HiveAesCipher(encryptionKey),
      );

      // 2. Write representative data
      final note1 = NotesSection(
        id: 'encrypted-note-1',
        title: 'Encrypted Title 1',
        content: 'Encrypted Content 1',
        richContent: '{"ops":[{"insert":"Hello"}]}',
        isPinned: true,
        updatedAt: DateTime.utc(2025, 1, 1),
        positionIndex: 0,
      );
      const settings1 = AppSettings(
        isDarkMode: true,
        userName: 'AES User',
        seedVersion: 2,
      );

      await notesBox.put(note1.id, note1);
      await settingsBox.put('current_settings', settings1);

      // Compact & close
      await notesBox.compact();
      await settingsBox.compact();
      await notesBox.close();
      await settingsBox.close();

      // 3. Re-open using the exact same encryption key in Hive CE
      final reopenedNotesBox = await Hive.openBox<NotesSection>(
        'notes_box_encrypted_test',
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
      final reopenedSettingsBox = await Hive.openBox<AppSettings>(
        'settings_box_encrypted_test',
        encryptionCipher: HiveAesCipher(encryptionKey),
      );

      // 4. Verify data integrity, TypeId=0 (NotesSection) & TypeId=1 (AppSettings)
      final retrievedNote = reopenedNotesBox.get('encrypted-note-1');
      final retrievedSettings = reopenedSettingsBox.get('current_settings');

      expect(retrievedNote, isNotNull);
      expect(retrievedNote!.title, 'Encrypted Title 1');
      expect(retrievedNote.content, 'Encrypted Content 1');
      expect(retrievedNote.isPinned, isTrue);

      expect(retrievedSettings, isNotNull);
      expect(retrievedSettings!.isDarkMode, isTrue);
      expect(retrievedSettings.userName, 'AES User');
      expect(retrievedSettings.seedVersion, 2);

      // 5. Test CRUD (Update & Delete)
      retrievedNote.title = 'Updated Title 1';
      await reopenedNotesBox.put(retrievedNote.id, retrievedNote);
      expect(reopenedNotesBox.get('encrypted-note-1')!.title, 'Updated Title 1');

      await reopenedNotesBox.delete('encrypted-note-1');
      expect(reopenedNotesBox.get('encrypted-note-1'), isNull);

      await reopenedNotesBox.close();
      await reopenedSettingsBox.close();
    });
  });
}
