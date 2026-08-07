import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/bootstrap/app_startup_builder.dart';

void main() {
  testWidgets('AppStartupBuilder shows error view when bootstrap fails and succeeds on retry',
      (tester) async {
    int callCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AppStartupBuilder(
          bootstrapper: () async {
            callCount++;
            if (callCount == 1) {
              throw Exception('Test bootstrap failure');
            }
          },
          child: const Text('App Content'),
        ),
      ),
    );

    // 1. Initial failure
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Notepad could not start'), findsOneWidget);
    expect(find.textContaining('Test bootstrap failure'), findsOneWidget);

    // 2. Tap Retry
    await tester.tap(find.text('Retry'));
    
    // We use pump() and then a small duration to let the retry Future complete
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Now it should show success content
    expect(find.text('App Content'), findsOneWidget);
    expect(find.text('Notepad could not start'), findsNothing);
    expect(callCount, 2);
  });
}
