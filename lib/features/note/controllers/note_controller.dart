import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/data/notes_repository.dart';
import 'package:notepad/core/services/scaffold_messenger_notifier.dart';
import 'package:notepad/features/note/services/voice_ai/groq_service.dart';
import 'package:notepad/features/note/services/voice_ai/note_voice_feedback_service.dart';
import 'package:notepad/features/note/services/voice_ai/voice_formatting_service.dart';
import 'package:notepad/features/note/widgets/save_indicator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Handles all non-UI logic for NotePage:
/// - Autosave (debounced)
/// - Crash recovery (shadow drafts)
/// - Persistent save (repository)
/// - Voice command orchestration
class NoteController {
  final NoteRepository noteRepository;
  String? noteId;

  NoteController({required this.noteRepository, this.noteId}) {
    initSpeech();
  }
  // Guard to prevent multiple simultaneous initializations
  Future<void>? _initTask;

  Timer? _autosaveDebounce;
  bool _isDisposed = false;

  /// Dedicated debounce window to capture text entry idle loops
  Timer? _fadeVisibilityDebounce;

  /// Prevents overlapping saves
  bool _isSaving = false;

  /// Surgical UI State: Notifiers prevent full NotePage rebuilds
  final ValueNotifier<SaveState> saveState = ValueNotifier<SaveState>(
    SaveState.idle,
  );
  final ValueNotifier<bool> isProcessingVoice = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isListening = ValueNotifier<bool>(false);

  /// Controls the overall alpha opacity layer of the floating action elements
  final ValueNotifier<double> aiButtonOpacity = ValueNotifier<double>(1.0);

  void _orchestrateButtonVisibility() {
    // 1. The millisecond a user presses a key, instantly dim the button out of sight
    if (aiButtonOpacity.value != 0.15) {
      aiButtonOpacity.value =
          0.15; // Low profile profile, faint and "invisible"
    }

    _fadeVisibilityDebounce?.cancel();

    // 2. The moment typing pauses for 1.2 seconds, smoothly bloom the button back to life
    _fadeVisibilityDebounce = Timer(const Duration(milliseconds: 1200), () {
      if (aiButtonOpacity.value != 1.0) {
        aiButtonOpacity.value = 1.0;
      }
    });
  }

  ///Dirty State Tracking
  String? _lastEditorSignature;

  /// Sets the initial baseline for comparison so hasChanges
  /// accurately detects modifications from the original load.
  void setInitialSignature(String title, Document document) {
    _lastEditorSignature = _editorSignature(title, document);
  }

  /// Generates a unique signature of the editor state for comparison.
  String _editorSignature(String title, Document document) {
    return '${title.trim()}\n${jsonEncode(document.toDelta().toJson())}';
  }

  bool _isStateUnchanged(String title, Document document) {
    return _lastEditorSignature == _editorSignature(title, document);
  }

  /// Used for the back navigation guard.
  bool hasPendingChanges(String title, Document document) {
    return !_isStateUnchanged(title, document);
  }

  /// --- VOICE AI & HARDWARE STATE ---
  final stt.SpeechToText _speech = stt.SpeechToText();
  final NoteVoiceFeedbackService _voiceFeedback = NoteVoiceFeedbackService();
  Timer? _speechTimer;
  String _lastWords = '';
  bool _speechInitialized = false;

  /// Called whenever editor content changes.
  /// Uses a "Bouncer Pattern" to ignore redundant updates.
  void handleEditorChanged({
    required String title,
    required Document document,
  }) {
    if (_isStateUnchanged(title, document)) return;

    _autosaveDebounce?.cancel();
    _autosaveDebounce = Timer(
      UIConstants.saveIndicatorDuration,
      () => saveNote(title: title, document: document),
    );
    _orchestrateButtonVisibility();
  }

