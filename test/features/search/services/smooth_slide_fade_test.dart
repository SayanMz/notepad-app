import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/features/search/services/smooth_slide_fade.dart';

void main() {
  testWidgets(
    'SmoothSlideFade manages visibility via opacity and size',
    (tester) async {
      // 1. Initial State: Invisible
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SmoothSlideFade(
              isVisible: false,
              child: Text('Search panel'),
            ),
          ),
        ),
      );

      // Note: Transition-based widgets like FadeTransition keep the child in the
      // tree even when opacity is 0. We verify it's hidden by checking the value.
      expect(find.text('Search panel'), findsOneWidget);
      
      final fadeFinder = find.descendant(
        of: find.byType(SmoothSlideFade),
        matching: find.byType(FadeTransition),
      );
      
      final FadeTransition fade = tester.widget(fadeFinder);
      expect(fade.opacity.value, 0.0);

      // 2. State Change: Become Visible
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SmoothSlideFade(isVisible: true, child: Text('Search panel')),
          ),
        ),
      );

      // Advance the animation clock
      await tester.pump(AnimationConstants.slow);
      await tester.pump(const Duration(milliseconds: 100));

      // Verify it's now fully opaque
      final FadeTransition fadeVisible = tester.widget(fadeFinder);
      expect(fadeVisible.opacity.value, 1.0);
      expect(find.text('Search panel'), findsOneWidget);
    },
  );
}
