import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/features/home/widgets/note_list_items/note_card.dart';

void main() {
  Widget buildTestCard({
    required NotesSection note,
    bool isSelectionMode = false,
    bool isSelected = false,
    bool isVaporizing = false,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    VoidCallback? onPin,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: NoteCard(
          index: 0,
          note: note,
          isSelectionMode: isSelectionMode,
          isSelected: isSelected,
          isVaporizing: isVaporizing,
          onTap: onTap ?? () {},
          onLongPress: onLongPress ?? () {},
          onPin: onPin ?? () {},
          colorNotifier: ValueNotifier(0),
          maxPreviewLines: 3,
        ),
      ),
    );
  }

  group('NoteCard Widget', () {
    testWidgets('displays note title and content preview', (tester) async {
      final note = NotesSection(
        title: 'Test Note',
        content: 'Line 1\nLine 2',
        updatedAt: DateTime(2026, 8, 4),
      );

      await tester.pumpWidget(buildTestCard(note: note));

      expect(find.text('Test Note'), findsOneWidget);
      expect(find.text('Line 1'), findsOneWidget);
    });

    testWidgets('displays Untitled Note when title is empty', (tester) async {
      final note = NotesSection(
        title: '',
        content: 'Content only',
      );

      await tester.pumpWidget(buildTestCard(note: note));

      expect(find.text('Untitled Note'), findsOneWidget);
    });

    testWidgets('shows selection icon and highlights border in selection mode', (tester) async {
      final note = NotesSection(title: 'Selection Test');

      await tester.pumpWidget(buildTestCard(
        note: note,
        isSelectionMode: true,
        isSelected: true,
      ));

      // Check for the check_circle icon
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      
      // Verify visual feedback for selected state (Card shape border in code)
      final cardFinder = find.byType(Card);
      final Card card = tester.widget(cardFinder);
      final shape = card.shape as RoundedRectangleBorder;
      expect(shape.side.color, isNot(Colors.transparent));
    });

    testWidgets('triggers callbacks on user interaction', (tester) async {
      bool tapped = false;
      bool longPressed = false;
      
      final note = NotesSection(title: 'Interaction Test');

      await tester.pumpWidget(buildTestCard(
        note: note,
        onTap: () => tapped = true,
        onLongPress: () => longPressed = true,
      ));

      await tester.tap(find.byType(NoteCard));
      expect(tapped, isTrue);

      await tester.longPress(find.byType(NoteCard));
      expect(longPressed, isTrue);
    });

    testWidgets('shows pin icon only when note is pinned', (tester) async {
      final unpinnedNote = NotesSection(title: 'Unpinned', isPinned: false);
      final pinnedNote = NotesSection(title: 'Pinned', isPinned: true);

      await tester.pumpWidget(buildTestCard(note: unpinnedNote));
      expect(find.byIcon(Icons.push_pin), findsNothing);

      await tester.pumpWidget(buildTestCard(note: pinnedNote));
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
    });
  });
}