  /// Saves note to repository with a "latest-wins" strategy.
  Future<void> saveNote({
    required String title,
    required Document document,
  }) async {
    _autosaveDebounce?.cancel();

    final plainText = document.toPlainText().trim();

    // Don't save if it's completely empty
    if ((title.trim() + plainText).isEmpty) return;

    if (_isSaving) return; // Avoids double saving
    _isSaving = true;

    try {
      saveState.value = SaveState.saving;

      final resolvedTitle = title.trim().isEmpty
          ? 'Untitled note'
          : title.trim();

      final saved = await noteRepository.saveNote(
        noteId: noteId,
        title: resolvedTitle,
        content: plainText,
        richContent: jsonEncode(document.toDelta().toJson()),
      );

      // Brief delay to ensure the UI "Saving..." animation is visible to the user
      await Future.delayed(const Duration(milliseconds: 500));

      if (saved != null) {
        noteId = saved.id;
      }

      _lastEditorSignature = _editorSignature(title, document);
      saveState.value = SaveState.saved;
    } catch (e) {
      // Revert to idle on error to prevent UI hang
      saveState.value = SaveState.idle;
      debugPrint("Controller Save Error: $e");
    } finally {
      _isSaving = false;

      // Auto-hide the "Saved" checkmark after a fixed duration
      Future.delayed(UIConstants.saveIndicatorDuration, () {
        if (_isDisposed) return;
        if (saveState.value == SaveState.saved) {
          saveState.value = SaveState.idle;
        }
      });
    }
  }

  /// Called when navigating away to ensure final changes are persistent.
  Future<void> saveAndCleanupOnClose({
    required String title,
    required Document document,
  }) async {
    final plainText = document.toPlainText().trim();
    final cleanTitle = title.trim();

    // Clean up empty drafts from the database
    if ((cleanTitle.isEmpty || cleanTitle == 'Untitled note') &&
        plainText.isEmpty) {
      if (noteId != null) {
        await noteRepository.deleteForever(noteId!);
      }
      return;
    }

    await saveNote(title: title, document: document);
  }

  /// -------------------------------------------------------------------------
  /// 2. VOICE AI PIPELINE (Migrated from NotePage)
  /// -------------------------------------------------------------------------

  Future<void> initSpeech() async {
    if (_speechInitialized) return;
    if (_initTask != null) return _initTask; // Return existing task if running

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
      _initTask = null; // Reset task regardless of outcome
    }
  }

  void toggleListening(QuillController contentController) async {
    if (isListening.value) {
      _cleanupListening(cancelRobot: true);
      return;
    }

    // PHASE 1: UI FEEDBACK (Instant)
    // The robot starts spinning the millisecond the user taps.
    isProcessingVoice.value = true;

    // PHASE 2: HARDWARE WARMUP
    if (!_speechInitialized) {
      await initSpeech();
      if (!_speechInitialized) {
        isProcessingVoice.value = false;
        return;
      }
    }

    // 3. Listening Execution
    isListening.value = true;
    _lastWords = '';

    _speechTimer = Timer(const Duration(seconds: 5), () {
      if (_lastWords.trim().isEmpty) {
        _cleanupListening(cancelRobot: true);
      }
    });

    _speech.listen(
      onResult: (result) {
        _lastWords = result.recognizedWords;

        _speechTimer?.cancel();
        _speechTimer = Timer(const Duration(milliseconds: 1000), () {
          if (_lastWords.trim().isNotEmpty) {
            _cleanupListening();
            _processVoiceCommandAndFeedback(_lastWords, contentController);
          }
        });
      },
    );
  }

  void _cleanupListening({bool cancelRobot = false}) {
    _speechTimer?.cancel();
    _speech.stop();
    isListening.value = false;
    if (cancelRobot) isProcessingVoice.value = false;
  }

  /// Orchestrates Voice AI formatting using Groq and VoiceFormattingService.
  Future<void> _processVoiceCommandAndFeedback(
    String commandText,
    QuillController controller,
  ) async {
    isProcessingVoice.value = true;

    Future.microtask(() async {
      FocusManager.instance.primaryFocus?.unfocus();
      await Future.delayed(const Duration(milliseconds: 50));

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
        uiNotifier.showSnackBar(
          const SnackBar(content: Text('AI service error. Try again.')),
        );
      }
    });
  }

  /// Clean up all listeners and timers to prevent memory leaks.
  /// -------------------------------------------------------------------------
  /// 3. LIFECYCLE
  /// -------------------------------------------------------------------------

  void dispose() {
    _isDisposed = true;
    _cleanupListening();
    _autosaveDebounce?.cancel();
    saveState.dispose();
    isProcessingVoice.dispose();
    isListening.dispose();
    _fadeVisibilityDebounce?.cancel();
    aiButtonOpacity.dispose();
  }
}
