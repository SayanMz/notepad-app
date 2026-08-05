import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/home/widgets/drawer_items/storage_progress_bar.dart';
import 'package:notepad/core/theme/app_colors.dart';

void main() {
  testWidgets('StorageProgressBar renders correct colors based on progress', (tester) async {
    // 1. Normal progress
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StorageProgressBar(progress: 0.5),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Check for the inner container (the progress indicator)
    // It's inside a FractionallySizedBox which is inside a RepaintBoundary/TweenAnimationBuilder
    final containerFinder = find.descendant(
      of: find.byType(FractionallySizedBox),
      matching: find.byType(Container),
    );
    
    final Container container = tester.widget(containerFinder);
    final decoration = container.decoration as BoxDecoration;
    // For normal progress (0.5), it should not be AppColors.storageCritical
    expect(decoration.color, isNot(AppColors.storageCritical));

    // 2. Critical progress (> 0.9)
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StorageProgressBar(progress: 0.95),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final Container criticalContainer = tester.widget(containerFinder);
    final criticalDecoration = criticalContainer.decoration as BoxDecoration;
    expect(criticalDecoration.color, AppColors.storageCritical);
  });
}
