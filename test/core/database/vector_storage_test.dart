import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/vector_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('vector_storage_test_');
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
    await VectorStorageService.close();
    await tempDir.delete(recursive: true);
  });

  group('VectorStorageService', () {
    test('upsertEmbeddings stores and retrieves vector chunks', () async {
      final floatVec = Float32List.fromList([0.1, 0.2, 0.3, 0.4]);
      final blob = floatVec.buffer.asUint8List();
      final now = DateTime(2026, 1, 15);

      await VectorStorageService.upsertEmbeddings('vec-note-1', [blob], now);

      final results = await VectorStorageService.fetchAllEmbeddings();
      expect(results, isNotEmpty);

      final matched = results.firstWhere((r) => r['note_id'] == 'vec-note-1');
      expect(matched['note_id'], equals('vec-note-1'));
    });

    test('getNoteIdsMissingEmbeddings accurately identifies unindexed notes', () async {
      final activeNoteIds = ['vec-note-1', 'vec-note-unindexed'];
      final missing = await VectorStorageService.getNoteIdsMissingEmbeddings(activeNoteIds);

      expect(missing, contains('vec-note-unindexed'));
      expect(missing, isNot(contains('vec-note-1')));
    });

    test('remove and removeBulk clears vector entries', () async {
      final floatVec = Float32List.fromList([0.5, 0.6]);
      final blob = floatVec.buffer.asUint8List();

      await VectorStorageService.upsertEmbeddings('vec-del-1', [blob], DateTime.now());
      await VectorStorageService.upsertEmbeddings('vec-del-2', [blob], DateTime.now());

      await VectorStorageService.remove('vec-del-1');
      var results = await VectorStorageService.fetchAllEmbeddings();
      expect(results.any((r) => r['note_id'] == 'vec-del-1'), isFalse);

      await VectorStorageService.removeBulk({'vec-del-2'});
      results = await VectorStorageService.fetchAllEmbeddings();
      expect(results.any((r) => r['note_id'] == 'vec-del-2'), isFalse);
    });
  });
}
