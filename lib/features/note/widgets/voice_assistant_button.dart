import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:flutter_quill/flutter_quill.dart';

// ⚡ IMPORT THE EXACT SATELLITE CONTROLLERS
import 'package:notepad/features/note/controllers/note_voice_controller.dart';
import 'package:notepad/features/note/controllers/note_ui_controller.dart';

class VoiceAssistantButton extends StatefulWidget {
  const VoiceAssistantButton({
    super.key,
    required this.lottieController,
    required this.voiceController, // ⚡ Pass the Voice driver directly
    required this.uiController, // ⚡ Pass the UI driver directly
    required this.contentController, // Needed to pass down to toggleListening
  });

  final AnimationController lottieController;
  final NoteVoiceController voiceController;
  final NoteUIController uiController;
  final QuillController contentController;

  @override
  State<VoiceAssistantButton> createState() => _VoiceAssistantButtonState();
}

class _VoiceAssistantButtonState extends State<VoiceAssistantButton> {
  final ValueNotifier<bool> _isPressedNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    // ⚡ Child directly listens to its controller's niche data stream!
    widget.voiceController.isProcessingVoice.addListener(_handleLottieState);
  }

  @override
  void dispose() {
    widget.voiceController.isProcessingVoice.removeListener(_handleLottieState);
    _isPressedNotifier.dispose();
    super.dispose();
  }

  void _handleLottieState() {
    if (widget.voiceController.isProcessingVoice.value) {
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
      // ⚡ Merging the explicit controller streams directly inside the child!
      listenable: Listenable.merge([
        widget.voiceController.isListening,
        widget.voiceController.isProcessingVoice,
        widget.uiController.aiButtonOpacity,
        _isPressedNotifier,
      ]),
      builder: (context, _) {
        final isListening = widget.voiceController.isListening.value;
        final isProcessing = widget.voiceController.isProcessingVoice.value;
        final currentOpacity = widget.uiController.aiButtonOpacity.value;
        final isPressed = _isPressedNotifier.value;

        return AnimatedOpacity(
          opacity: currentOpacity,
          duration: AnimationConstants.fast,
          curve: Curves.easeInOut,
          child: IgnorePointer(
            ignoring: currentOpacity <= UIConstants.voiceButtonHiddenThreshold,
            child: Listener(
              onPointerDown: (_) => _isPressedNotifier.value = true,
              onPointerUp: (_) => _isPressedNotifier.value = false,
              onPointerCancel: (_) => _isPressedNotifier.value = false,
              child: GestureDetector(
                onTap: (isProcessing && !isListening)
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        // ⚡ Fire execution directly into the business controller!
                        widget.voiceController.toggleListening(
                          widget.contentController,
                        );
                      },
                child: AnimatedScale(
                  scale: isPressed ? UIConstants.voiceButtonPressedScale : 1.0,
                  duration: AnimationConstants.fast,
                  curve: Curves.easeOut,
                  child: AnimatedContainer(
                    duration: AnimationConstants.medium,
                    height: isListening
                        ? UIConstants.voiceButtonListeningSize
                        : UIConstants.voiceButtonIdleSize,
                    width: isListening
                        ? UIConstants.voiceButtonListeningSize
                        : UIConstants.voiceButtonIdleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[900]
                          : Colors.white,
                      boxShadow: [
                        if (isListening)
                          BoxShadow(
                            color: Colors.purpleAccent.withValues(alpha: 0.4),
                            blurRadius:
                                UIConstants.voiceButtonListeningShadowBlur,
                            spreadRadius:
                                UIConstants.voiceButtonListeningShadowSpread,
                          )
                        else if (isPressed)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius:
                                UIConstants.voiceButtonPressedShadowBlur,
                            spreadRadius:
                                UIConstants.voiceButtonPressedShadowSpread,
                          ),
                      ],
                    ),
                    child: Center(
                      child: RepaintBoundary(
                        child: Lottie.asset(
                          'assets/lotties/Ai_Assistant.json',
                          controller: widget.lottieController,
                          addRepaintBoundary: true,
                          height: isListening
                              ? UIConstants.voiceButtonListeningAssetSize
                              : UIConstants.voiceButtonIdleAssetSize,
                          width: isListening
                              ? UIConstants.voiceButtonListeningAssetSize
                              : UIConstants.voiceButtonIdleAssetSize,
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
}
