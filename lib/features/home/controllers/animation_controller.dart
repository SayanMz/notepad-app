import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';

// Owns the short-lived vaporize animation state for deleted notes.
class AnimationControllerState extends ChangeNotifier {
  final Set<String> _vaporizingIds = {};

  bool isVaporizing(String id) => _vaporizingIds.contains(id);

  Future<void> triggerVaporizeAnimation(Set<String> noteIds) async {
    if (noteIds.isEmpty) return;

    _vaporizingIds.addAll(noteIds);
    notifyListeners();

    await Future.delayed(AnimationConstants.medium);

    _vaporizingIds.removeAll(noteIds);
  }
}
