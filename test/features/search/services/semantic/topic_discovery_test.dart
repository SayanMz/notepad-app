import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/search/services/semantic/topic_discovery_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

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
    test('invalidateCache clears topic cache and increments cacheRevision', () {
      final initialRevision = TopicDiscoveryService.cacheRevision.value;
      TopicDiscoveryService.invalidateCache();
      expect(TopicDiscoveryService.cacheRevision.value, equals(initialRevision + 1));
    });

    test(
      'discoverSuggestedTopics returns empty list when AI model is missing',
      () async {
        final topics = await TopicDiscoveryService.discoverSuggestedTopics(
          activeNoteIds: ['topic-note-1', 'topic-note-2'],
        );
        expect(topics, isEmpty);
      },
    );

    test(
      'discoverSuggestedTopics returns empty list when activeNoteIds is empty',
      () async {
        final topics = await TopicDiscoveryService.discoverSuggestedTopics(
          activeNoteIds: <String>[],
        );
        expect(topics, isEmpty);
      },
    );

    test(
      'getNoteIdsForTopic returns empty list when AI model is missing',
      () async {
        final ids = await TopicDiscoveryService.getNoteIdsForTopic(
          'Software & Tech',
        );
        expect(ids, isEmpty);
      },
    );
  });
}
