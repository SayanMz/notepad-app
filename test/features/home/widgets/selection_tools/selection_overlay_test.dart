import 'package:flutter/material.dart' hide SelectionOverlay;
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/home/controllers/animation_controller.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
import 'package:notepad/features/home/controllers/selection_controller.dart';
import 'package:notepad/features/home/widgets/selection_tools/selection_overlay.dart';

void main() {
  testWidgets('SelectionOverlay responds to selection mode changes', (tester) async {
    final selectionController = SelectionController();
    final controller = HomeController(
      selectionController: selectionController,
      animationController: AnimationControllerState(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectionOverlay(controller: controller),
        ),
      ),
    );

    // Initial state: Hidden (offset is non-zero)
    final slideFinder = find.byType(AnimatedSlide);
    AnimatedSlide slide = tester.widget(slideFinder);
    expect(slide.offset.dy, isNonZero);

    // Enter selection mode
    selectionController.toggleSelected('note-1');
    
    // Since SelectionOverlay doesn't listen to the controller directly, 
    // we re-pump the tree to simulate a parent-driven rebuild.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectionOverlay(controller: controller),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    // Now it should be at Offset.zero
    slide = tester.widget(slideFinder);
    expect(slide.offset, Offset.zero);
  });
}
