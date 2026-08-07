import 'dart:async';

import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/features/note/note_constants.dart';

/// Manages editor-only UI state such as edit mode and AI button visibility.
class NoteUIController {
  final ValueNotifier<double> aiButtonOpacity = ValueNotifier<double>(1.0);
  final ValueNotifier<bool> isEditing = ValueNotifier<bool>(false);

  Timer? _fadeVisibilityDebounce;

  void toggleEditMode() {
    isEditing.value = !isEditing.value;
  }

  void orchestrateButtonVisibility() {
    if (aiButtonOpacity.value != NoteConstants.aiButtonOpacityDim) {
      aiButtonOpacity.value = NoteConstants.aiButtonOpacityDim;
    }

    _fadeVisibilityDebounce?.cancel();

    _fadeVisibilityDebounce = Timer(AnimationConstants.extraLong, () {
      if (aiButtonOpacity.value != NoteConstants.aiButtonOpacityFull) {
        aiButtonOpacity.value = NoteConstants.aiButtonOpacityFull;
      }
    });
  }

  void dispose() {
    _fadeVisibilityDebounce?.cancel();
    aiButtonOpacity.dispose();
    isEditing.dispose();
  }
}
