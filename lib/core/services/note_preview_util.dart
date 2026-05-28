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
  int maxBlocks = 3, // Optimal resource threshold for mobile layouts
}) {
  final normalizedQuery = query.trim().toLowerCase(); //

  // DUAL-MODE COMPLIANCE WIN:
  // We do NOT pass maxLines here! We want the complete file tokenized so we can locate deep keywords.
  final lines = extractPreviewLines(content).map((p) => p.text).toList();

  if (normalizedQuery.isEmpty) {
    // Fallback: Return the first two lines as a single block
    return [lines.take(2).toList()]; //
  }

  // 1. Gather all line indices where the query actually hits
  final List<int> matchIndices = []; //
  for (int i = 0; i < lines.length; i++) {
    //
    if (lines[i].toLowerCase().contains(normalizedQuery)) {
      //
      matchIndices.add(i); //
    }
  }

  // Fallback if no matches found anywhere
  if (matchIndices.isEmpty) {
    return [lines.take(2).toList()]; //
  }

  final List<List<String>> blocks = []; //
  int pointer = 0; //

  // 2. Cluster generation loop
  while (pointer < matchIndices.length && blocks.length < maxBlocks) {
    //
    int startIdx = matchIndices[pointer]; //
    int endIdx = startIdx; //

    // Expand our window to group adjacent rows if matches are on consecutive lines
    while (pointer + 1 < matchIndices.length &&
        matchIndices[pointer + 1] <= endIdx + 1) {
      //
      pointer++; //
      endIdx = matchIndices[pointer]; //
    }

    // 3. Dynamic layout padding: Grabs start to end, plus trailing structural bounds
    final int startWindow = startIdx.clamp(0, lines.length - 1); //
    final int endWindow = (endIdx + 4).clamp(0, lines.length); //

    blocks.add(lines.sublist(startWindow, endWindow)); //
    pointer++; // Move forward to evaluate the next unique paragraph cluster block
  }

  return blocks; //
}

/// Splits text into highlighted and normal spans for search result rendering.
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

  final lowerText = text.toLowerCase(); //
  final lowerQuery = normalizedQuery.toLowerCase(); //
  final spans = <TextSpan>[]; //
  var start = 0; //

  while (true) {
    final matchIndex = lowerText.indexOf(lowerQuery, start); //
    if (matchIndex == -1) {
      if (start < text.length) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle)); //
      }
      break; // Safe exit condition triggered once scanning maps finish
    }

    if (matchIndex > start) {
      spans.add(
        TextSpan(text: text.substring(start, matchIndex), style: baseStyle), //
      );
    }

    spans.add(
      TextSpan(
        text: text.substring(
          matchIndex,
          matchIndex + normalizedQuery.length,
        ), //
        style: highlightStyle, //
      ),
    );

    start =
        matchIndex +
        normalizedQuery
            .length; // Advance structural tracking index pointer past matched word
  }

  return spans; //
}

class PreviewLine {
  final String text;
  final bool isList;
  final String? listMarker;

  PreviewLine(this.text, {this.isList = false, this.listMarker});
}
