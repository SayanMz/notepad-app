import 'package:flutter/material.dart';

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
      // Standardized values for your BCA project
      duration: const Duration(milliseconds: 800),
      reverseDuration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
          ),
          child: SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1.0,
            child: child,
          ),
        );
      },
      child: isVisible
          ? child
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}
