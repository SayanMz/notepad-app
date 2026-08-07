import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/widgets/editor/note_title_bar.dart';

void main() {
  testWidgets('NoteTitleBar allows editing and triggers toggle', (tester) async {
    final titleController = TextEditingController(text: 'Initial Title');
    bool toggleCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteTitleBar(
            titleController: titleController,
            onToggleEdit: () => toggleCalled = true,
            readOnly: false,
          ),
        ),
      ),
    );

    // Check title text
    expect(find.text('Initial Title'), findsOneWidget);

    // Edit title
    await tester.enterText(find.byType(TextField), 'New Title');
    expect(titleController.text, 'New Title');

    // Tap magic wand button
    await tester.tap(find.byIcon(Icons.auto_fix_high));
    expect(toggleCalled, isTrue);
  });
}
