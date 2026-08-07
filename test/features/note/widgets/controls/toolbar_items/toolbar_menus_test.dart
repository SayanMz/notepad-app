import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/controllers/note_toolbar_controller.dart';
import 'package:notepad/features/note/widgets/controls/toolbar_items/alignment_menu.dart';

void main() {
  testWidgets('AlignmentMenu opens and selects center alignment', (tester) async {
    final controller = QuillController.basic();
    final toolbarController = NoteToolbarController();
    final menuController = MenuController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AlignmentMenu(
            controller: controller,
            toolbarController: toolbarController,
            menuController: menuController,
            selectionStyle: const Style(),
          ),
        ),
      ),
    );

    // 1. Open Menu
    await tester.tap(find.byIcon(Icons.format_align_justify));
    await tester.pumpAndSettle();

    expect(find.text('Center'), findsOneWidget);

    // 2. Select Center
    await tester.tap(find.text('Center'));
    await tester.pumpAndSettle();

    // Verify formatting (Center Align value is 'center')
    final attr = controller.getSelectionStyle().attributes[Attribute.align.key];
    expect(attr?.value, 'center');
  });
}
