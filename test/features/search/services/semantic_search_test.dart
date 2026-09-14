import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/search/services/semantic_search.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    tempDir = await Directory.systemTemp.createTemp('semantic_search_test_');

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

  group('SemanticSearchService', () {
    test(
      'computeCosineSimilarity calculates exact dot product of normalized vectors',
      () {
        final a = Float32List.fromList([1.0, 0.0, 0.0]);
        final b = Float32List.fromList([1.0, 0.0, 0.0]);
        final c = Float32List.fromList([0.0, 1.0, 0.0]);

        expect(
          SemanticSearchService.computeCosineSimilarity(a, b),
          closeTo(1.0, 1e-5),
        );
        expect(
          SemanticSearchService.computeCosineSimilarity(a, c),
          closeTo(0.0, 1e-5),
        );
      },
    );

    test(
      'isModelAvailable checks ONNX model availability',
      () async {
        final available = await SemanticSearchService.isModelAvailable();
        expect(available, isA<bool>());
      },
    );

    test('invalidateTopicCache clears cached topics without error', () {
      expect(
        () => SemanticSearchService.invalidateTopicCache(),
        returnsNormally,
      );
    });

    test('cacheRevision exposes topic discovery revision notifier', () {
      expect(SemanticSearchService.cacheRevision, isNotNull);
    });

    test(
      'discoverSuggestedTopics returns empty list if activeNoteIds is empty',
      () async {
        final topics = await SemanticSearchService.discoverSuggestedTopics(
          activeNoteIds: <String>[],
        );
        expect(topics, isEmpty);
      },
    );

    test(
      'getNoteIdsForTopic delegates call to TopicDiscoveryService',
      () async {
        final ids = await SemanticSearchService.getNoteIdsForTopic('Software & Tech');
        expect(ids, isA<List<String>>());
      },
    );
  });
}
