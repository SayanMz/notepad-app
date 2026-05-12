import 'package:flutter/material.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/services/note_preview_util.dart';
import 'package:notepad/core/services/note_timestamp_formatter.dart';

/// Displays a single search result (note) with highlighted matches.
class SearchResultCard extends StatelessWidget {
  const SearchResultCard({
    required this.note,
    required this.query,
    required this.onTap,
    super.key,
  });

  final NotesSection note;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final titleStyle = const TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 16,
    );
    final previewStyle = TextStyle(color: Colors.grey[700], height: 1.25);

    const highlightStyle = TextStyle(
      backgroundColor: Color(0xFFFFF176),
      fontWeight: FontWeight.w600,
      color: Colors.black,
    );

    final previewLines = extractSearchSnippets(note.content, query);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.hardEdge,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: buildHighlightedTextSpans(
                  text: note.title.isEmpty ? 'Untitled note' : note.title,
                  query: query,
                  baseStyle: titleStyle,
                  highlightStyle: titleStyle.merge(highlightStyle),
                ),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: UIConstants.paddingXS),
            Text(
              'Edited: ${note.updatedAt.format()}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: UIConstants.noteCardEditedFontSize,
              ),
            ),
            const SizedBox(height: UIConstants.paddingSM),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: previewLines.map((line) {
              final isListLine = isListStyledPreviewLine(line);
              final previewText = isListLine ? stripListMarker(line) : line;

              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: buildHighlightedTextSpans(
                            text: previewText,
                            query: query,
                            baseStyle: previewStyle,
                            highlightStyle: previewStyle.merge(highlightStyle),
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Empty-state card shown when no notes match the search.
class SearchMessage extends StatelessWidget {
  const SearchMessage({
    required this.title,
    required this.subtitle,
    required this.icon,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.grey[500]),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
