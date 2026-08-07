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
  List<List<String>>? _memoizedBlocks;
  List<TextSpan>? _memoizedTitleSpans;
  List<List<List<TextSpan>>>? _memoizedBlockSpans;
  String? _lastContent;
  String? _lastQuery;
  bool? _lastIsDark;

  @override
  void initState() {
    super.initState();
    _cardScrollController = ScrollController();
  }

  @override
  void didUpdateWidget(SearchResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.note.content != oldWidget.note.content ||
        widget.query != oldWidget.query) {
      _memoizedBlocks = null;
      _memoizedBlockSpans = null;
    }
  }

  void _ensureBlocks() {
    if (_memoizedBlocks != null &&
        _lastContent == widget.note.content &&
        _lastQuery == widget.query) {
      return;
    }
    _memoizedBlocks = extractMultiSearchSnippets(
      widget.note.content,
      widget.query,
    );
    _lastContent = widget.note.content;
    _lastQuery = widget.query;
    _memoizedBlockSpans = null; // Invalidate spans if blocks changed
  }

  void _ensureSpans(TextStyle titleBase, TextStyle previewBase,
      TextStyle highlight, bool isDark) {
    if (_memoizedTitleSpans != null &&
        _memoizedBlockSpans != null &&
        _lastQuery == widget.query &&
        _lastIsDark == isDark) {
      return;
    }

    _memoizedTitleSpans = buildHighlightedTextSpans(
      text: widget.note.displayTitle,
      query: widget.query,
      baseStyle: titleBase,
      highlightStyle: titleBase.merge(highlight),
    );

    if (_memoizedBlocks != null) {
      _memoizedBlockSpans = _memoizedBlocks!.map((block) {
        return block.map((line) {
          return buildHighlightedTextSpans(
            text: line,
            query: widget.query,
            baseStyle: previewBase,
            highlightStyle: previewBase.merge(highlight),
          );
        }).toList();
      }).toList();
    }

    _lastIsDark = isDark;
    _lastQuery = widget.query;
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

    _ensureBlocks();
    _ensureSpans(titleStyle, previewStyle, highlightStyle, isDark);

    final List<List<List<TextSpan>>> blockSpans = _memoizedBlockSpans ?? [];

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
              TextSpan(children: _memoizedTitleSpans),
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

