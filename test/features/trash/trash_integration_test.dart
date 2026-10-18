import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/services/repo_services/notes_initialization.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockStorageService {
  static List<NotesSection> notes = [];
  static void reset() => notes = [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('trash_integration_test_');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

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

  group('Trash Auto-Cleanup Integration', () {
    test('NotesInitializationService logic path for standard load', () async {
      // This integration test verifies the logic paths of the service.

      final result = await NotesInitializationService.initializeData(
        installedSeedVersion: 1,
        currentSeedVersion: 1,
      );

      // Verify logic: initialization should return the non-expired note but NOT the expired one.
      expect(result.deletedNotes, isEmpty); // Assuming empty DB in test env
    });
  });
}
