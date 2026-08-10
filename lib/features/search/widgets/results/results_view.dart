import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/core/services/ui_management/app_router.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/note/note_page.dart';
import 'package:notepad/features/search/controllers/search_controller.dart'
    as search_ctrl;
import 'package:notepad/features/search/search_constants.dart';
import 'package:notepad/features/search/widgets/results/drag_handle.dart';
import 'package:notepad/features/search/widgets/results/empty_states.dart';
import 'package:notepad/features/search/widgets/results/result_card.dart';
import 'package:notepad/features/trash/recycle_constants.dart';

// Matches Block A (112) + Block B (56) from SearchPage
const double kTotalFloatingHeaderHeight = 168.0;

// Header widget that shows result count and provides filter-clearing controls.
class ResultsMetadataHeader extends StatelessWidget {
  const ResultsMetadataHeader({
    super.key,
    required this.controller,
    required this.onClearFilter,
  });

  final search_ctrl.SearchController controller;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isDarkMode = context.isDark;
        final resultsCount = controller.results.length;
        final hasCriteria = controller.hasAnyCriteria;
        final hasActiveFilters = controller.hasFilters;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: hasActiveFilters
                ? SearchConstants.panelPadding
                : SearchConstants.panelPadding + RecycleConstants.listPadding,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (hasActiveFilters) ...[
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    controller.clearFilter();
                    onClearFilter();
                  },
                  icon: const Icon(Icons.filter_alt_off, size: 25),
                  color: isDarkMode
                      ? context.theme.colorScheme.onSurfaceVariant
                      : AppColors.searchMetadataTextLight,
                  tooltip: 'Clear filter',
                ),
              ],
              if (hasCriteria || hasActiveFilters)
                Text(
                  resultsCount == 1 ? '1 result' : '$resultsCount results',
                  style: TextStyle(
                    color: isDarkMode
                        ? context.theme.colorScheme.onSurfaceVariant
                        : AppColors.searchMetadataTextLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// Results screen that swaps between empty states, the results list, and has the draggable scroll handle.
class ResultsView extends StatefulWidget {
  const ResultsView({
    super.key,
    required this.controller,
    required this.scrollController,
  });

  final search_ctrl.SearchController controller;
  final ScrollController scrollController;

  @override
  State<ResultsView> createState() => ResultsViewState();
}

class ResultsViewState extends State<ResultsView> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return AnimatedSwitcher(
          duration: AnimationConstants.fast,
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: _buildCurrentContent(),
        );
      },
    );
  }

  Widget _buildCurrentContent() {
    final results = widget.controller.results;
    final query = widget.controller.query;
    final hasCriteria = widget.controller.hasAnyCriteria;

    if (!hasCriteria) {
      return const Padding(
        padding: EdgeInsets.only(top: kTotalFloatingHeaderHeight),
        child: SearchInitialState(key: ValueKey('initial')),
      );
    }
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: kTotalFloatingHeaderHeight),
        child: SearchEmptyState(key: const ValueKey('empty'), query: query),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          controller: widget.scrollController,
          key: const ValueKey('results_list'),
          padding: const EdgeInsets.only(
            top: kTotalFloatingHeaderHeight,
            left: SearchConstants.panelPadding + SearchConstants.chipGap,
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

            return ResultCard(
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

        Positioned(
          top: kTotalFloatingHeaderHeight,
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
                    child: DragHandle(),
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
