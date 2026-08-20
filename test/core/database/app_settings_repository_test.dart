import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/app_settings_repository.dart';
import 'package:notepad/core/database/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('notepad_settings_test_');
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

  group('AppSettingsRepository', () {
    test('themeMode stays system until settings are loaded', () {
      final repo = AppSettingsRepository();

      expect(repo.themeMode, ThemeMode.system);
    });

    test('load reads the persisted settings and updates theme revision', () async {
      await StorageService.saveSettings(
        AppSettings(
          isDarkMode: true,
          seedVersion: 3,
          lastMaintenanceDate: DateTime(2024, 1, 1),
        ),
      );

      final repo = AppSettingsRepository();
      await repo.load();

      expect(repo.settings.isDarkMode, isTrue);
      expect(repo.settings.seedVersion, 3);
      expect(repo.themeMode, ThemeMode.dark);
      expect(repo.themeRevision.value, 1);
    });

    test('addRecentColor moves colors to the front and trims the list', () async {
      final repo = AppSettingsRepository();
      await repo.update(const AppSettings(recentColorValues: []));

      await repo.addRecentColor(Colors.red, 2);
      await repo.addRecentColor(Colors.blue, 2);
      await repo.addRecentColor(Colors.red, 2);

      expect(
        repo.settings.recentColorValues,
        [Colors.red.toARGB32(), Colors.blue.toARGB32()],
      );
    });

    test('setSeedVersion and recordMaintenanceCompleted persist updates', () async {
      final repo = AppSettingsRepository();
      final maintenanceDate = DateTime.utc(2024, 1, 15, 12);

      await repo.setSeedVersion(7);
      await repo.recordMaintenanceCompleted(maintenanceDate);

      expect(repo.settings.seedVersion, 7);
      expect(repo.settings.lastMaintenanceDate, maintenanceDate);
      expect(StorageService.loadSettings().seedVersion, 7);
      expect(StorageService.loadSettings().lastMaintenanceDate, maintenanceDate);
    });
  });
}
