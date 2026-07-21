import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/features/search/services/smooth_slide_fade.dart';

void main() {
  testWidgets(
    'SmoothSlideFade hides and reveals its child based on visibility',
    (tester) async {
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

      expect(find.text('Search panel'), findsNothing);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SmoothSlideFade(isVisible: true, child: Text('Search panel')),
          ),
        ),
      );

      await tester.pump(AnimationConstants.extraLong);

      expect(find.text('Search panel'), findsOneWidget);
    },
  );
}
