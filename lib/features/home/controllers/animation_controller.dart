import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';

/// ------------------------------------------------------------
/// ANIMATION CONTROLLER (UI State)
/// Handles visual timing states like vaporizing/dismissing.
/// ------------------------------------------------------------
class AnimationControllerState extends ChangeNotifier {
  final Set<String> _vaporizingIds = {};

  bool isVaporizing(String id) => _vaporizingIds.contains(id);

  Future<void> triggerVaporizeAnimation(Set<String> noteIds) async {
    if (noteIds.isEmpty) return;

    _vaporizingIds.addAll(noteIds);
    notifyListeners();

    await Future.delayed(AnimationConstants.medium);

    _vaporizingIds.removeAll(noteIds);
    notifyListeners();
  }
}
