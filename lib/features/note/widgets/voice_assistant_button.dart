import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:notepad/features/note/controllers/note_controller.dart';

class VoiceAssistantButton extends StatefulWidget {
  const VoiceAssistantButton({
    super.key,
    required this.noteController,
    required this.lottieController,
    required this.isListeningNotifier,
    required this.aiButtonOpacityNotifier,
    required this.toggleListening,
  });

  final NoteController noteController;
  final AnimationController lottieController;
  final ValueListenable<bool> isListeningNotifier;
  final ValueListenable<double> aiButtonOpacityNotifier;
  final VoidCallback toggleListening;

  @override
  State<VoiceAssistantButton> createState() => _VoiceAssistantButtonState();
}

class _VoiceAssistantButtonState extends State<VoiceAssistantButton> {
  // JOB 1: Physical Feedback (The "Reflex")
  final ValueNotifier<bool> _isPressedNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    // Move Lottie control to a dedicated listener instead of the build method
    widget.noteController.isProcessingVoice.addListener(_handleLottieState);
  }

  @override
  void dispose() {
    widget.noteController.isProcessingVoice.removeListener(_handleLottieState);
    _isPressedNotifier.dispose();
    super.dispose();
  }

  void _handleLottieState() {
    if (widget.noteController.isProcessingVoice.value) {
      if (!widget.lottieController.isAnimating) {
        widget.lottieController.repeat();
      }
    } else {
      widget.lottieController.stop();
      widget.lottieController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.isListeningNotifier,
        widget.noteController.isProcessingVoice,
        widget.aiButtonOpacityNotifier,
        _isPressedNotifier,
      ]),
      builder: (context, _) {
        final isListening = widget.isListeningNotifier.value;
        final isProcessing = widget.noteController.isProcessingVoice.value;
        final currentOpacity = widget.aiButtonOpacityNotifier.value;
        final isPressed = _isPressedNotifier.value;

        return AnimatedOpacity(
          opacity: currentOpacity,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: IgnorePointer(
            ignoring: currentOpacity <= 0.2,
            child: Listener(
              onPointerDown: (_) => _isPressedNotifier.value = true,
              onPointerUp: (_) => _isPressedNotifier.value = false,
              onPointerCancel: (_) => _isPressedNotifier.value = false,
              child: GestureDetector(
                onTap: (isProcessing && !isListening)
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        widget.toggleListening();
                      },
                // JOB 2: Physical "Squish" on tap
                child: AnimatedScale(
                  scale: isPressed ? 0.92 : 1.0,
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOut,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    // JOB 3: System "Expansion" when microphone is active
                    height: isListening ? 80.0 : 72.0,
                    width: isListening ? 80.0 : 72.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.grey[900] : Colors.white,
                      boxShadow: [
                        // Different shadows for different jobs
                        if (isListening)
                          BoxShadow(
                            color: Colors.purpleAccent.withValues(alpha: 0.4),
                            blurRadius: 30,
                            spreadRadius: 8,
                          )
                        else if (isPressed)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                    child: Center(
                      child: RepaintBoundary(
                        // ISOLATE: Keeps the 60fps loop independent
                        child: Lottie.asset(
                          'assets/lotties/Ai_Assistant.json',
                          controller: widget.lottieController,
                          addRepaintBoundary: true,
                          height: isListening ? 70 : 60,
                          width: isListening ? 70 : 60,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  bool get isDark => Theme.of(context).brightness == Brightness.dark;
}
