import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/widgets/note_app_bar.dart';
import 'package:notepad/features/note/widgets/status/save_indicator.dart';

void main() {
  testWidgets('NoteAppBar displays history controls and more actions', (tester) async {
    final titleController = TextEditingController(text: 'Test Title');
    final contentController = QuillController.basic();
    final saveState = ValueNotifier<SaveState>(SaveState.idle);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: NoteAppBar(
            readOnly: false,
            title: titleController,
            contentController: contentController,
            saveState: saveState,
          ),
        ),
      ),
    );

    // Verify Undo/Redo presence
    expect(find.byIcon(Icons.undo), findsOneWidget);
    expect(find.byIcon(Icons.redo), findsOneWidget);

    // Verify SaveIndicator presence
    expect(find.byType(SaveIndicator), findsOneWidget);

    // Open More Menu
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Save as PDF'), findsOneWidget);
    expect(find.text('Share Note'), findsOneWidget);
  });
}
