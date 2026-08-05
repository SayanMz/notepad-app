import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/services/note_preview_util.dart';

void main() {
  group('NotePreviewUtil Advanced Parsing', () {
    test('extractPreviewLines handles malformed rich text JSON gracefully', () {
      const malformedJson = '[{"insert": "Broken JSON"'; // Missing closing brace
      final result = extractPreviewLines(malformedJson);
      
      // Should fallback to plain text parsing
      expect(result.first.text, contains('Broken JSON'));
    });

    test('extractPreviewLines handles empty operation lists', () {
      const emptyOps = '[]';
      final result = extractPreviewLines(emptyOps);
      
      expect(result, isEmpty);
    });

    test('extractMultiSearchSnippets handles multi-word query gaps', () {
      const content = 'First line\nSecond line\nTarget word\nFourth line\nFifth line\nAnother match';
      // Query words are far apart
      final blocks = extractMultiSearchSnippets(content, 'First Another');
      
      expect(blocks.length, greaterThan(1));
      expect(blocks[0], contains('First line'));
      expect(blocks[blocks.length - 1], contains('Another match'));
    });

    test('buildHighlightedTextSpans is case-insensitive', () {
      final spans = buildHighlightedTextSpans(
        text: 'Hello FLUTTER World',
        query: 'flutter',
        baseStyle: const TextStyle(),
        highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      );

      // Should find 1 match (FLUTTER)
      final matches = spans.where((s) => s.style?.fontWeight == FontWeight.bold);
      expect(matches.length, 1);
      expect(matches.first.text, 'FLUTTER');
    });
  });
}
