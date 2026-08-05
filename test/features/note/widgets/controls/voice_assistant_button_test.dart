import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/controllers/note_ui_controller.dart';
import 'package:notepad/features/note/controllers/note_voice_controller.dart';
import 'package:notepad/features/note/widgets/controls/voice_assistant_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('VoiceAssistantButton responds to controller states', (tester) async {
    final lottieController = AnimationController(vsync: const TestVSync(), duration: Duration.zero);
    final voiceController = NoteVoiceController();
    final uiController = NoteUIController();
    final contentController = QuillController.basic();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceAssistantButton(
            lottieController: lottieController,
            voiceController: voiceController,
            uiController: uiController,
            contentController: contentController,
          ),
        ),
      ),
    );

    // Verify initial state
    expect(find.byType(VoiceAssistantButton), findsOneWidget);
    
    // Check for opacity - initial is full (1.0)
    final AnimatedOpacity opacityWidget = tester.widget(find.byType(AnimatedOpacity));
    expect(opacityWidget.opacity, 1.0);

    // Dim the button via uiController
    uiController.aiButtonOpacity.value = 0.5;
    await tester.pump();
    
    final AnimatedOpacity dimmedOpacityWidget = tester.widget(find.byType(AnimatedOpacity));
    expect(dimmedOpacityWidget.opacity, 0.5);

    lottieController.dispose();
  });
}
