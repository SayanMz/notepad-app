import 'dart:convert';

import 'package:flutter/foundation.dart';

class DocumentDeltaLine {
  const DocumentDeltaLine({required this.runs, required this.blockAttributes});

  final List<DocumentInlineRun> runs;
  final Map<String, dynamic> blockAttributes;
}

class DocumentInlineRun {
  const DocumentInlineRun({required this.text, required this.attributes});

  final String text;
  final Map<String, dynamic> attributes;
}

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
          pushLine(blockAttributes(attributes));
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

Map<String, dynamic> blockAttributes(Map<String, dynamic> attributes) {
  const blockKeys = {'align', 'list', 'header', 'blockquote', 'code-block'};
  return Map<String, dynamic>.fromEntries(
    attributes.entries.where((entry) => blockKeys.contains(entry.key)),
  );
}

List<DocumentInlineRun> normalizeRunsForListLine(
  List<DocumentInlineRun> runs, {
  required bool isBullet,
  required bool isOrdered,
}) {
  if ((!isBullet && !isOrdered) || runs.isEmpty) return runs;
  final normalizedRuns = List<DocumentInlineRun>.from(runs);
  final firstRun = normalizedRuns.first;
  final strippedText = firstRun.text.replaceFirst(
    isOrdered ? RegExp(r'^\s*\d+[.)]\s+') : RegExp(r'^\s*([-*â€¢])\s+'),
    '',
  );
  if (strippedText == firstRun.text) return normalizedRuns;
  normalizedRuns[0] = DocumentInlineRun(
    text: strippedText,
    attributes: firstRun.attributes,
  );
  return normalizedRuns;
}

String safeFileTitle(String title) {
  final safe = title.trim().replaceAll(RegExp(r'[<>:"/\\|?*]'), '');
  return safe.isEmpty ? 'Note' : safe;
}

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
    debugPrint('JSON Error: $e');
  }
  return [
    {'insert': fallbackText},
    {'insert': '\n'},
  ];
}
