import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/services/ui_management/theme_fader.dart';

void main() {
  tearDown(() {
    ThemeFader.isTransitioning.value = false;
  });

  testWidgets('captureAndFade overlays the frame and resets transition state',
      (tester) async {
    var themeSwapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: ThemeFader.appBoundaryKey,
            child: const SizedBox(
              width: 120,
              height: 120,
              child: ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      ),
    );

    final context = tester.element(find.byType(Scaffold));

    await tester.runAsync(() async {
      await ThemeFader.captureAndFade(
        context: context,
        executeThemeSwap: () {
          themeSwapped = true;
        },
      );
    });

    await tester.pump();
    expect(themeSwapped, isTrue);
    expect(ThemeFader.isTransitioning.value, isTrue);
    expect(find.byType(RawImage), findsOneWidget);

    await tester.pump(
      AnimationConstants.fast +
          AnimationConstants.slow +
          const Duration(milliseconds: 100),
    );
    await tester.pumpAndSettle();

    expect(ThemeFader.isTransitioning.value, isFalse);
    expect(find.byType(RawImage), findsNothing);
  });
}
