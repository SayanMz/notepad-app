import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/services/link_handlers/hyperlink_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('convertToHyperlink handles empty selection', (tester) async {
    // This test is limited as it calls a dialog, but we can verify it returns early on empty text
    final controller = QuillController.basic();
    
    // Create a context for the handler
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => HyperlinkHandler.convertToHyperlink(
                  context: context,
                  controller: controller,
                ),
                child: const Text('Go'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Go'));
    await tester.pump();
    
    // Should not have crashed and document should remain empty
    expect(controller.document.toPlainText().trim(), isEmpty);
  });
}
