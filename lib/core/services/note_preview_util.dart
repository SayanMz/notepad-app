import 'package:flutter/material.dart';
import 'dart:convert'; // REQUIRED for parsing Quill Delta correctly

/// Converts note text into short preview lines for list cards and search.
List<String> extractPreviewLines(String content, {int? maxLines}) {
  if (content.trim().isEmpty) return const ['No additional text'];

  List<String> extractedLines = [];

  try {
    // 1. IS IT QUILL RICH TEXT?
    if (content.trim().startsWith('[') && content.trim().endsWith(']')) {
      // Decode the raw JSON safely
      final List<dynamic> ops = jsonDecode(content);
      String currentLine = '';

      // 2. PARSE THE DELTA LIKE A COMPILER
      for (var op in ops) {
        if (op['insert'] is String) {
          String text = op['insert'];
          Map<String, dynamic>? attrs = op['attributes'];

          // A: Quill marks bullets by attaching an attribute to the newline
          if (text == '\n' && attrs != null) {
            if (attrs['list'] == 'bullet') {
              extractedLines.add(
                '• ${currentLine.trim()}',
              ); // Force the bullet marker
            } else if (attrs['list'] == 'ordered') {
              extractedLines.add(
                '1. ${currentLine.trim()}',
              ); // Force the number marker
            } else {
              extractedLines.add(currentLine.trim());
            }
            currentLine = ''; // Reset for the next line
          }
          // B: Regular text blocks that might contain normal newlines
          else if (text.contains('\n')) {
            final parts = text.split('\n');
            for (int i = 0; i < parts.length - 1; i++) {
              currentLine += parts[i];
              extractedLines.add(currentLine.trim());
              currentLine = '';
            }
            currentLine += parts.last;
          }
          // C: Standard inline text fragment
          else {
            currentLine += text;
          }
        }
      }

      // Catch any leftover text
      if (currentLine.trim().isNotEmpty) {
        extractedLines.add(currentLine.trim());
      }
    } else {
      // Not JSON, just standard plain text typed by the user
      extractedLines = content.split('\n');
    }
  } catch (e) {
    // If absolutely anything goes wrong, safely fallback so the app doesn't crash
    extractedLines = content.split('\n');
  }

  // 3. FINAL CLEANUP & LIMITING
  return maxLines != null
      ? extractedLines.where((line) => line.isNotEmpty).take(maxLines).toList()
      : extractedLines.where((line) => line.isNotEmpty).toList();
}

/// Returns search snippets centered around the matched query when possible.
List<String> extractSearchSnippets(
  String content,
  String query, {
  int maxLines = 2,
}) {
  final normalizedQuery = query.trim().toLowerCase();

  // Use our new robust parser to get the clean lines first
  final lines = extractPreviewLines(content);

  if (normalizedQuery.isEmpty) {
    return lines.take(maxLines).toList();
  }

  final matchingIndex = lines.indexWhere(
    (line) => line.toLowerCase().contains(normalizedQuery),
  );

  if (matchingIndex == -1) {
    return lines.take(maxLines).toList();
  }

  final start = matchingIndex.clamp(0, lines.length - 1);
  final end = (matchingIndex + maxLines).clamp(0, lines.length);
  return lines.sublist(start, end);
}

/// Splits text into highlighted and normal spans for search result rendering.
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

  final lowerText = text.toLowerCase();
  final lowerQuery = normalizedQuery.toLowerCase();
  final spans = <TextSpan>[];
  var start = 0;

  while (true) {
    final matchIndex = lowerText.indexOf(lowerQuery, start);
    if (matchIndex == -1) {
      if (start < text.length) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
      }
      break;
    }

    if (matchIndex > start) {
      spans.add(
        TextSpan(text: text.substring(start, matchIndex), style: baseStyle),
      );
    }

    spans.add(
      TextSpan(
        text: text.substring(matchIndex, matchIndex + normalizedQuery.length),
        style: highlightStyle,
      ),
    );

    start = matchIndex + normalizedQuery.length;
  }

  return spans;
}

/// Detects whether a preview line still includes a list marker.
bool isListStyledPreviewLine(String line) {
  return RegExp(r'^\s*([-•·]|\d+\.)\s+').hasMatch(line);
}

/// Removes list markers (bullets, numbers) from the start of a line for clean previews.
String stripListMarker(String line) {
  return line.replaceFirst(RegExp(r'^\s*([-•·]|\d+\.)\s+'), '');
}

/*
To highlight text, the system applies a style attribute to a specific range in the Delta. When Flutter renders it, it maps that Delta segment to a TextSpan with a background color."
*/
