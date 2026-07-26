import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';

// Combines slide and fade transitions for search navigation.
class SmoothSlideFade extends StatelessWidget {
  final Widget child;
  final bool isVisible;

  const SmoothSlideFade({
    super.key,
    required this.child,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AnimationConstants.extraLong,
      reverseDuration: AnimationConstants.long,
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation, // 👈 Smooth continuous fade
          child: SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: child,
            ),
          ),
        );
      },
      child: isVisible
          ? child
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}
