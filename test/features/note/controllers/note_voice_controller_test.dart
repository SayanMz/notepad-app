import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/controllers/note_voice_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // We can only test non-hardware paths without a mocking framework
  test('NoteVoiceController initial state is idle', () {
    final controller = NoteVoiceController();
    
    expect(controller.isListening.value, isFalse);
    expect(controller.isProcessingVoice.value, isFalse);
    expect(controller.isSpeechInitialized, isFalse);
  });
}
