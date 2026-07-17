import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/services/note_preview_util.dart';

void main() {
  test('extractPreviewLines keeps plain text lines intact', () {
    final lines = extractPreviewLines('First line\nSecond line\nThird line');

    expect(lines.map((line) => line.text), [
      'First line',
      'Second line',
      'Third line',
    ]);
  });

  test('extractPreviewLines recognizes simple list markers', () {
    final lines = extractPreviewLines('- Bullet one\n2. Number two');

    expect(lines, hasLength(2));
    expect(lines.first.isList, isTrue);
    expect(lines.first.text, 'Bullet one');
    expect(lines.last.listMarker, '2.');
  });

  test('extractMultiSearchSnippets returns the matching context block', () {
    final blocks = extractMultiSearchSnippets(
      'Alpha\nBeta\nGamma\nDelta',
      'beta',
    );

    expect(blocks, isNotEmpty);
    expect(blocks.first.join('\n'), contains('Beta'));
  });

  test('buildHighlightedTextSpans highlights matching tokens', () {
    const baseStyle = TextStyle(fontSize: 14);
    const highlightStyle = TextStyle(backgroundColor: Colors.yellow);

    final spans = buildHighlightedTextSpans(
      text: 'Alpha beta gamma',
      query: 'beta',
      baseStyle: baseStyle,
      highlightStyle: highlightStyle,
    );

    expect(spans.map((span) => span.text).toList(), [
      'Alpha ',
      'beta',
      ' gamma',
    ]);
    expect(spans[1].style?.backgroundColor, Colors.yellow);
  });
}
