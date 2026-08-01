// Route helpers centralize the app's navigation transitions.
import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/constants/ui_constants.dart';

class AppRouter {
  // Use the slide route for primary navigation so screen changes feel continuous.
  static Route slide(Widget page, {bool animateReverse = true}) {
    return PageRouteBuilder(
      transitionDuration: AnimationConstants.slow,
      reverseTransitionDuration: animateReverse
          ? AnimationConstants.medium
          : Duration.zero,

      pageBuilder: (_, _, _) => page,

      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Incoming and outgoing pages animate independently so the handoff stays smooth.
        final inTween = Tween(
          begin: Offset(UIConstants.routeSlideInBeginX, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));

        final outTween = Tween(
          begin: Offset.zero,
          end: Offset(UIConstants.routeSlideOutEndX, 0),
        ).chain(CurveTween(curve: Curves.easeOut));

        return SlideTransition(
          position: animation.drive(inTween),
          child: SlideTransition(
            position: secondaryAnimation.drive(outTween),
            child: child,
          ),
        );
      },
    );
  }

  // Use the fade route for lighter, dialog-like navigation.
  static Route fade(Widget page) {
    return PageRouteBuilder(
      transitionDuration: AnimationConstants.medium,
      reverseTransitionDuration: AnimationConstants.fast,

      pageBuilder: (_, _, _) => page,

      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  // 🌟 THE SOLUTION: High-fidelity Page Scale and Fade for cleaner content handoffs
  static Route sharedAxis(Widget page) {
    return PageRouteBuilder(
      transitionDuration: AnimationConstants.medium,
      // 🌟 SNAPPY FIX: Lower the duration to 180ms for a rapid pop response
      reverseTransitionDuration: AnimationConstants.sharedAxisReverseDuration,
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Forward path stays the same; Reverse path gets a hyper-fast curve
        final scaleTween = Tween<double>(
          begin: AnimationConstants.sharedAxisScaleBegin,
          end: 1.0,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: animation.status == AnimationStatus.reverse
                ? Curves
                      .easeOutExpo // 🌟 SNAPPY FIX: Instantly jumps into motion on exit
                : Curves.fastOutSlowIn,
          ),
        );

        // Dissolve the opacity quickly in tandem with the quick acceleration curve
        final fadeTween = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: animation.status == AnimationStatus.reverse
                ? const Interval(
                    0.0,
                    AnimationConstants.sharedAxisFadeReverseCutoff,
                    curve: Curves.easeIn,
                  )
                : const Interval(
                    0.0,
                    AnimationConstants.sharedAxisFadeForwardCutoff,
                    curve: Curves.easeOut,
                  ),
          ),
        );

        return FadeTransition(
          opacity: fadeTween,
          child: ScaleTransition(scale: scaleTween, child: child),
        );
      },
    );
  }
}
