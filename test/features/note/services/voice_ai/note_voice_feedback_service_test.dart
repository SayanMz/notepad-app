import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:notepad/features/note/services/voice_ai/note_voice_feedback_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class FakeFlutterTts extends Fake implements FlutterTts {
  bool speakCalled = false;
  String? lastSpoken;
  
  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    speakCalled = true;
    lastSpoken = text;
    return 1;
  }

  @override
  Future<dynamic> get getVoices async => [];

  @override
  Future<dynamic> setLanguage(String language) async => 1;

  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> setVolume(double volume) async => 1;

  @override
  Future<dynamic> setVoice(Map<String, String> voice) async => 1;
}

class FakeSpeechToText extends Fake implements stt.SpeechToText {
  @override
  Future<bool> initialize({
    stt.SpeechErrorListener? onError,
    stt.SpeechStatusListener? onStatus,
    debugLogging = false,
    Duration finalTimeout = const Duration(seconds: 2),
    List<stt.SpeechConfigOption>? options,
  }) async {
    return true;
  }
}

void main() {
  group('NoteVoiceFeedbackService', () {
    late FakeFlutterTts fakeTts;
    late NoteVoiceFeedbackService service;

    setUp(() {
      fakeTts = FakeFlutterTts();
      service = NoteVoiceFeedbackService(tts: fakeTts);
    });

    test('speakSuccess calls tts.speak', () async {
      await service.speakSuccess();
      expect(fakeTts.speakCalled, isTrue);
      expect(fakeTts.lastSpoken, isNotNull);
    });

    test('speakFailure calls tts.speak', () async {
      await service.speakFailure();
      expect(fakeTts.speakCalled, isTrue);
      expect(fakeTts.lastSpoken, isNotNull);
    });
  });
}
