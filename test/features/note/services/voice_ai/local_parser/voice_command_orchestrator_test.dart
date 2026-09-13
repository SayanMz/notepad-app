import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/services/voice_ai/groq_service.dart';
import 'package:notepad/features/note/services/voice_ai/local_parser/base_voice_parser.dart';
import 'package:notepad/features/note/services/voice_ai/local_parser/voice_command_orchestrator.dart';

class MockLocalParser implements BaseVoiceParser {
  List<VoiceInstruction>? response;
  bool called = false;
  String? lastQuery;

  @override
  List<VoiceInstruction>? parse(String voiceText, [String currentEditorText = '']) {
    called = true;
    lastQuery = voiceText;
    return response;
  }
}

class MockRemoteParser implements BaseVoiceParser {
  List<VoiceInstruction>? response;
  bool called = false;
  bool throwOffline = false;

  @override
  Future<List<VoiceInstruction>?> parse(String voiceText, [String currentEditorText = '']) async {
    called = true;
    if (throwOffline) {
      throw GroqServiceException('Offline');
    }
    return response;
  }
}

void main() {
  group('VoiceCommandOrchestrator', () {
    late MockLocalParser localParser;
    late MockRemoteParser remoteParser;
    late VoiceCommandOrchestrator orchestrator;
    const dummyText = 'test document';

    setUp(() {
      localParser = MockLocalParser();
      remoteParser = MockRemoteParser();
      orchestrator = VoiceCommandOrchestrator(
        localParser: localParser,
        remoteParser: remoteParser,
      );
    });

    test('returns null for empty text without calling parsers', () async {
      final res = await orchestrator.routeCommand('   ', dummyText);
      expect(res, isNull);
      expect(localParser.called, isFalse);
      expect(remoteParser.called, isFalse);
    });

    test('returns local instructions immediately if target is confident', () async {
      localParser.response = [
        const VoiceInstruction(key: 'bold', value: true, target: 'selection', occurrence: 'all')
      ];

      final res = await orchestrator.routeCommand('make this bold', dummyText);

      expect(res, isNotNull);
      expect(res!.first['key'], 'bold');
      expect(localParser.called, isTrue);
      expect(remoteParser.called, isFalse); // Remote skipped!
    });

    test('falls back to remote parser if local returns null', () async {
      localParser.response = null; // Local fails
      remoteParser.response = [
        const VoiceInstruction(key: 'color', value: '#FF0000', target: 'house', occurrence: 'all')
      ];

      final res = await orchestrator.routeCommand('make the house red', dummyText);

      expect(res, isNotNull);
      expect(res!.first['target'], 'house');
      expect(localParser.called, isTrue);
      expect(remoteParser.called, isTrue); // Remote called!
    });

    test('falls back to remote parser if local returns empty target', () async {
      // Local detects 'color' but cannot find a definitive structural target
      localParser.response = [
        const VoiceInstruction(key: 'color', value: '#FF0000', target: '', occurrence: 'all')
      ];
      remoteParser.response = [
        const VoiceInstruction(key: 'color', value: '#FF0000', target: 'golden retriever', occurrence: 'all')
      ];

      final res = await orchestrator.routeCommand('make golden retriever red', dummyText);

      expect(res, isNotNull);
      expect(res!.first['target'], 'golden retriever');
      expect(localParser.called, isTrue);
      expect(remoteParser.called, isTrue);
    });

    test('rethrows GroqServiceException to allow UI to handle offline states', () async {
      localParser.response = null;
      remoteParser.throwOffline = true;

      expect(
        () => orchestrator.routeCommand('make golden retriever red', dummyText),
        throwsA(isA<GroqServiceException>()),
      );
    });
  });
}
