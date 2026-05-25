import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lottie/lottie.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/services/context_extensions.dart';
import 'package:notepad/features/note/controllers/note_ui_controller.dart';
// ⚡ IMPORT THE EXACT SATELLITE CONTROLLERS
import 'package:notepad/features/note/controllers/note_voice_controller.dart';

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
  bool get isDark => context.isDark;

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
                      color: isDark ? Colors.grey[900] : Colors.white,
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
                            // ⚡ Crisp radiant white glow for dark mode, subtle clean drop for light mode
                            color: isDark
                                ? Colors.white.withValues(
                                    alpha: 0.65,
                                  ) // High opacity makes it look like it's emitting light
                                : Colors.black.withValues(
                                    alpha: 0.15,
                                  ), // Clean depth for light mode
                            blurRadius: isDark
                                ? UIConstants.voiceButtonPressedShadowBlur +
                                      6.0 // Extra blur softens the neon edge
                                : UIConstants.voiceButtonPressedShadowBlur,
                            spreadRadius: isDark
                                ? UIConstants.voiceButtonPressedShadowSpread +
                                      2.0 // Extra spread pushes the light outward
                                : UIConstants.voiceButtonPressedShadowSpread,
                          ),
                      ],
                    ),
                    child: Center(
                      child: RepaintBoundary(
                        child: Lottie.asset(
                          'assets/lotties/Ai_Assistant.json',
                          controller: widget.lottieController,
                          height: isListening
                              ? UIConstants.voiceButtonListeningAssetSize
                              : UIConstants.voiceButtonIdleAssetSize,
                          width: isListening
                              ? UIConstants.voiceButtonListeningAssetSize
                              : UIConstants.voiceButtonIdleAssetSize,

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
