import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lottie/lottie.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/note/controllers/note_ui_controller.dart';
import 'package:notepad/features/note/controllers/note_voice_controller.dart';
import 'package:notepad/features/note/note_constants.dart';

// Voice assistant button with animated states for listening, processing commands by Ai and tap interactions.
class VoiceAssistantButton extends StatefulWidget {
  const VoiceAssistantButton({
    super.key,
    required this.lottieController,
    required this.voiceController,
    required this.uiController,
    required this.contentController,
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
            ignoring:
                currentOpacity <= NoteConstants.voiceButtonHiddenThreshold,
            child: Listener(
              onPointerDown: (_) => _isPressedNotifier.value = true,
              onPointerUp: (_) => _isPressedNotifier.value = false,
              onPointerCancel: (_) => _isPressedNotifier.value = false,
              child: GestureDetector(
                onTap: (isProcessing && !isListening)
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        widget.voiceController.toggleListening(
                          widget.contentController,
                        );
                      },
                child: AnimatedScale(
                  scale: isPressed ? NoteConstants.voiceButtonPressedScale : 1.0,
                  duration: AnimationConstants.fast,
                  curve: Curves.easeOut,
                  child: AnimatedContainer(
                    duration: AnimationConstants.medium,
                    height: isListening
                        ? NoteConstants.voiceButtonListeningSize
                        : NoteConstants.voiceButtonIdleSize,
                    width: isListening
                        ? NoteConstants.voiceButtonListeningSize
                        : NoteConstants.voiceButtonIdleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.isDark
                          ? AppColors.surfaceSecondaryDark
                          : AppColors.cardSurfaceLight,
                      boxShadow: [
                        if (isListening)
                          BoxShadow(
                            color: AppColors.actionPrimaryLight.withValues(alpha: 0.4),
                            blurRadius:
                                NoteConstants.voiceButtonListeningShadowBlur,
                            spreadRadius:
                                NoteConstants.voiceButtonListeningShadowSpread,
                          )
                        else if (isPressed)
                          BoxShadow(
                            color: context.isDark
                                ? AppColors.overlayBorder.withValues(
                                    alpha: 0.65,
                                  )
                                : AppColors.overlayShadow.withValues(
                                    alpha: 0.15,
                                  ),
                            blurRadius: context.isDark
                                ? NoteConstants.voiceButtonPressedShadowBlur +
                                      UIConstants.paddingS
                                : NoteConstants.voiceButtonPressedShadowBlur,
                            spreadRadius: context.isDark
                                ? NoteConstants.voiceButtonPressedShadowSpread +
                                      UIConstants.paddingXS
                                : NoteConstants.voiceButtonPressedShadowSpread,
                          ),
                      ],
                    ),
                    child: Center(
                      child: RepaintBoundary(
                        child: Lottie.asset(
                          'assets/lotties/Ai_Assistant.json',
                          controller: widget.lottieController,
                          fit: BoxFit.contain,
                          renderCache: RenderCache.drawingCommands,
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
