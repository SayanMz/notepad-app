import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/features/filter/controllers/search_controller.dart'
    as search_ctrl;
import 'package:notepad/features/filter/search_constants.dart';
import 'package:notepad/features/filter/widgets/search_empty_states.dart';
import 'package:notepad/features/filter/widgets/search_result_card.dart';

class SearchResultsList extends StatefulWidget {
  const SearchResultsList({
    super.key,
    required this.controller,
    required this.onNoteTap,
    required this.scrollController,
  });

  final search_ctrl.SearchController controller;
  final Future<void> Function(NotesSection note) onNoteTap;
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
      return SearchInitialState(key: ValueKey('initial'));
    }
    if (results.isEmpty) {
      return SearchEmptyState(key: const ValueKey('empty'), query: query);
    }

    return ListView.builder(
      controller: widget.scrollController,
      key: const ValueKey('results_list'),
      padding: const EdgeInsets.only(
        left: SearchConstants.chipGap,
        right: SearchConstants.resultsRightPadding,
        bottom: SearchConstants.resultsBottomPadding,
      ),
      itemCount: results.length,
      addRepaintBoundaries: true,

      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),

      itemBuilder: (context, index) {
        final note = results[index];
        return SearchResultCard(
          key: ValueKey(note.id),
          note: note,
          query: query,
          onTap: () => widget.onNoteTap(note),
        );
      },
    );
  }
}
