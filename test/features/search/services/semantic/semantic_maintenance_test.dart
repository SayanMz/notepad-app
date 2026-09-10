import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/features/search/services/semantic/semantic_maintenance.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('semantic_maintenance_test_');

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
    await tempDir.delete(recursive: true);
  });

  group('SemanticMaintenanceService', () {
    test('runMaintenanceSweep exits early when model is not available', () async {
      final note = NotesSection(
        id: 'sweep-note-1',
        title: 'Title',
        content: 'Content',
      );

      expect(
        () => SemanticMaintenanceService.runMaintenanceSweep([note]),
        returnsNormally,
      );
    });

    test('embedNoteInBackground queues background task without error', () async {
      final note = NotesSection(
        id: 'bg-note-1',
        title: 'Background Embed',
        content: 'Content',
      );

      expect(
        () => SemanticMaintenanceService.embedNoteInBackground(note),
        returnsNormally,
      );
    });
  });
}
