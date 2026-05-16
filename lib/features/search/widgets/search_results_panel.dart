import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/features/search/controllers/search_controller.dart'
    as search_ctrl;
import 'package:notepad/features/search/models/search_date_selection.dart';
import 'package:notepad/features/search/models/search_filters.dart';
import 'package:notepad/features/search/widgets/search_result_card.dart';
import 'package:notepad/features/search/widgets/smooth_slide_fade.dart';
import 'package:notepad/core/services/context_extensions.dart';

class SearchResultsPanel extends StatelessWidget {
  const SearchResultsPanel({
    required this.controller,
    required this.onNoteTap,
    required this.showChips,
    required this.onClearFilter,
    super.key,
  });

  final search_ctrl.SearchController controller;
  final Future<void> Function(NotesSection note) onNoteTap;
  final ValueNotifier<bool> showChips;
  final VoidCallback onClearFilter;

  SearchDateSelection _midnightSelection(DateTime value) {
    return SearchDateSelection(
      year: value.year,
      month: value.month,
      day: value.day,
    );
  }

  void _applyQuickFilter(int daysBack) {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daysBack));

    final filter = SearchFilters(
      isRangeSearch: true,
      start: _midnightSelection(start),
      end: _midnightSelection(now),
    );

    controller.applyFilters(filter);
  }

  bool _isQuickChipActive(SearchFilters currentFilters, int daysBack) {
    if (!currentFilters.isRangeSearch) return false;

    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daysBack));

    return currentFilters.start.year == start.year &&
        currentFilters.start.month == start.month &&
        currentFilters.start.day == start.day &&
        currentFilters.end.year == now.year &&
        currentFilters.end.month == now.month &&
        currentFilters.end.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. The Quick Chips Section
        // Merges the scroll visibility (showChips) and filter states (controller)
        ListenableBuilder(
          listenable: Listenable.merge([showChips, controller]),
          builder: (context, _) {
            return SmoothSlideFade(
              isVisible: showChips.value,
              child: SizedBox(
                key: const ValueKey('chips'),
                width: double.infinity,
                child: _buildChipsSection(context),
              ),
            );
          },
        ),

        // 2. The Search Results & Metadata Section
        // Isolates the heavy list building from the chip animations above
        Expanded(
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, child) {
              return Column(
                children: [
                  _buildMetadataHeader(context, context.isDark),
                  const SizedBox(height: 4),
                  Expanded(
                    child: _SearchResultsList(
                      controller: controller,
                      onNoteTap: onNoteTap,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataHeader(BuildContext context, bool isDarkMode) {
    final resultsCount = controller.results.length;
    final hasCriteria = controller.hasAnyCriteria;
    final hasActiveFilters = controller.hasFilters;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Condition is strong enough: only builds if there is data to show
        if (hasCriteria || hasActiveFilters)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              resultsCount == 1 ? '1 result' : '$resultsCount results',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

        const Spacer(),

        if (hasActiveFilters)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: TextButton.icon(
              onPressed: () {
                controller.clearFilter();
                onClearFilter();
              },
              icon: const Icon(Icons.filter_alt_off, size: 18),
              label: const Text('Clear Filter'),
              style: TextButton.styleFrom(
                foregroundColor: isDarkMode
                    ? Colors.grey[400]
                    : Colors.grey[700],
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChipsSection(BuildContext context) {
    // We calculate activity states once per build cycle of this section
    final is1DayActive = _isQuickChipActive(controller.filters, 1);
    final is7DaysActive = _isQuickChipActive(controller.filters, 7);
    final is30DaysActive = _isQuickChipActive(controller.filters, 30);
    final isAnyQuickChipActive =
        is1DayActive || is7DaysActive || is30DaysActive;

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 5),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.bolt_rounded,
                size: 18,
                color: isAnyQuickChipActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).disabledColor,
              ),
              const SizedBox(width: 22.5),
              _buildActionChip(
                label: 'Yesterday',
                isSelected: is1DayActive,
                onPressed: () {
                  _applyQuickFilter(1);
                  HapticFeedback.lightImpact();
                },
                context: context,
              ),
              const SizedBox(width: 8),
              _buildActionChip(
                label: 'Past 7 days',
                isSelected: is7DaysActive,
                onPressed: () {
                  _applyQuickFilter(7);
                  HapticFeedback.lightImpact();
                },
                context: context,
              ),
              const SizedBox(width: 8),
              _buildActionChip(
                label: 'Past 30 days',
                isSelected: is30DaysActive,
                onPressed: () {
                  _applyQuickFilter(30);
                  HapticFeedback.lightImpact();
                },
                context: context,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required String label,
    required bool isSelected,
    required VoidCallback onPressed,
    required BuildContext context,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          // Make text bold or change color when selected
          color: isSelected ? colorScheme.onPrimaryContainer : null,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onPressed: onPressed,
      backgroundColor: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.8)
          : (context.isDark ? Colors.grey[800] : Colors.grey[200]),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({required this.controller, required this.onNoteTap});

  final search_ctrl.SearchController controller;
  final Future<void> Function(NotesSection note) onNoteTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _buildCurrentContent(),
    );
  }

  Widget _buildCurrentContent() {
    final results = controller.results;
    final query = controller.query;
    final hasCriteria = controller.hasAnyCriteria;

    // IMPORTANT: Keys are required for AnimatedSwitcher to recognize changes
    if (!hasCriteria) {
      return const _SearchInitialState(key: ValueKey('initial'));
    }
    if (results.isEmpty) {
      return _SearchEmptyState(key: const ValueKey('empty'), query: query);
    }

    return ListView.builder(
      key: const ValueKey('results_list'), // Key ensures the list fades in
      padding: const EdgeInsets.only(left: 8, right: 15, bottom: 20),
      itemCount: results.length,
      addRepaintBoundaries: true,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final note = results[index];
        return SearchResultCard(
          key: ValueKey(note.id),
          note: note,
          query: query,
          onTap: () => onNoteTap(note),
        );
      },
    );
  }
}

class _SearchInitialState extends StatelessWidget {
  const _SearchInitialState({super.key});

  @override
  Widget build(BuildContext context) {
    return const SearchMessage(
      title: 'Search your notes by title or content',
      subtitle: 'Type a keyword or use the filter to find notes.',
      icon: Icons.manage_search_rounded,
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({required this.query, super.key});

  final String query;

  @override
  Widget build(BuildContext context) {
    final title = query.isNotEmpty
        ? 'No notes matched "$query"'
        : 'No notes matched your filters';

    return SearchMessage(
      title: title,
      subtitle: 'Try a shorter phrase or adjust your selection.',
      icon: Icons.search_off_rounded,
    );
  }
}
