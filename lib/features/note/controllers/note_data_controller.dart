// Note data changes are tracked by signature so redundant saves can be skipped.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/features/note/widgets/save_indicator.dart';

// Tracks note signatures so autosave can skip redundant writes.
class NoteDataController {
  final NoteRepository noteRepository;
  String? noteId;

  NoteDataController({required this.noteRepository, this.noteId});

  Timer? _autosaveDebounce;
  bool _isSaving = false;
  bool _isDisposed = false;

  final ValueNotifier<SaveState> saveState = ValueNotifier<SaveState>(
    SaveState.idle,
  );

  String? _lastEditorSignature;

  void setInitialSignature(String title, Document document) {
    _lastEditorSignature = _editorSignature(title, document);
  }

  String _editorSignature(String title, Document document) {
    return '${title.trim()}\n${jsonEncode(document.toDelta().toJson())}';
  }

  bool _isStateUnchanged(String title, Document document) {
    return _lastEditorSignature == _editorSignature(title, document);
  }

  bool hasPendingChanges(String title, Document document) {
    return !_isStateUnchanged(title, document);
  }

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

  Future<void> saveNote({
    required String title,
    required Document document,
    final bool notify = false,
  }) async {
    _autosaveDebounce?.cancel();
    final plainText = document.toPlainText().trim();

    if (noteId == null && title.isEmpty && plainText.isEmpty) {
      return;
    }

    if (_isSaving || _isStateUnchanged(title, document)) {
      return;
    }

    _isSaving = true;

    try {
      saveState.value = SaveState.saving;

      final resolvedTitle = title.isEmpty ? 'Untitled note' : title;

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

  Future<void> saveAndCleanupOnClose({
    required String title,
    required Document document,
  }) async {
    final plainText = document.toPlainText().trim();
    final cleanTitle = title.trim();

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
