import 'package:flutter/material.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/core/services/note_preview_util.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/core/extensions/note_timestamp_formatter.dart';
import 'package:notepad/features/search/search_constants.dart';

// Search result card highlights matches, snippets, and note metadata in one tile.
class SearchResultCard extends StatefulWidget {
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
  State<SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<SearchResultCard> {
  late final ScrollController _cardScrollController;

  @override
  void initState() {
    super.initState();
    _cardScrollController = ScrollController();
  }

  @override
  void dispose() {
    _cardScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: SearchConstants.resultTitleFontSize,
      color: context.isDark ? AppColors.searchResultTitleDark : AppColors.searchResultTitleLight,
    );
    final previewStyle = TextStyle(
      color: context.isDark ? AppColors.searchResultSubtitleDark : AppColors.searchResultSubtitleLight,
      height: 1.35,
      fontSize: 13,
    );

    final highlightStyle = TextStyle(
      backgroundColor: AppColors.searchResultHighlight,
      fontWeight: FontWeight.w700,
      color: AppColors.searchResultTitleLight,
    );

    final List<List<String>> blocks = extractMultiSearchSnippets(
      widget.note.content,
      widget.query,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: SearchConstants.resultMarginBottom),
      clipBehavior: Clip.hardEdge,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SearchConstants.resultContentPaddingH,
          vertical: SearchConstants.resultContentPaddingV,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: buildHighlightedTextSpans(
                  text: widget.note.displayTitle,
                  query: widget.query,
                  baseStyle: titleStyle,
                  highlightStyle: titleStyle.merge(highlightStyle),
                ),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: SearchConstants.chipGap),
            Text(
              'Edited: ${widget.note.updatedAt.format()}',
              style: TextStyle(
                color: context.isDark ? AppColors.searchResultSubtitleDark : AppColors.searchResultSubtitleLight,
                fontSize: SearchConstants.resultEditedFontSize,
              ),
            ),
            const SizedBox(height: SearchConstants.chipGap),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(
            top: SearchConstants.resultSubtitleTopPadding,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 0, maxHeight: 115.0),
            child: SingleChildScrollView(
              physics: ClampingScrollPhysics(),
              controller: _cardScrollController,
              primary: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...blocks.asMap().entries.map((blockEntry) {
                    final blockIndex = blockEntry.key;
                    final blockLines = blockEntry.value;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (blockIndex > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              children: [
                                const SizedBox(width: 4),
                                Text(
                                  '•  •  •',
                                  style: TextStyle(
                                    color: AppColors.searchResultSubtitleDark,
                                    fontSize: 9,
                                    letterSpacing: 4,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        ...blockLines.map((line) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 3.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      children: buildHighlightedTextSpans(
                                        text: line,
                                        query: widget.query,
                                        baseStyle: previewStyle,
                                        highlightStyle: previewStyle.merge(
                                          highlightStyle,
                                        ),
                                      ),
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
        onTap: widget.onTap,
      ),
    );
  }
}

