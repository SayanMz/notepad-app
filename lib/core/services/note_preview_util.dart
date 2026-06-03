// Preview helpers extract short snippets from plain text and rich content.
import 'dart:convert';

import 'package:flutter/material.dart';

List<PreviewLine> extractPreviewLines(String content, {int? maxLines}) {
  final trimmed = content.trim();
  if (trimmed.isEmpty) return [PreviewLine('No additional text')];

  final List<PreviewLine> extractedLines = maxLines != null
      ? List.from([], growable: true)
      : [];

  try {
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      final List<dynamic> ops = jsonDecode(trimmed);
      final StringBuffer currentLineBuffer = StringBuffer();

      for (final op in ops) {
        if (op is! Map || op['insert'] is! String) continue;

        final String text = op['insert'];
        final Map<String, dynamic>? attrs =
            op['attributes'] is Map<String, dynamic>
            ? op['attributes'] as Map<String, dynamic>
            : null;

        if (text == '\n') {
          final String lineText = currentLineBuffer.toString().trim();
          currentLineBuffer.clear();

          if (attrs != null) {
            if (attrs['list'] == 'bullet') {
              extractedLines.add(
                PreviewLine(lineText, isList: true, listMarker: '•'),
              );
            } else if (attrs['list'] == 'ordered') {
              extractedLines.add(
                PreviewLine(lineText, isList: true, listMarker: '1.'),
              );
            } else {
              if (lineText.isNotEmpty) {
                extractedLines.add(PreviewLine(lineText));
              }
            }
          } else {
            if (lineText.isNotEmpty) extractedLines.add(PreviewLine(lineText));
          }

          if (maxLines != null && extractedLines.length >= maxLines) {
            return extractedLines;
          }
        } else if (text.contains('\n')) {
          int start = 0;
          int nextNewline = text.indexOf('\n');

          while (nextNewline != -1) {
            currentLineBuffer.write(text.substring(start, nextNewline));
            final String lineText = currentLineBuffer.toString().trim();
            currentLineBuffer.clear();

            if (lineText.isNotEmpty) {
              extractedLines.add(PreviewLine(lineText));
              if (maxLines != null && extractedLines.length >= maxLines) {
                return extractedLines;
              }
            }
            start = nextNewline + 1;
            nextNewline = text.indexOf('\n', start);
          }

          if (start < text.length) {
            currentLineBuffer.write(text.substring(start));
          }
        } else {
          currentLineBuffer.write(text);
        }
      }

      final String leftover = currentLineBuffer.toString().trim();
      if (leftover.isNotEmpty) {
        extractedLines.add(PreviewLine(leftover));
      }
    } else {
      _parsePlainTextLines(trimmed, extractedLines, maxLines);
    }
  } catch (e) {
    _parsePlainTextLines(content, extractedLines, maxLines);
  }

  return extractedLines
      .where((line) => line.text.isNotEmpty)
      .toList()
      .cast<PreviewLine>();
}

void _parsePlainTextLines(
  String rawText,
  List<PreviewLine> targetList,
  int? maxLines,
) {
  int start = 0;
  int nextNewline = rawText.indexOf('\n');
  final listPattern = RegExp(r'^\s*([-•·]|\d+\.)\s+(.*)');

  int regularTextCount = 0;
  int checklistCount = 0;

  final int maxChecklistsToFind = maxLines ?? 6;

  while (nextNewline != -1) {
    final String rawLine = rawText.substring(start, nextNewline).trim();

    if (rawLine.isNotEmpty) {
      final match = listPattern.firstMatch(rawLine);

      if (match != null) {
        if (checklistCount < maxChecklistsToFind) {
          targetList.add(
            PreviewLine(
              (match.group(2) ?? '').trim(),
              isList: true,
              listMarker: match.group(1),
            ),
          );
          checklistCount++;
        }
      } else {
        if (maxLines == null || regularTextCount < maxLines) {
          targetList.add(PreviewLine(rawLine));
          regularTextCount++;
        }
      }

      if (maxLines != null &&
          regularTextCount >= maxLines &&
          (checklistCount >= maxChecklistsToFind ||
              !rawText.contains('-', start))) {
        return;
      }
    }

    start = nextNewline + 1;
    nextNewline = rawText.indexOf('\n', start);
  }

  if (start < rawText.length) {
    final String lastLine = rawText.substring(start).trim();
    if (lastLine.isNotEmpty) {
      final match = listPattern.firstMatch(lastLine);
      if (match != null) {
        if (checklistCount < maxChecklistsToFind) {
          targetList.add(
            PreviewLine(
              (match.group(2) ?? '').trim(),
              isList: true,
              listMarker: match.group(1),
            ),
          );
        }
      } else {
        if (maxLines == null || regularTextCount < maxLines) {
          targetList.add(PreviewLine(lastLine));
        }
      }
    }
  }
}

List<List<String>> extractMultiSearchSnippets(
  String content,
  String query, {
  int maxBlocks = 3,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final lines = extractPreviewLines(content).map((p) => p.text).toList();

  if (normalizedQuery.isEmpty) {
    return [lines.take(2).toList()];
  }

  final List<String> tokens = normalizedQuery
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();

  if (tokens.isEmpty) return [lines.take(2).toList()];

  final List<int> matchIndices = [];
  for (int i = 0; i < lines.length; i++) {
    final lineLower = lines[i].toLowerCase();
    final bool isMatch = tokens.any((token) => lineLower.contains(token));
    if (isMatch) {
      matchIndices.add(i);
    }
  }

  if (matchIndices.isEmpty) {
    return [lines.take(2).toList()];
  }

  final List<List<String>> blocks = [];
  int pointer = 0;

  const int contextPadding = 2;
  const int maxGapAllowed = 3;

  while (pointer < matchIndices.length && blocks.length < maxBlocks) {
    int startIdx = matchIndices[pointer];
    int endIdx = startIdx;

    while (pointer + 1 < matchIndices.length &&
        matchIndices[pointer + 1] - endIdx <= maxGapAllowed) {
      pointer++;
      endIdx = matchIndices[pointer];
    }

    final int startWindow = startIdx.clamp(0, lines.length - 1);
    final int endWindow = (endIdx + contextPadding + 1).clamp(0, lines.length);

    blocks.add(lines.sublist(startWindow, endWindow));
    pointer++;
  }

  return blocks;
}

List<TextSpan> buildHighlightedTextSpans({
  required String text,
  required String query,
  required TextStyle baseStyle,
  required TextStyle highlightStyle,
}) {
  final normalizedQuery = query.trim();
  if (normalizedQuery.isEmpty) {
    return [TextSpan(text: text, style: baseStyle)];
  }

  final List<String> tokens = normalizedQuery
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList();

  if (tokens.isEmpty) {
    return [TextSpan(text: text, style: baseStyle)];
  }

  final String pattern = tokens.map((t) => RegExp.escape(t)).join('|');
  final RegExp regex = RegExp(pattern, caseSensitive: false);

  final List<TextSpan> spans = [];
  int lastMatchEnd = 0;

  for (final Match match in regex.allMatches(text)) {
    if (match.start > lastMatchEnd) {
      spans.add(
        TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: baseStyle,
        ),
      );
    }

    spans.add(
      TextSpan(
        text: text.substring(match.start, match.end),
        style: highlightStyle,
      ),
    );

    lastMatchEnd = match.end;
  }

  if (lastMatchEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastMatchEnd), style: baseStyle));
  }

  return spans;
}

class PreviewLine {
  final String text;
  final bool isList;
  final String? listMarker;

  PreviewLine(this.text, {this.isList = false, this.listMarker});
}

