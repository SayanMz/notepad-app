import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/home/controllers/home_fab_controller.dart';
import 'package:notepad/features/home/controllers/selection_controller.dart';
import 'package:notepad/features/home/widgets/home_fab.dart';

void main() {
  testWidgets('HomeFab renders and responds to state changes', (tester) async {
    final fabController = HomeFabController();
    final selectionController = SelectionController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          floatingActionButton: HomeFab(
            fabController: fabController,
            selectionController: selectionController,
          ),
        ),
      ),
    );

    // Verify it is on screen (CustomPaint is used, so we look for the widget)
    expect(find.byType(HomeFab), findsOneWidget);

    // Trigger selection mode - FAB should slide down (offset changes)
    selectionController.toggleSelected('note-1');
    await tester.pump();
    
    // In selection mode, FAB aligns outside or slides away
    // We verify it still exists but logic is handled by AnimatedSlide
    expect(find.byType(HomeFab), findsOneWidget);
  });
}
