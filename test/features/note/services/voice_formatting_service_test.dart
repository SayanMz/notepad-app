import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/services/voice_ai/voice_formatting_service.dart';

QuillController _controllerFor(
  String text, {
  TextSelection? selection,
}) {
  return QuillController(
    document: Document()..insert(0, text),
    selection: selection ?? const TextSelection.collapsed(offset: 0),
    keepStyleOnNewLine: false,
  );
}

void main() {
  test('applyInstructions can clear all formatting in one pass', () {
    final controller = _controllerFor(
      'Hello world',
      selection: const TextSelection(baseOffset: 0, extentOffset: 5),
    );
    controller.formatSelection(Attribute.bold);

    final before = controller.document.collectStyle(0, 1).attributes;
    expect(before.containsKey(Attribute.bold.key), isTrue);

    final result = VoiceFormattingService.applyInstructions(
      instructions: [
        {
          'target': 'all',
          'key': 'unformat_all',
          'value': true,
          'occurrence': 'all',
        },
      ],
      controller: controller,
      commandText: 'clear formatting',
    );

    expect(result, 'Formatting applied!');
    final after = controller.document.collectStyle(0, 1).attributes;
    expect(after.containsKey(Attribute.bold.key), isFalse);
  });

  test(
    'applyInstructions applies inline formatting to the current selection',
    () {
      final controller = _controllerFor(
        'Hello world',
        selection: const TextSelection(baseOffset: 0, extentOffset: 5),
      );

      final result = VoiceFormattingService.applyInstructions(
        instructions: [
          {
            'target': 'selection',
            'key': 'bold',
            'value': true,
            'occurrence': 'all',
          },
        ],
        controller: controller,
        commandText: 'make it bold',
      );

      expect(result, 'Formatting applied!');
      final style = controller.document.collectStyle(0, 1).attributes;
      expect(style.containsKey(Attribute.bold.key), isTrue);
    },
  );
}
