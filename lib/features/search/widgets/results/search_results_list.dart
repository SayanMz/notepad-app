import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/services/ui_management/app_router.dart';
import 'package:notepad/features/note/note_page.dart';
import 'package:notepad/features/search/controllers/search_controller.dart'
    as search_ctrl;
import 'package:notepad/features/search/search_constants.dart';
import 'package:notepad/features/search/widgets/results/search_empty_states.dart';
import 'package:notepad/features/search/widgets/results/search_result_card.dart';
import 'package:notepad/features/search/widgets/search_drag_handle.dart';

// Search results list switches between empty, initial, and result states.
class SearchResultsList extends StatefulWidget {
  const SearchResultsList({
    super.key,
    required this.controller,
    required this.scrollController,
  });

  final search_ctrl.SearchController controller;
  final ScrollController scrollController;

  @override
  State<SearchResultsList> createState() => SearchResultsListState();
}

class SearchResultsListState extends State<SearchResultsList> {
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AnimationConstants.fast,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _buildCurrentContent(),
    );
  }

  Widget _buildCurrentContent() {
    final results = widget.controller.results;
    final query = widget.controller.query;
    final hasCriteria = widget.controller.hasAnyCriteria;

    if (!hasCriteria) {
      return SearchInitialState(key: const ValueKey('initial'));
    }
    if (results.isEmpty) {
      return SearchEmptyState(key: const ValueKey('empty'), query: query);
    }

    return Stack(
      children: [
        ListView.builder(
          controller: widget.scrollController,
          key: const ValueKey('results_list'),
          padding: const EdgeInsets.only(
            left: SearchConstants.chipGap,
            right: SearchConstants.resultsRightPadding + 14.0,
            bottom: SearchConstants.resultsBottomPadding,
          ),
          itemCount: results.length,
          addRepaintBoundaries: true,
          physics: const ClampingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemBuilder: (context, index) {
            final note = results[index];

            return SearchResultCard(
              key: ValueKey(note.id),
              note: note,
              query: query,
              onTap: () async {
                await Navigator.push(
                  context,
                  AppRouter.slide(NotePage(noteId: note.id)),
                );
                widget.controller.refresh();
              },
            );
          },
        ),

        // Custom Interactive Scrollbar Overlay
        Positioned(
          top: 0,
          bottom: SearchConstants.resultsBottomPadding,
          right: 2,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double trackHeight = constraints.maxHeight;

              return AnimatedBuilder(
                animation: widget.scrollController,
                child: const RepaintBoundary(
                  child: Padding(
                    padding: EdgeInsets.only(left: 20.0),
                    child: SearchDragHandle(),
                  ),
                ),
                builder: (context, cachedHandle) {
                  final scrollCtrl = widget.scrollController;

                  if (!scrollCtrl.hasClients ||
                      scrollCtrl.position.maxScrollExtent <= 0) {
                    return const SizedBox.shrink();
                  }

                  final double progress =
                      (scrollCtrl.offset / scrollCtrl.position.maxScrollExtent)
                          .clamp(0.0, 1.0);

                  return Align(
                    alignment: Alignment(1.0, (progress * 2) - 1.0),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (details) {
                        if (trackHeight <= 0) return;

                        final double deltaProgress =
                            details.delta.dy / trackHeight;
                        final double currentOffset = scrollCtrl.offset;
                        final double newOffset =
                            currentOffset +
                            (deltaProgress *
                                scrollCtrl.position.maxScrollExtent);

                        scrollCtrl.jumpTo(
                          newOffset.clamp(
                            0.0,
                            scrollCtrl.position.maxScrollExtent,
                          ),
                        );
                      },
                      child: cachedHandle,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
