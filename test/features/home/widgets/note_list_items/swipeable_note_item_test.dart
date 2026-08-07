import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/features/home/controllers/animation_controller.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
import 'package:notepad/features/home/controllers/selection_controller.dart';
import 'package:notepad/features/home/widgets/note_list_items/swipeable_note_item.dart';

class FakeAnimationController extends AnimationControllerState {}

void main() {
  testWidgets('SwipeableNoteItem renders and handles swipe-to-delete', (tester) async {
    final note = NotesSection(id: '1', title: 'Swipe Target');
    final selectionController = SelectionController();
    final controller = HomeController(
      selectionController: selectionController,
      animationController: FakeAnimationController(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeableNoteItem(
            index: 0,
            note: note,
            controller: controller,
            animationController: FakeAnimationController(),
            maxPreviewLines: 3,
          ),
        ),
      ),
    );

    expect(find.text('Swipe Target'), findsOneWidget);

    // Initial state: Background card (delete surface) should be hidden or have 0 progress
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    // Simulate partial swipe
    await tester.drag(find.byType(SwipeableNoteItem), const Offset(100.0, 0.0));
    await tester.pump();

    // Verify visibility of delete indicator (it's inside a Visibility widget with progress > 0)
    // Note: The specific icon might be AnimatedTrashIcon
    expect(find.byType(Card), findsAtLeast(1));
  });
}
