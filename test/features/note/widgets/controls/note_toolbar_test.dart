import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/controllers/note_toolbar_controller.dart';
import 'package:notepad/features/note/widgets/controls/note_toolbar.dart';

void main() {
  testWidgets('NoteToolbar renders style toggle buttons', (tester) async {
    final controller = QuillController.basic();
    final toolbarController = NoteToolbarController();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteToolbar(
            controller: controller,
            toolbarController: toolbarController,
            focusNode: focusNode,
            shouldNudge: false,
          ),
        ),
      ),
    );

    // Verify presence of core formatting icons
    expect(find.byIcon(Icons.format_bold), findsOneWidget);
    expect(find.byIcon(Icons.format_italic), findsOneWidget);
    expect(find.byIcon(Icons.format_underlined), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outlined), findsOneWidget);
    expect(find.byIcon(Icons.link), findsOneWidget);
    
    // Test a simple interaction
    await tester.tap(find.byIcon(Icons.format_bold));
    await tester.pump();
    
    // Note: Checking the controller style would be the next step, 
    // but verifying the widget interaction doesn't crash is a good baseline.
  });
}
