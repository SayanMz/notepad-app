import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/search/services/semantic/topic_discovery_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('topic_discovery_test_');

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

  setUp(() {
    TopicDiscoveryService.invalidateCache();
  });

  group('TopicDiscoveryService', () {
    test('invalidateCache clears topic cache without throwing error', () {
      expect(() => TopicDiscoveryService.invalidateCache(), returnsNormally);
    });

    test(
      'discoverSuggestedTopics returns empty list when AI model is missing',
      () async {
        final topics = await TopicDiscoveryService.discoverSuggestedTopics(
          activeNoteIds: {'topic-note-1', 'topic-note-2'},
        );
        expect(topics, isEmpty);
      },
    );

    test(
      'discoverSuggestedTopics returns empty list when activeNoteIds is empty',
      () async {
        final topics = await TopicDiscoveryService.discoverSuggestedTopics(
          activeNoteIds: {},
        );
        expect(topics, isEmpty);
      },
    );

    test(
      'getNoteIdsForTopic returns empty list when AI model is missing',
      () async {
        final ids = await TopicDiscoveryService.getNoteIdsForTopic(
          'Software & Programming',
        );
        expect(ids, isEmpty);
      },
    );
  });
}
