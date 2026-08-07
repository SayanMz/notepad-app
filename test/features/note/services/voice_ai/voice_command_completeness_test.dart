import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/services/voice_ai/voice_formatting_service.dart';

/// Completeness test suite based on the "All test commands.docx" document.
/// This verifies that the formatting engine handles every category of command listed.
void main() {
  group('Completeness Test Suite (Document-based)', () {
    late QuillController controller;

    setUp(() {
      controller = QuillController.basic();
    });

    void runTest({
      required String name,
      required String initialText,
      required List<Map<String, dynamic>> instructions,
      required void Function(Document doc) verify,
      TextSelection? selection,
    }) {
      test(name, () {
        controller.document = Document()..insert(0, initialText);
        if (selection != null) {
          controller.updateSelection(selection, ChangeSource.local);
        }

        VoiceFormattingService.applyInstructions(
          controller: controller,
          instructions: instructions,
          commandText: name,
        );

        verify(controller.document);
      });
    }

    // 1. Global Document Commands
    runTest(
      name: 'Nuke it (Clear All)',
      initialText: 'Bold and Red.',
      instructions: [
        {'target': 'all', 'key': 'unformat_all', 'value': true}
      ],
      verify: (doc) {
        expect(doc.collectStyle(0, doc.length - 1).attributes, isEmpty);
      },
    );

    runTest(
      name: 'Align the entire document to the center',
      initialText: 'Text to align.',
      instructions: [
        {'target': 'all', 'key': 'align', 'value': 'center'}
      ],
      verify: (doc) {
        expect(doc.collectStyle(0, 1).attributes['align']?.value, 'center');
      },
    );

    // 2. Selection-Based Commands
    runTest(
      name: 'Highlight this in red',
      initialText: 'Target this text.',
      selection: const TextSelection(baseOffset: 7, extentOffset: 11),
      instructions: [
        {'target': 'selection', 'key': 'color', 'value': '#FF0000'}
      ],
      verify: (doc) {
        expect(doc.collectStyle(7, 1).attributes['color']?.value, '#FF0000');
        expect(doc.collectStyle(0, 1).attributes['color'], isNull);
      },
    );

    // 3. Positional Targeting
    runTest(
      name: 'Underline the second sentence',
      initialText: 'Sentence one. Sentence two. Sentence three.',
      instructions: [
        {'target': 'line:second', 'key': 'underline', 'value': true}
      ],
      verify: (doc) {
        // Sentence one ends at index 13 (including period and space)
        // Sentence two starts at 14. "Sentence two." is 13 chars.
        expect(doc.collectStyle(14, 10).attributes['underline'], isNotNull);
        expect(doc.collectStyle(0, 1).attributes['underline'], isNull);
      },
    );

    runTest(
      name: 'Push the second paragraph to the right',
      initialText: 'Para 1.\n\nPara 2.\n\nPara 3.',
      instructions: [
        {'target': 'paragraph:second', 'key': 'align', 'value': 'right'}
      ],
      verify: (doc) {
        // Para 1 is 0-8. Para 2 starts at 9.
        expect(doc.collectStyle(9, 7).attributes['align']?.value, 'right');
        expect(doc.collectStyle(0, 1).attributes['align'], isNull);
      },
    );

    // 4. Literal Phrase & Occurrence
    runTest(
      name: 'Highlight the first time I said loyal in green',
      initialText: 'He was loyal and very loyal.',
      instructions: [
        {'target': 'loyal', 'key': 'color', 'value': '#00FF00', 'occurrence': 'first'}
      ],
      verify: (doc) {
        expect(doc.collectStyle(7, 5).attributes['color']?.value, '#00FF00');
        expect(doc.collectStyle(22, 5).attributes['color'], isNull);
      },
    );

    // 5. Surgical Lists
    runTest(
      name: 'Turn grocery list into bullet points',
      initialText: 'Grocery list:\nMilk\nEggs\nBread',
      instructions: [
        {'target': 'grocery list', 'key': 'list', 'value': 'bullet'}
      ],
      verify: (doc) {
        expect(doc.collectStyle(0, 12).attributes['list'], isNull);
        expect(doc.collectStyle(14, 4).attributes['list']?.value, 'bullet');
      },
    );

    // 6. Sizing
    runTest(
      name: 'Make the word warning look massive',
      initialText: 'This is a warning message.',
      instructions: [
        {'target': 'warning', 'key': 'size_change', 'value': 5}
      ],
      verify: (doc) {
        expect(doc.collectStyle(10, 7).attributes['size']?.value, 21.0);
      },
    );

    runTest(
      name: 'Make golden retriever 40 pixel',
      initialText: 'My golden retriever.',
      instructions: [
        {'target': 'golden retriever', 'key': 'size', 'value': '40'}
      ],
      verify: (doc) {
        expect(doc.collectStyle(3, 16).attributes['size']?.value, 40.0);
      },
    );

    // 7. Hyperlinks
    runTest(
      name: 'Make the bottom line point to flutter.dev',
      initialText: 'First line.\nLast line.',
      instructions: [
        {'target': 'line:last', 'key': 'link', 'value': 'flutter.dev'}
      ],
      verify: (doc) {
        // Last line starts at 12
        expect(doc.collectStyle(12, 9).attributes['link']?.value, 'https://flutter.dev');
      },
    );
  });
}
