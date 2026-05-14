import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:notepad/features/note/controllers/note_controller.dart';

class VoiceAssistantButton extends StatelessWidget {
  const VoiceAssistantButton({
    super.key,
    required this.noteController,
    required this.lottieController,
    required this.isListening,
    required this.toggleListening,
  });

  final NoteController noteController;
  final AnimationController lottieController;
  final bool isListening;
  final VoidCallback toggleListening;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: noteController.isProcessingVoice,
      builder: (context, isProcessing, _) {
        // Handle Lottie animation states
        if (isProcessing) {
          if (!lottieController.isAnimating) {
            lottieController.repeat();
          }
        } else {
          lottieController.stop();
          lottieController.reset();
        }

        //
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          // Increased size for more screen estate
          height: isListening ? 80.0 : 72.0,
          width: isListening ? 80.0 : 72.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              if (isListening)
                BoxShadow(
                  color: Colors.purpleAccent.withValues(alpha: 0.5),
                  blurRadius: 30,
                  spreadRadius: 8,
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: (isProcessing && !isListening)
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    toggleListening();
                  },
            // REMOVED GREY BACKGROUND: Set to transparent
            backgroundColor: Colors.transparent,
            elevation: 0,
            highlightElevation: 0,
            hoverElevation: 0,
            splashColor: Colors.purpleAccent.withValues(alpha: 0.1),
            shape: const CircleBorder(),
            // LOTTIE SCALING: Takes up more of the FAB circle
            child: Lottie.asset(
              'assets/lotties/Ai_Assistant.json',
              controller: lottieController,
              onLoaded: (composition) {
                lottieController.duration = composition.duration;
              },
              height: isListening ? 70 : 60,
              width: isListening ? 70 : 60,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }
}
