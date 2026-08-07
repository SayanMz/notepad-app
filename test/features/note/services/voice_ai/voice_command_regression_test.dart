import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/services/voice_ai/voice_formatting_service.dart';

/// This test suite allows for rapid regression testing of voice commands.
/// To add a new command that was previously "rejected", simply add a new entry to the [cases] list.
void main() {
  group('Voice Command Regression Suite', () {
    late QuillController controller;

    setUp(() {
      controller = QuillController.basic();
    });

    final cases = [
      _VoiceTestCase(
        name: 'Global Clear',
        command: 'Clear all formatting.',
        initialText: 'Some bold text here.',
        initialSelection: const TextSelection.collapsed(offset: 0),
        mockAiInstructions: [
          {
            'target': 'all',
            'key': 'unformat_all',
            'value': true,
            'occurrence': 'all',
          },
        ],
        verify: (doc) {
          expect(doc.collectStyle(0, doc.length - 1).attributes, isEmpty);
        },
      ),
      _VoiceTestCase(
        name: 'Positional Line Bold',
        command: 'Make the first line bold.',
        initialText: 'Line 1\nLine 2',
        mockAiInstructions: [
          {
            'target': 'line:first',
            'key': 'bold',
            'value': true,
            'occurrence': 'all',
          },
        ],
        verify: (doc) {
          expect(doc.collectStyle(0, 6).attributes['bold'], isNotNull);
        },
      ),
      _VoiceTestCase(
        name: 'Surgical Checklist',
        command: 'Make menu items a checklist.',
        initialText: 'Menu items:\nPizza\nBurger',
        mockAiInstructions: [
          {
            'target': 'menu items',
            'key': 'list',
            'value': 'unchecked',
            'occurrence': 'all',
          },
        ],
        verify: (doc) {
          // "Menu items:" (11 chars) should NOT be list
          expect(doc.collectStyle(0, 11).attributes['list'], isNull);
          // "Pizza" should be checklist
          expect(
            doc.collectStyle(12, 5).attributes['list']?.value,
            'unchecked',
          );
        },
      ),
      _VoiceTestCase(
        name: 'Literal Word Color',
        command: 'Make the word dog red.',
        initialText: 'The cat and the dog.',
        mockAiInstructions: [
          {
            'target': 'dog',
            'key': 'color',
            'value': '#FF0000',
            'occurrence': 'all',
          },
        ],
        verify: (doc) {
          expect(doc.collectStyle(16, 3).attributes['color']?.value, '#FF0000');
        },
      ),
      _VoiceTestCase(
        name: 'Nth Occurrence Italic',
        command: 'Make the second instance of hello italic.',
        initialText: 'hello one, hello two',
        mockAiInstructions: [
          {
            'target': 'hello',
            'key': 'italic',
            'value': true,
            'occurrence': 'second',
          },
        ],
        verify: (doc) {
          expect(doc.collectStyle(0, 5).attributes['italic'], isNull);
          expect(doc.collectStyle(11, 5).attributes['italic'], isNotNull);
        },
      ),
      _VoiceTestCase(
        name: 'Relative Sizing (Small)',
        command: 'Make this small.',
        initialText: 'Shrink me.',
        initialSelection: const TextSelection(baseOffset: 0, extentOffset: 9),
        mockAiInstructions: [
          {
            'target': 'selection',
            'key': 'size_change',
            'value': -5,
            'occurrence': 'all',
          },
        ],
        verify: (doc) {
          // Default 16 - 5 = 11
          expect(doc.collectStyle(0, 9).attributes['size']?.value, 11.0);
        },
      ),
      _VoiceTestCase(
        name: 'Link Engine (Selection)',
        command: 'Link this to google.com.',
        initialText: 'Click here.',
        initialSelection: const TextSelection(baseOffset: 6, extentOffset: 10),
        mockAiInstructions: [
          {
            'target': 'selection',
            'key': 'link',
            'value': 'google.com',
            'occurrence': 'all',
          },
        ],
        verify: (doc) {
          final style = doc.collectStyle(6, 4);
          // Current implementation doesn't prepend to selection
          expect(style.attributes['link']?.value, 'google.com');
        },
      ),
    ];

    for (final tc in cases) {
      test(tc.name, () {
        controller.document = Document()..insert(0, tc.initialText);
        if (tc.initialSelection != null) {
          controller.updateSelection(tc.initialSelection!, ChangeSource.local);
        }

        VoiceFormattingService.applyInstructions(
          controller: controller,
          instructions: tc.mockAiInstructions,
          commandText: tc.command,
        );

        tc.verify(controller.document);
      });
    }
  });
}

class _VoiceTestCase {
  final String name;
  final String command;
  final String initialText;
  final TextSelection? initialSelection;
  final List<Map<String, dynamic>> mockAiInstructions;
  final void Function(Document doc) verify;
  final bool shouldFail;

  _VoiceTestCase({
    required this.name,
    required this.command,
    required this.initialText,
    this.initialSelection,
    required this.mockAiInstructions,
    required this.verify,
  }) : shouldFail = false;
}
