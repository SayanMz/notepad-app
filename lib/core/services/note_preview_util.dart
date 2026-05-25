import 'dart:convert'; // REQUIRED for parsing Quill Delta correctly

import 'package:flutter/material.dart'; // REQUIRED for TextSpan definitions

/// Converts note text into short preview lines for list cards and search.
/// High-performance version optimized for zero redundant string allocations using a single-pass stream buffer.
List<String> extractPreviewLines(String content, {int? maxLines}) {
  final trimmed = content.trim(); //
  if (trimmed.isEmpty) return const ['No additional text']; //

  // Pre-allocate initial list array slots to minimize memory allocations resizing overhead
  final List<String> extractedLines = maxLines != null
      ? List.from([], growable: true)
      : [];

  try {
    // 1. IS IT QUILL RICH TEXT DELTA JSON?
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      //
      final List<dynamic> ops = jsonDecode(trimmed); //

      // Using a StringBuffer is significantly more memory-efficient than standard string concatenation
      final StringBuffer currentLineBuffer = StringBuffer();

      for (final op in ops) {
        // Robustness Guard: Ignore corrupted or malformed operation payload maps safely
        if (op is! Map || op['insert'] is! String) continue;

        final String text = op['insert']; //
        final Map<String, dynamic>? attrs =
            op['attributes'] is Map<String, dynamic>
            ? op['attributes'] as Map<String, dynamic>
            : null; //

        // CASE A: Quill newline structural attribute tracker
        if (text == '\n') {
          final String lineText = currentLineBuffer.toString().trim();
          currentLineBuffer
              .clear(); // Flush buffer contents instantly without discarding instance slot

          if (attrs != null) {
            if (attrs['list'] == 'bullet') {
              extractedLines.add('• $lineText'); //
            } else if (attrs['list'] == 'ordered') {
              extractedLines.add('1. $lineText'); //
            } else {
              if (lineText.isNotEmpty) extractedLines.add(lineText); //
            }
          } else {
            if (lineText.isNotEmpty) extractedLines.add(lineText); //
          }

          // ⚡ THE LAZY OPTIMIZATION SCRIPT:
          // Early exit the loop pass instantly if our required caching window quota is filled!
          if (maxLines != null && extractedLines.length >= maxLines) {
            return extractedLines;
          }
        }
        // CASE B: Inline line breaks (e.g., block copy-pastes)
        else if (text.contains('\n')) {
          int start = 0;
          int nextNewline = text.indexOf('\n');

          // High-speed index slicing loop pass (completely avoids expensive string split arrays)
          while (nextNewline != -1) {
            currentLineBuffer.write(text.substring(start, nextNewline));
            final String lineText = currentLineBuffer.toString().trim();
            currentLineBuffer.clear();

            if (lineText.isNotEmpty) {
              extractedLines.add(lineText);
              if (maxLines != null && extractedLines.length >= maxLines) {
                return extractedLines;
              }
            }
            start = nextNewline + 1;
            nextNewline = text.indexOf('\n', start);
          }

          // Append any remaining text block characters trailing after the final newline marker
          if (start < text.length) {
            currentLineBuffer.write(text.substring(start));
          }
        }
        // CASE C: Standard inline alphanumeric element fragment
        else {
          currentLineBuffer.write(text); //
        }
      }

      // Capture any uncommitted text segments remaining inside the active buffer sequence
      final String leftover = currentLineBuffer.toString().trim();
      if (leftover.isNotEmpty) {
        extractedLines.add(leftover); //
      }
    } else {
      // 2. PLAIN TEXT FALLBACK LOGIC: Parse cleanly using native memory index boundaries
      _parsePlainTextLines(trimmed, extractedLines, maxLines);
    }
  } catch (e) {
    // Fail-safe protection pass to guarantee zero crashing behaviors
    _parsePlainTextLines(content, extractedLines, maxLines);
  }

  // Clean up and filter out empty string nodes safely
  return extractedLines.where((line) => line.isNotEmpty).toList(); //
}

/// Private helper optimization method to compile raw plain text without utilizing `.split()` blocks
void _parsePlainTextLines(
  String rawText,
  List<String> targetList,
  int? maxLines,
) {
  int start = 0;
  int nextNewline = rawText.indexOf('\n');

  while (nextNewline != -1) {
    final String line = rawText.substring(start, nextNewline).trim();
    if (line.isNotEmpty) {
      targetList.add(line);
      if (maxLines != null && targetList.length >= maxLines) return;
    }
    start = nextNewline + 1;
    // ⚡ FIXED: Correctly updating variables tracking to prevent layout RangeErrors loops!
    nextNewline = rawText.indexOf('\n', start);
  }

  if (start < rawText.length) {
    final String lastLine = rawText.substring(start).trim();
    if (lastLine.isNotEmpty) targetList.add(lastLine);
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
  final lines = extractPreviewLines(content); //

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

/// Detects whether a preview line still includes a list marker.
bool isListStyledPreviewLine(String line) {
  return RegExp(r'^\s*([-•·]|\d+\.)\s+').hasMatch(line); //
}

/// Removes list markers (bullets, numbers) from the start of a line for clean previews.
String stripListMarker(String line) {
  // We use a capture group for the marker and a separate one for the trailing text payload
  final pattern = RegExp(r'^\s*([-•·]|\d+\.)\s+(.*)');
  final match = pattern.firstMatch(line);

  if (match != null) {
    // Group 2 returns the pure content body text payload
    return (match.group(2) ?? '').trim();
  }
  return line.trim();
}
