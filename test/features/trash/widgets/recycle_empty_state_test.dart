import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/trash/widgets/recycle_empty_state.dart';

void main() {
  testWidgets('RecycleEmptyState displays text and reacts to touch', (tester) async {
    const testText = 'Your bin is as clean as a whistle!';
    
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RecycleEmptyState(text: testText),
        ),
      ),
    );

    expect(find.text(testText), findsOneWidget);
    expect(find.byIcon(Icons.delete_sweep_rounded), findsOneWidget);

    // Initial state: scale should be 1.0 (implicitly checked by verifying visibility)
    
    // Tap down to trigger scale up
    final gesture = await tester.startGesture(tester.getCenter(find.byType(Icon)));
    await tester.pump(); // Start animation
    await tester.pump(const Duration(milliseconds: 100)); // Advance animation

    // Find the AnimatedScale widget and verify it's scaling up
    final AnimatedScale animatedScale = tester.widget(find.byType(AnimatedScale));
    expect(animatedScale.scale, 1.2);

    // Release tap
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    
    final AnimatedScale restoredScale = tester.widget(find.byType(AnimatedScale));
    expect(restoredScale.scale, 1.0);
  });
}
