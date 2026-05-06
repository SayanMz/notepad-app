import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/features/note/services/groq_service.dart';
import 'package:notepad/features/note/data/note_repository.dart';
import 'package:notepad/features/note/services/note_recovery_service.dart';
import 'package:notepad/features/note/services/voice_formatting_service.dart';
import 'package:notepad/features/note/widgets/save_indicator.dart';

/// Handles all non-UI logic for NotePage:
/// - Autosave (debounced)
/// - Crash recovery (shadow drafts)
/// - Persistent save (repository)
class NoteController {
  final NoteRecoveryService recoveryService;
  final NoteRepository noteRepository;

  NoteController({
    required this.recoveryService,
    required this.noteRepository,
    this.noteId,
  });

  Timer? _autosaveDebounce;
  bool _isDisposed = false;

  /// Prevents overlapping saves
  bool _isSaving = false;

  /// Current note ID (null for new note)
  String? noteId;
  final ValueNotifier<SaveState> saveState = ValueNotifier<SaveState>(
    SaveState.idle,
  );
  String? _lastEditorSignature;

  /// Called whenever editor content changes
  ///
  /// FLOW:
  /// 1. Immediate shadow save (fast, crash-safe)
  /// 2. Debounced persistent save (slow, disk-heavy)
  void handleEditorChanged({
    required String title,
    required Document document,
  }) {
    final currentSignature = _editorSignature(title, document);
    //Nothing has changed so skip saving - #Guard Clause or the "Bouncer Pattern"
    if (_lastEditorSignature == currentSignature) {
      return;
    }

    _lastEditorSignature = currentSignature;

    // Crash recovery (lightweight)
    recoveryService.saveShadowDraft(NoteRecoveryService.draftKey, [
      title,
      document.toPlainText(),
    ]);

    // Debounce persistent save
    _autosaveDebounce?.cancel();

    _autosaveDebounce = Timer(
      UIConstants.saveIndicatorDuration,
      () => saveNote(title: title, document: document),
    );
  }

  String _editorSignature(String title, Document document) {
    return '${title.trim()}\n${jsonEncode(document.toDelta().toJson())}';
  }

  /// Saves note to repository
  ///
  /// Uses "latest-wins" strategy to avoid race conditions

  Future<void> saveNote({
    required String title,
    required Document document,
  }) async {
    _autosaveDebounce?.cancel();

    final plainText = document.toPlainText().trim();
    // Don't save if it's completely empty
    if ((title.trim() + plainText).isEmpty) return;

    if (_isSaving) return; //avoids double saving
    _isSaving = true;

    saveState.value = SaveState.saving;
    await Future.delayed(Duration(milliseconds: 500));

    try {
      final resolvedTitle = title.trim().isEmpty
          ? 'Untitled note'
          : title.trim();

      final saved = noteRepository.saveNote(
        noteId: noteId, // Passes current ID (null if new)
        title: resolvedTitle,
        content: plainText,
        richContent: jsonEncode(document.toDelta().toJson()),
      );

      //Only update ID if a note was actually created/updated.
      // If 'saved' is null (no changes), KEEP existing noteId.
      if (saved != null) {
        noteId = saved
            .id; // This id would be passed to the save above, ensures proper update
      }

      _lastEditorSignature = _editorSignature(title, document);
    } finally {
      _isSaving = false;
      saveState.value = SaveState.saved;

      Future.delayed(UIConstants.saveIndicatorDuration, () {
        if (_isDisposed) return;

        if (saveState.value == SaveState.saved) {
          saveState.value = SaveState.idle;
        }
      });
    }
  }

  /// Called ONLY when the user presses the back button to leave the page.
  /// Cleans up the database if they left the note completely blank.
  void saveAndCleanupOnClose({
    required String title,
    required Document document,
  }) {
    final plainText = document.toPlainText().trim();
    final cleanTitle = title.trim();

    // Catch it if it's completely empty OR if it's an empty 'Untitled note'
    if ((cleanTitle.isEmpty || cleanTitle == 'Untitled note') &&
        plainText.isEmpty) {
      if (noteId != null) {
        noteRepository.deleteForever(noteId!);
      }
      return;
    }

    saveNote(title: title, document: document);
  }

  /// State for the voice processing spinner
  final ValueNotifier<bool> isProcessingVoice = ValueNotifier<bool>(false);

  Future<String?> processVoiceCommand({
    required String commandText,
    required QuillController controller,
  }) async {
    if (commandText.isEmpty) return null;
    isProcessingVoice.value = true;

    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      // 1. Fetch instructions from the API service
      final instructions = await GroqService.parseVoiceCommand(commandText);

      if (instructions == null || instructions.isEmpty) {
        return 'No instructions found.';
      }

      // 2. Pass the instructions to your new Formatting service
      final feedback = VoiceFormattingService.applyInstructions(
        instructions: instructions,
        controller: controller,
        commandText: '',
      );

      return feedback;
    } catch (e) {
      return 'Error: $e';
    } finally {
      isProcessingVoice.value = false;
    }
  }

  void dispose() {
    _isDisposed = true;
    _autosaveDebounce?.cancel();
    saveState.dispose();
  }
}

/*
Interview Note: "I designed the AI integration to be fully data-driven. 
Instead of writing brittle parsing logic with hardcoded switch cases in Dart, 
I prompt-engineered the LLM to output exact flutter_quill Delta JSON keys. 
This allows me to use Quill's native deserialization, reducing my processing 
logic to a single line of code and making the architecture instantly scalable for new formatting features."
*/
