import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/features/note/note_constants.dart';
import 'package:notepad/core/services/scaffold_messenger_notifier.dart';
import 'package:notepad/features/note/services/voice_ai/groq_service.dart';
import 'package:notepad/features/note/services/voice_ai/note_voice_feedback_service.dart';
import 'package:notepad/features/note/services/voice_ai/voice_formatting_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Strictly handles Microphone hardware, Groq AI parsing, and TTS feedback.
class NoteVoiceController {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final NoteVoiceFeedbackService _voiceFeedback = NoteVoiceFeedbackService();

  Future<void>? _initTask;
  Timer? _speechTimer;
  String _lastWords = '';
  bool _speechInitialized = false;

  final ValueNotifier<bool> isProcessingVoice = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isListening = ValueNotifier<bool>(false);

  NoteVoiceController() {
    initSpeech();
  }

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
        // ⚡ trim() removed for efficiency
        _cleanupListening(cancelLottie: true);
      }
    });

    _speech.listen(
      onResult: (result) {
        _lastWords = result.recognizedWords;

        _speechTimer?.cancel();
        _speechTimer = Timer(NoteConstants.aiSpeechResultDelay, () {
          if (_lastWords.isNotEmpty) {
            // ⚡ trim() removed for efficiency
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

    // ⚡ FIX: Microtask removed. Clean synchronous execution.
    FocusManager.instance.primaryFocus?.unfocus();

    // Naturally pushes the network call safely out of the current build frame pass
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

      // Feedback Orchestration
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
    }
  }

  void stopHardwareListening() {
    _cleanupListening(
      cancelLottie: true,
    ); // ⚡ Shuts down the mic hardware instantly
  }

  void dispose() {
    _cleanupListening();
    isProcessingVoice.dispose();
    isListening.dispose();
  }
}
