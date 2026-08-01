import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/features/note/services/link_handlers/link_detector_service.dart';
import 'package:notepad/features/note/widgets/status/save_indicator.dart';

/// Handles note persistence, autosave, scroll state, and link detection triggers.
class NoteDataController {
  final NoteRepository noteRepository;
  String? noteId;

  NoteDataController({required this.noteRepository, this.noteId});

  Timer? _autosaveDebounce;
  Timer? _detectionDebounce;
  bool _isSaving = false;
  bool _isDisposed = false;

  final ValueNotifier<SaveState> saveState = ValueNotifier<SaveState>(
    SaveState.idle,
  );

  String? _lastEditorSignature;
  double _lastSavedScrollOffset = 0.0;

  void setInitialSignature(
    String title,
    Document document,
    double scrollOffset,
  ) {
    _lastEditorSignature = _editorSignature(title, document);
    _lastSavedScrollOffset = scrollOffset;
  }

  String _editorSignature(String title, Document document) {
    return '${title.trim()}\n${jsonEncode(document.toDelta().toJson())}';
  }

  void handleEditorChanged({
    required String title,
    required Document document,
    required QuillController controller,
    required DocChange? change,
  }) {
    if (change != null && change.source != ChangeSource.local) return;

    final textUnchanged =
        _lastEditorSignature == _editorSignature(title, document);
    if (textUnchanged) return;

    _autosaveDebounce?.cancel();
    _autosaveDebounce = Timer(
      AnimationConstants.saveIndicator,
      () => saveNote(title: title.trim(), document: document),
    );

    _detectionDebounce?.cancel();
    _detectionDebounce = Timer(
      const Duration(milliseconds: 600),
      () => LinkDetectorService.scanAndLinkifyParagraph(controller),
    );
  }

  void handleScrollEvent({
    required String title,
    required Document document,
    required double scrollOffset,
  }) {
    // Prevent spamming the database if the pixel offset hasn't actually moved
    final scrollUnchanged = _lastSavedScrollOffset == scrollOffset;
    if (scrollUnchanged) return;

    _lastSavedScrollOffset = scrollOffset;

    _autosaveDebounce?.cancel();
    _autosaveDebounce = Timer(
      AnimationConstants.saveIndicator,
      () => saveNote(
        title: title.trim(),
        document: document,
        scrollOffset: scrollOffset,
        isScrollUpdate: true,
      ),
    );
  }

  Future<void> saveNote({
    required String title,
    required Document document,
    double scrollOffset = 0.0,
    bool isScrollUpdate = false,
    final bool notify = false,
  }) async {
    _autosaveDebounce?.cancel();
    final plainText = document.toPlainText().trim();

    if (noteId == null && title.isEmpty && plainText.isEmpty) return;

    // Safety check against recursive loops
    if (_isSaving) return;
    _isSaving = true;

    try {
      if (!isScrollUpdate) {
        saveState.value = SaveState.saving;
      }
      final resolvedTitle = title.isEmpty ? 'Untitled note' : title;

      final saved = await noteRepository.saveNote(
        noteId: noteId,
        title: resolvedTitle,
        content: plainText,
        richContent: jsonEncode(document.toDelta().toJson()),
        scrollOffset: scrollOffset,
        notify: notify,
      );

      if (saved != null) {
        noteId = saved.id;
      }

      // Update baselines
      _lastEditorSignature = _editorSignature(title, document);

      if (!isScrollUpdate) {
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
      }
    } catch (e) {
      saveState.value = SaveState.idle;
      debugPrint('Data Controller Save Error: $e');
    } finally {
      _isSaving = false;
    }
  }

  Future<void> saveAndCleanupOnClose({
    required String title,
    required Document document,
    required double scrollOffset,
  }) async {
    final plainText = document.toPlainText().trim();
    final cleanTitle = title.trim();

    if ((cleanTitle.isEmpty || cleanTitle == 'Untitled note') &&
        plainText.isEmpty) {
      if (noteId != null) await noteRepository.deleteForever(noteId!);
      return;
    }

    await saveNote(
      title: cleanTitle,
      document: document,
      scrollOffset: scrollOffset,
      notify: true,
    );
  }

  void dispose() {
    _isDisposed = true;
    _autosaveDebounce?.cancel();
    _detectionDebounce?.cancel();
    saveState.dispose();
  }
}
