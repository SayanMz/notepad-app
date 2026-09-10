import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/controllers/note_voice_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NoteVoiceController', () {
    const channelSTT = MethodChannel('plugin.csdcorp.com/speech_to_text');
    const channelTTS = MethodChannel('flutter_tts');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channelSTT, (MethodCall methodCall) async {
        if (methodCall.method == 'initialize') {
          return true;
        }
        return null;
      });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channelTTS, (MethodCall methodCall) async {
        if (methodCall.method == 'getVoices') {
          return [];
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channelSTT, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channelTTS, null);
    });

    test('initial state is idle', () async {
      // Create controller
      final controller = NoteVoiceController();
      
      // Ensure we don't have unawaited init tasks lingering
      await controller.initSpeech();

      expect(controller.isListening.value, isFalse);
      expect(controller.isProcessingVoice.value, isFalse);
      
      controller.dispose();
    });
  });
}
