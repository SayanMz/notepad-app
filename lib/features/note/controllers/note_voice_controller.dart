// Voice interaction state is isolated from the note editor and toolbar.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/core/services/ui_management/scaffold_messenger_notifier.dart';
import 'package:notepad/features/note/note_constants.dart';
import 'package:notepad/features/note/services/voice_ai/groq_service.dart';
import 'package:notepad/features/note/services/voice_ai/note_voice_feedback_service.dart';
import 'package:notepad/features/note/services/voice_ai/voice_formatting_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

// Voice UI state is isolated here so AI actions do not clutter the editor.
class NoteVoiceController {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final NoteVoiceFeedbackService _voiceFeedback = NoteVoiceFeedbackService();

  Future<void>? _initTask;
  Timer? _speechTimer;
  String _lastWords = '';
  bool _speechInitialized = false;
  bool get isSpeechInitialized => _speechInitialized;

  final ValueNotifier<bool> isProcessingVoice = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isListening = ValueNotifier<bool>(false);

  Future<void> initSpeech() async {
    if (_speechInitialized) return;
    if (_initTask != null) return _initTask;

    _initTask = _doInit();
    return _initTask;
  }

  Future<void> _doInit() async {
    try {
      final available = await _speech.initialize(
        onError: (error) => debugPrint('STT Error: $error'),
        onStatus: (status) => debugPrint('STT Status: $status'),
      );

      if (available) {
        await _voiceFeedback.initializeSpeech(_speech);
        _speechInitialized = true;
      }
    } finally {
      _initTask = null;
    }
  }

  void toggleListening(QuillController contentController) async {
    if (isListening.value) {
      _cleanupListening(cancelLottie: true);
      return;
    }

    isProcessingVoice.value = true;

    if (!_speechInitialized) {
      await initSpeech();
      if (!_speechInitialized) {
        isProcessingVoice.value = false;
        return;
      }
    }

    isListening.value = true;
    _lastWords = '';

    _speechTimer = Timer(NoteConstants.aiSpeechSilenceTimeout, () {
      if (_lastWords.isEmpty) {
        _cleanupListening(cancelLottie: true);
      }
    });

    _speech.listen(
      onResult: (result) {
        _lastWords = result.recognizedWords;

        _speechTimer?.cancel();
        _speechTimer = Timer(NoteConstants.aiSpeechResultDelay, () {
          if (_lastWords.isNotEmpty) {
            _cleanupListening();
            _processVoiceCommandAndFeedback(_lastWords, contentController);
          }
        });
      },
    );
  }

  void _cleanupListening({bool cancelLottie = false}) {
    _speechTimer?.cancel();
    _speech.stop();
    isListening.value = false;
    if (cancelLottie) isProcessingVoice.value = false;
  }

  Future<void> _processVoiceCommandAndFeedback(
    String commandText,
    QuillController controller,
  ) async {
    isProcessingVoice.value = true;

    FocusManager.instance.primaryFocus?.unfocus();

    await Future.delayed(NoteConstants.aiProcessingDelay);

    try {
      final instructions = await GroqService.parseVoiceCommand(commandText);
      String? feedback;

      if (instructions == null || instructions.isEmpty) {
        feedback = 'No matches found.';
      } else {
        feedback = VoiceFormattingService.applyInstructions(
          instructions: instructions,
          controller: controller,
          commandText: commandText,
        );
      }

      isProcessingVoice.value = false;

      if (feedback == 'Formatting applied!') {
        HapticFeedback.mediumImpact();
        await _voiceFeedback.speakSuccess();
      } else if (feedback == 'No matches found.') {
        HapticFeedback.selectionClick();
        await _voiceFeedback.speakFailure();
      }
    } catch (e) {
      isProcessingVoice.value = false;
      showErrorSnackBar('AI service error. Try again.');
    } finally {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  void stopHardwareListening() {
    _cleanupListening(cancelLottie: true);
  }

  void dispose() {
    _cleanupListening();
    isProcessingVoice.dispose();
    isListening.dispose();
  }
}
