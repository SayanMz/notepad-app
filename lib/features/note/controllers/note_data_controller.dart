import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/data/notes_repository.dart';
import 'package:notepad/features/note/widgets/save_indicator.dart';

/// Handles purely file system I/O, autosave debouncing, and dirty state hashing.
class NoteDataController {
  final NoteRepository noteRepository;
  String? noteId;

  NoteDataController({required this.noteRepository, this.noteId});

  Timer? _autosaveDebounce;
  bool _isSaving = false;
  bool _isDisposed = false;

  /// Surgical UI State: Notifies the page when to show the saving indicator
  final ValueNotifier<SaveState> saveState = ValueNotifier<SaveState>(
    SaveState.idle,
  );

  /// Dirty State Tracking
  String? _lastEditorSignature;

  /// Sets the initial baseline for comparison so hasPendingChanges accurately detects modifications.
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

  /// Exposes state checking for the UI back-navigation guard
  bool hasPendingChanges(String title, Document document) {
    return !_isStateUnchanged(title, document);
  }

  /// Called whenever editor content changes. Uses a Bouncer Pattern.
  void handleEditorChanged({
    required String title,
    required Document document,
  }) {
    _autosaveDebounce?.cancel();
    _autosaveDebounce = Timer(
      AnimationConstants.saveIndicator,
      () => saveNote(title: title.trim(), document: document),
    );
  }

  /// Saves note to repository with a "latest-wins" strategy.
  Future<void> saveNote({
    required String title,
    required Document document,
    final bool notify = false,
  }) async {
    _autosaveDebounce?.cancel();
    final plainText = document.toPlainText().trim();

    // ⚡ Ghost Wipe Guard: If it's a completely new blank draft, don't write anything.
    // If noteId is NOT null, it allows the user to intentionally clear an existing note!
    if (noteId == null && title.isEmpty && plainText.isEmpty) {
      return;
    }

    // Skip redundant operations
    if (_isSaving || _isStateUnchanged(title, document)) {
      return;
    }

    _isSaving = true;

    try {
      saveState.value = SaveState.saving;

      final resolvedTitle = title.isEmpty ? 'Untitled note' : title;

      // Note: If noteId != null and fields are empty, this correctly saves empty values to Hive.
      final saved = await noteRepository.saveNote(
        noteId: noteId,
        title: resolvedTitle,
        content: plainText,
        richContent: jsonEncode(document.toDelta().toJson()),
        notify: notify,
      );

      if (saved != null) {
        noteId = saved.id;
      }

      _lastEditorSignature = _editorSignature(title, document);

      Future.delayed(AnimationConstants.extraSlow, () {
        if (_isDisposed) return;

        saveState.value = SaveState.saved;

        Future.delayed(AnimationConstants.saveIndicator, () {
          if (_isDisposed) return;
          if (saveState.value == SaveState.saved) {
            saveState.value = SaveState.idle;
          }
        });
      });
    } catch (e) {
      saveState.value = SaveState.idle;
      debugPrint("Data Controller Save Error: $e");
    } finally {
      _isSaving = false;
    }
  }

  /// Executed ONLY during manual back-navigation to destroy abandoned empty drafts.
  Future<void> saveAndCleanupOnClose({
    required String title,
    required Document document,
  }) async {
    final plainText = document.toPlainText().trim();
    final cleanTitle = title.trim();

    // Clean up empty drafts permanently from the database
    if ((cleanTitle.isEmpty || cleanTitle == 'Untitled note') &&
        plainText.isEmpty) {
      if (noteId != null) {
        await noteRepository.deleteForever(noteId!);
      }
      return;
    }

    await saveNote(title: cleanTitle, document: document, notify: true);
  }

  void dispose() {
    _isDisposed = true;
    _autosaveDebounce?.cancel();
    saveState.dispose();
  }
}
