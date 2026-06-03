// Route helpers centralize the app's navigation transitions.
import 'package:flutter/material.dart';
import 'package:notepad/core/constants/ui_constants.dart';

class AppRouter {
  // Use the slide route for primary navigation so screen changes feel continuous.
  static Route slide(Widget page) {
    return PageRouteBuilder(
      transitionDuration: UIConstants.animationSlow,
      reverseTransitionDuration: UIConstants.animationMedium,

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
      transitionDuration: UIConstants.animationMedium,
      reverseTransitionDuration: UIConstants.animationFast,

      pageBuilder: (_, _, _) => page,

      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }
}


