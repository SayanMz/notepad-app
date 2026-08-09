import 'package:flutter/material.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/core/services/note_preview_util.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/core/extensions/note_timestamp_formatter.dart';
import 'package:notepad/features/search/search_constants.dart';

// Search result card highlights matches, snippets, and note metadata in one tile.
class ResultCard extends StatefulWidget {
  const ResultCard({
    required this.note,
    required this.query,
    required this.onTap,

    super.key,
  });

  final NotesSection note;
  final String query;
  final VoidCallback onTap;

  @override
  State<ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<ResultCard> {
  late final ScrollController _cardScrollController;

  // Single cached result set
  List<TextSpan>? _titleSpans;
  List<List<List<TextSpan>>>? _blockSpans;

  // Single set of cache keys
  String? _cachedContent;
  String? _cachedQuery;

  @override
  void initState() {
    super.initState();
    _cardScrollController = ScrollController();
  }

  void _ensureCache({
    required TextStyle titleBase,
    required TextStyle previewBase,
    required TextStyle highlight,
  }) {
    // Return early if nothing that affects rendering has changed
    final isCacheValid =
        _titleSpans != null &&
        _blockSpans != null &&
        _cachedContent == widget.note.content &&
        _cachedQuery == widget.query;

    if (isCacheValid) return;

    // 1. Extract raw blocks
    final blocks = extractMultiSearchSnippets(
      widget.note.content,
      widget.query,
    );

    // 2. Build title spans
    _titleSpans = buildHighlightedTextSpans(
      text: widget.note.displayTitle,
      query: widget.query,
      baseStyle: titleBase,
      highlightStyle: titleBase.merge(highlight),
    );

    // 3. Build body snippet spans
    _blockSpans = blocks.map((block) {
      return block.map((line) {
        return buildHighlightedTextSpans(
          text: line,
          query: widget.query,
          baseStyle: previewBase,
          highlightStyle: previewBase.merge(highlight),
        );
      }).toList();
    }).toList();

    // 4. Update cached keys
    _cachedContent = widget.note.content;
    _cachedQuery = widget.query;
  }

  @override
  void dispose() {
    _cardScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.isDark;

    final titleStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: SearchConstants.resultTitleFontSize,
      color: isDark
          ? AppColors.searchResultTitleDark
          : AppColors.searchResultTitleLight,
    );

    final previewStyle = TextStyle(
      color: isDark
          ? AppColors.searchResultSubtitleDark
          : AppColors.searchResultSubtitleLight,
      height: 1.35,
      fontSize: 13,
    );

    final highlightStyle = TextStyle(
      backgroundColor: AppColors.searchResultHighlight,
      fontWeight: FontWeight.w700,
      color: AppColors.searchResultTitleLight,
    );

    _ensureCache(
      titleBase: titleStyle,
      previewBase: previewStyle,
      highlight: highlightStyle,
    );

    final List<List<List<TextSpan>>> blockSpans = _blockSpans ?? [];

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
              TextSpan(children: _titleSpans),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: SearchConstants.chipGap),
            Text(
              'Edited: ${widget.note.updatedAt.format()}',
              style: TextStyle(
                color: isDark
                    ? AppColors.searchResultSubtitleDark
                    : AppColors.searchResultSubtitleLight,
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
              physics: const ClampingScrollPhysics(),
              controller: _cardScrollController,
              primary: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...blockSpans.asMap().entries.map((blockEntry) {
                    final blockIndex = blockEntry.key;
                    final lineSpansList = blockEntry.value;

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
                        ...lineSpansList.map((lineSpans) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 3.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(children: lineSpans),
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
