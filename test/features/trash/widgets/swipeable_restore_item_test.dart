import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/features/trash/widgets/swippeable_restore_item.dart';

void main() {
  testWidgets('SwipeableRestoreItem displays note info and days left', (tester) async {
    final note = NotesSection(
      id: 'note_1',
      title: 'Trash Note',
      content: 'Some content',
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
      isDeleted: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeableRestoreItem(
            key: ValueKey(note.id),
            cardWidth: 400,
            note: note,
            onRestore: (_) {},
            onShowActionSheet: (context, note) {},
          ),
        ),
      ),
    );

    expect(find.text('Trash Note'), findsOneWidget);
    expect(find.textContaining('25 days left'), findsOneWidget);
  });

  testWidgets('SwipeableRestoreItem triggers onRestore after full swipe', (tester) async {
    final note = NotesSection(
      id: 'note_1',
      title: 'Swipe Me',
      isDeleted: true,
    );

    bool restoreCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeableRestoreItem(
            key: ValueKey(note.id),
            cardWidth: 400,
            note: note,
            onRestore: (_) => restoreCalled = true,
            onShowActionSheet: (context, note) {},
          ),
        ),
      ),
    );

    // Perform a swipe from right to left (end to start)
    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(restoreCalled, isTrue);
  });
}
