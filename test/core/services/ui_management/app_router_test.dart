import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/services/ui_management/app_router.dart';

void main() {
  group('AppRouter Transitions', () {
    test('slide() returns a PageRouteBuilder with correct durations', () {
      final route = AppRouter.slide(const SizedBox());
      
      expect(route, isA<PageRouteBuilder>());
      final pageRoute = route as PageRouteBuilder;
      
      expect(pageRoute.transitionDuration, AnimationConstants.slow);
      expect(pageRoute.reverseTransitionDuration, AnimationConstants.medium);
    });

    test('fade() returns a PageRouteBuilder with correct durations', () {
      final route = AppRouter.fade(const SizedBox());
      
      expect(route, isA<PageRouteBuilder>());
      final pageRoute = route as PageRouteBuilder;
      
      expect(pageRoute.transitionDuration, AnimationConstants.medium);
      expect(pageRoute.reverseTransitionDuration, AnimationConstants.fast);
    });

    test('sharedAxis() returns a PageRouteBuilder with specific reverse duration', () {
      final route = AppRouter.sharedAxis(const SizedBox());
      
      expect(route, isA<PageRouteBuilder>());
      final pageRoute = route as PageRouteBuilder;
      
      expect(pageRoute.transitionDuration, AnimationConstants.medium);
      expect(pageRoute.reverseTransitionDuration, AnimationConstants.sharedAxisReverseDuration);
    });
  });
}
