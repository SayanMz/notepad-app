import 'dart:convert';

import 'package:flutter/material.dart';

/// Converts note text into structured objects, identifying list markers during the parsing phase.
/// Optimized for the UI layer during scrolling.
List<PreviewLine> extractPreviewLines(String content, {int? maxLines}) {
  final trimmed = content.trim();
  if (trimmed.isEmpty) return [PreviewLine('No additional text')];

  final List<PreviewLine> extractedLines = maxLines != null
      ? List.from([], growable: true)
      : [];

  try {
    // 1. IS IT QUILL RICH TEXT DELTA JSON?
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
            // Return structured data instead of injecting string bullets
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
      // 2. PLAIN TEXT FALLBACK
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

/// Helper for plain text structural mapping
void _parsePlainTextLines(
  String rawText,
  List<PreviewLine> targetList,
  int? maxLines,
) {
  int start = 0;
  int nextNewline = rawText.indexOf('\n');

  // We use the existing Regex here ONLY for plain text parsing to maintain parity,
  // but we do it once during extraction, not repeatedly in the UI build method.
  final listPattern = RegExp(r'^\s*([-•·]|\d+\.)\s+(.*)');

  while (nextNewline != -1) {
    final String rawLine = rawText.substring(start, nextNewline).trim();
    if (rawLine.isNotEmpty) {
      final match = listPattern.firstMatch(rawLine);
      if (match != null) {
        targetList.add(
          PreviewLine((match.group(2) ?? '').trim(), isList: true),
        );
      } else {
        targetList.add(PreviewLine(rawLine));
      }

      if (maxLines != null && targetList.length >= maxLines) return;
    }
    start = nextNewline + 1;
    nextNewline = rawText.indexOf('\n', start);
  }

  if (start < rawText.length) {
    final String lastLine = rawText.substring(start).trim();
    if (lastLine.isNotEmpty) {
      final match = listPattern.firstMatch(lastLine);
      if (match != null) {
        targetList.add(
          PreviewLine((match.group(2) ?? '').trim(), isList: true),
        );
      } else {
        targetList.add(PreviewLine(lastLine));
      }
    }
  }
}

/// Finds multiple separate match blocks across a document.
/// Returns a list of blocks, where each block contains a slice of lines.
List<List<String>> extractMultiSearchSnippets(
  String content,
  String query, {
  int maxBlocks = 3, //
}) {
  final normalizedQuery = query.trim().toLowerCase(); //
  final lines = extractPreviewLines(content).map((p) => p.text).toList(); //

  if (normalizedQuery.isEmpty) {
    return [lines.take(2).toList()]; //
  }

  // Split query into tokens to find line matches for ANY keyword component
  final List<String> tokens = normalizedQuery
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();

  if (tokens.isEmpty) return [lines.take(2).toList()];

  // 1. Gather all unique line indices where ANY search token hits
  final List<int> matchIndices = []; //
  for (int i = 0; i < lines.length; i++) {
    //
    final lineLower = lines[i].toLowerCase();
    final bool isMatch = tokens.any((token) => lineLower.contains(token));
    if (isMatch) {
      matchIndices.add(i); //
    }
  }

  if (matchIndices.isEmpty) {
    return [lines.take(2).toList()]; //
  }

  final List<List<String>> blocks = []; //
  int pointer = 0; //

  // 🌟 Define configuration thresholds for dynamic block separation
  const int contextPadding = 2; // Lines of context to pull below a match block
  const int maxGapAllowed =
      3; // Max distance between matches before forcing a split

  // 2. Advanced Cluster Extraction Loop
  while (pointer < matchIndices.length && blocks.length < maxBlocks) {
    //
    int startIdx = matchIndices[pointer]; //
    int endIdx = startIdx; //

    // 🌟 THE FIX: Group matches together ONLY if they fall within our maximum gap buffer
    while (pointer + 1 < matchIndices.length &&
        matchIndices[pointer + 1] - endIdx <= maxGapAllowed) {
      pointer++; //
      endIdx = matchIndices[pointer]; //
    }

    // 3. Slice out the clean, non-overlapping snippet window configuration
    final int startWindow = startIdx.clamp(0, lines.length - 1); //
    final int endWindow = (endIdx + contextPadding + 1).clamp(
      0,
      lines.length,
    ); //

    blocks.add(lines.sublist(startWindow, endWindow)); //
    pointer++; //
  }

  return blocks; //
}

/// Splits text into multiple highlighted and normal spans by evaluating
/// queries as individual matching word tokens.
List<TextSpan> buildHighlightedTextSpans({
  required String text,
  required String query,
  required TextStyle baseStyle,
  required TextStyle highlightStyle,
}) {
  final normalizedQuery = query.trim(); //
  if (normalizedQuery.isEmpty) {
    return [TextSpan(text: text, style: baseStyle)]; //
  }

  // 🌟 STEP 1: Split the query string into separate words and filter out empty items.
  // This turns "AI Meeting" into ['ai', 'meeting'] so we match both tokens separately.
  final List<String> tokens = normalizedQuery
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList();

  if (tokens.isEmpty) {
    return [TextSpan(text: text, style: baseStyle)];
  }

  // 🌟 STEP 2: Escape words for safe regex consumption, then build an alternation pattern.
  // Resulting regex matches: (ai|meeting)
  final String pattern = tokens.map((t) => RegExp.escape(t)).join('|');
  final RegExp regex = RegExp(pattern, caseSensitive: false);

  final List<TextSpan> spans = [];
  int lastMatchEnd = 0;

  // 🌟 STEP 3: Iterate through all matching token locations found inside the text slice
  for (final Match match in regex.allMatches(text)) {
    // Append the unhighlighted text prefix leading up to this match hit
    if (match.start > lastMatchEnd) {
      spans.add(
        TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: baseStyle,
        ),
      );
    }

    // Append the highlighted text span for the matched word token
    spans.add(
      TextSpan(
        text: text.substring(match.start, match.end),
        style: highlightStyle,
      ),
    );

    lastMatchEnd = match.end;
  }

  // Append any trailing leftover text remaining after the final loop match
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
