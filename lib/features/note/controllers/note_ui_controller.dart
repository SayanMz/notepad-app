import 'dart:async';

import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/features/note/note_constants.dart';

/// Strictly handles visual view states, animation timings, and layout opacities.
class NoteUIController {
  /// Controls the overall alpha opacity layer of floating action elements
  final ValueNotifier<double> aiButtonOpacity = ValueNotifier<double>(1.0);

  /// ⚡ MOVED HERE: Tracks whether the keyboard/toolbar layout mode is active
  final ValueNotifier<bool> isEditing = ValueNotifier<bool>(false);

  Timer? _fadeVisibilityDebounce;

  void toggleEditMode() {
    isEditing.value = !isEditing.value;
  }

  /// Call this every time the user types to manage floating button visibility
  void orchestrateButtonVisibility() {
    // 1. The millisecond a user presses a key, instantly dim the button out of sight
    if (aiButtonOpacity.value != NoteConstants.aiButtonOpacityDim) {
      aiButtonOpacity.value = NoteConstants.aiButtonOpacityDim;
    }

    _fadeVisibilityDebounce?.cancel();

    // 2. The moment typing pauses, smoothly bloom the button back to life
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
