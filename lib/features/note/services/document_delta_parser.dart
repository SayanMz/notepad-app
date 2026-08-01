// Converts Quill deltas into plain-text and rich-content structures.
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// A single logical line in a document parsed from Quill Delta operations.
class DocumentDeltaLine {
  const DocumentDeltaLine({required this.runs, required this.blockAttributes});

  /// Inline styled text segments or embeds in this line.
  final List<DocumentInlineRun> runs;

  /// Line-level formatting attributes (e.g., `header`, `align`, `list`).
  final Map<String, dynamic> blockAttributes;
}

/// A contiguous segment of inline text or content sharing the same attributes.
class DocumentInlineRun {
  const DocumentInlineRun({required this.text, required this.attributes});

  /// Raw text or placeholder representation (e.g., `'[Image]'`).
  final String text;

  /// Character-level formatting attributes (e.g., `bold`, `italic`).
  final Map<String, dynamic> attributes;
}

/// Parses a raw Quill Delta JSON array into a list of [DocumentDeltaLine] objects.
///
/// Splits text on newlines (`\n`), extracts line-level block attributes, and
/// handles embedded content like images.
List<DocumentDeltaLine> parseDocumentDelta(List<dynamic> delta) {
  final lines = <DocumentDeltaLine>[];
  final runs = <DocumentInlineRun>[];

  void pushLine([Map<String, dynamic>? blockAttributes]) {
    lines.add(
      DocumentDeltaLine(
        runs: List<DocumentInlineRun>.from(runs),
        blockAttributes: Map<String, dynamic>.from(blockAttributes ?? const {}),
      ),
    );
    runs.clear();
  }

  for (final rawOperation in delta) {
    if (rawOperation is! Map) continue;

    final insert = rawOperation['insert'];
    final attributes = Map<String, dynamic>.from(
      rawOperation['attributes'] as Map? ?? const {},
    );

    if (insert is String) {
      final parts = insert.split('\n');
      for (var index = 0; index < parts.length; index++) {
        final part = parts[index];
        if (part.isNotEmpty) {
          runs.add(DocumentInlineRun(text: part, attributes: attributes));
        }
        if (index < parts.length - 1) {
          pushLine(extractBlockAttributes(attributes));
        }
      }
    } else if (insert is Map) {
      runs.add(
        DocumentInlineRun(
          text: insert.keys.first == 'image' ? '[Image]' : '[Embedded content]',
          attributes: attributes,
        ),
      );
    }
  }

  if (runs.isNotEmpty || lines.isEmpty) pushLine();
  return lines;
}

/// Filters attributes to retain only line/block-level formatting.
Map<String, dynamic> extractBlockAttributes(Map<String, dynamic> attributes) {
  const blockKeys = {'align', 'list', 'header', 'blockquote', 'code-block'};
  return Map<String, dynamic>.fromEntries(
    attributes.entries.where((entry) => blockKeys.contains(entry.key)),
  );
}

/// Strips manual list markers (e.g., `1.`, `-`, `•`) from the first run of a list item
/// to prevent double-rendering.
List<DocumentInlineRun> normalizeRunsForListLine(
  List<DocumentInlineRun> runs, {
  required bool isBullet,
  required bool isOrdered,
}) {
  if ((!isBullet && !isOrdered) || runs.isEmpty) return runs;

  final normalizedRuns = List<DocumentInlineRun>.from(runs);
  final firstRun = normalizedRuns.first;

  final strippedText = firstRun.text.replaceFirst(
    isOrdered ? RegExp(r'^\s*\d+[.)]\s+') : RegExp(r'^\s*([-*•])\s+'),
    '',
  );

  if (strippedText == firstRun.text) return normalizedRuns;

  normalizedRuns[0] = DocumentInlineRun(
    text: strippedText,
    attributes: firstRun.attributes,
  );
  return normalizedRuns;
}

/// Sanitizes a string into a safe file system name, defaulting to `'Note'`.
String safeFileTitle(String title) {
  final safe = title.trim().replaceAll(RegExp(r'[<>:"/\\|?*]'), '');
  return safe.isEmpty ? 'Note' : safe;
}

/// Safely decodes a serialized Quill Delta JSON string into a Delta array.
/// Falls back to plain [fallbackText] on error or empty string.
List<dynamic> decodeRichContent(String richContent, String fallbackText) {
  if (richContent.trim().isEmpty) {
    return [
      {'insert': fallbackText},
      {'insert': '\n'},
    ];
  }

  try {
    final decoded = jsonDecode(richContent);
    if (decoded is List) return decoded;
  } catch (e) {
    debugPrint('JSON Error decoding rich content: $e');
  }

  return [
    {'insert': fallbackText},
    {'insert': '\n'},
  ];
}
