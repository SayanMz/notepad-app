import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';

// Owns home-screen motion state so the widget tree stays lightweight.
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
