import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/services/voice_ai/voice_formatting_target_resolver.dart';

QuillController _controllerFor(String text, {TextSelection? selection}) {
  return QuillController(
    document: Document()..insert(0, text),
    selection: selection ?? const TextSelection.collapsed(offset: 0),
    keepStyleOnNewLine: false,
  );
}

void main() {
  test('resolve returns the current selection for selection-based commands', () {
    final controller = _controllerFor(
      'Hello world',
      selection: const TextSelection(baseOffset: 0, extentOffset: 5),
    );

    final resolution = VoiceFormattingTargetResolver.resolve(
      controller: controller,
      plainText: 'Hello world',
      target: 'selection',
      occurrence: 'all',
      commandText: 'make it bold',
      key: 'bold',
    );

    expect(resolution.isSelectionTarget, isTrue);
    expect(resolution.hasSelection, isTrue);
    expect(resolution.ranges, [
      {'start': 0, 'len': 5},
    ]);
  });

  test('resolve expands positional line targets correctly', () {
    final controller = _controllerFor('First line\nSecond line\nThird line');

    final resolution = VoiceFormattingTargetResolver.resolve(
      controller: controller,
      plainText: 'First line\nSecond line\nThird line',
      target: 'line:second',
      occurrence: 'all',
      commandText: 'center the second line',
      key: 'align',
    );

    expect(resolution.ranges, [
      {'start': 11, 'len': 12},
    ]);
  });

  test('resolve supports global commands and literal occurrence filtering', () {
    final controller = _controllerFor('alpha beta alpha beta');

    final global = VoiceFormattingTargetResolver.resolve(
      controller: controller,
      plainText: 'alpha beta alpha beta',
      target: 'everything',
      occurrence: 'all',
      commandText: 'format everything',
      key: 'bold',
    );

    expect(global.isGlobal, isTrue);
    expect(global.ranges, [
      {'start': 0, 'len': 21},
    ]);

    final literal = VoiceFormattingTargetResolver.resolve(
      controller: controller,
      plainText: 'alpha beta alpha beta',
      target: 'alpha beta',
      occurrence: 'second',
      commandText: 'make the second alpha beta bold',
      key: 'bold',
    );

    expect(literal.ranges, [
      {'start': 11, 'len': 10},
    ]);
  });

  test('resolve marks empty positional lines as skipped for inline styles', () {
    final controller = _controllerFor('Hello\n');

    final resolution = VoiceFormattingTargetResolver.resolve(
      controller: controller,
      plainText: 'Hello\n',
      target: 'line:second',
      occurrence: 'all',
      commandText: 'make the empty line bold',
      key: 'bold',
    );

    expect(resolution.ranges, isEmpty);
    expect(resolution.skippedInlineOnEmpty, isTrue);
  });
}
