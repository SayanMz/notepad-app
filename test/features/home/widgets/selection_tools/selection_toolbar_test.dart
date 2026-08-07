import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/home/controllers/animation_controller.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
import 'package:notepad/features/home/controllers/selection_controller.dart';
import 'package:notepad/features/home/widgets/selection_tools/selection_toolbar.dart';

void main() {
  testWidgets('SelectionToolbar shows selection count', (tester) async {
    final selectionController = SelectionController();
    final controller = HomeController(
      selectionController: selectionController,
      animationController: AnimationControllerState(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectionToolbar(controller: controller),
        ),
      ),
    );

    // Initial count is 0
    expect(find.text('0'), findsOneWidget);

    // Enter selection mode manually. 
    // Since SelectionToolbar doesn't listen to the controller directly (it's driven by its parent),
    // we re-pump the widget to simulate a parent-triggered rebuild.
    selectionController.toggleSelected('note-1');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectionToolbar(controller: controller),
        ),
      ),
    );

    expect(find.text('1'), findsOneWidget);
  });
}
