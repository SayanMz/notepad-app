import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/search/services/semantic_search.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
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
      'isModelAvailable returns false when local model file does not exist',
      () async {
        final available = await SemanticSearchService.isModelAvailable();
        expect(available, isFalse);
      },
    );

    test('invalidateTopicCache clears cached topics without error', () {
      expect(
        () => SemanticSearchService.invalidateTopicCache(),
        returnsNormally,
      );
    });

    test(
      'discoverSuggestedTopics returns empty list if model is missing',
      () async {
        final topics = await SemanticSearchService.discoverSuggestedTopics(
          activeNoteIds: {'note-1', 'note-2'},
        );
        expect(topics, isEmpty);
      },
    );
  });
}
