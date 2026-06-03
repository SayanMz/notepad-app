// Search results panel keeps summary, filters, and list presentation aligned.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/features/filter/controllers/search_controller.dart'
    as search_ctrl;
import 'package:notepad/features/filter/models/search_date_selection.dart';
import 'package:notepad/features/filter/models/search_filters.dart';
import 'package:notepad/features/filter/search_constants.dart';
import 'package:notepad/features/filter/services/smooth_slide_fade.dart';
import 'package:notepad/features/filter/widgets/search_results_list.dart';
import 'package:notepad/features/trash/recycle_constants.dart';

// Results panel coordinates the summary, filters, and searchable list sections.
class SearchResultsPanel extends StatelessWidget {
  const SearchResultsPanel({
    required this.controller,
    required this.onNoteTap,
    required this.showChips,
    required this.onClearFilter,
    required this.scrollController,
    super.key,
  });

  final search_ctrl.SearchController controller;
  final Future<void> Function(NotesSection note) onNoteTap;
  final ValueNotifier<bool> showChips;
  final VoidCallback onClearFilter;
  final ScrollController scrollController;

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

        Expanded(
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, child) {
              return Column(
                children: [
                  _buildMetadataHeader(context, context.isDark),
                  const SizedBox(height: 4),
                  Expanded(
                    child: SearchResultsList(
                      controller: controller,
                      onNoteTap: onNoteTap,
                      scrollController: scrollController,
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

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: hasActiveFilters ? 0 : RecycleConstants.listPadding,
        vertical: SearchConstants.metadataPaddingV,
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
              color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
              tooltip: 'Clear filter',
            ),
          ],
          if (hasCriteria || hasActiveFilters)
            Text(
              resultsCount == 1 ? '1 result' : '$resultsCount results',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChipsSection(BuildContext context) {
    final is1DayActive = _isQuickChipActive(controller.filters, 1);
    final is7DaysActive = _isQuickChipActive(controller.filters, 7);
    final is30DaysActive = _isQuickChipActive(controller.filters, 30);
    final isAnyQuickChipActive =
        is1DayActive || is7DaysActive || is30DaysActive;

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(
          bottom: SearchConstants.chipBottomPadding,
          left: SearchConstants.chipLeftPadding,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.bolt_rounded,
                size: SearchConstants.chipIconSize,
                color: isAnyQuickChipActive
                    ? context.colorScheme.primary
                    : Theme.of(context).disabledColor,
              ),
              const SizedBox(width: SearchConstants.chipBoltGap),
              _buildActionChip(
                label: 'Yesterday',
                isSelected: is1DayActive,
                onPressed: () {
                  _applyQuickFilter(1);
                  HapticFeedback.lightImpact();
                },
                context: context,
              ),
              const SizedBox(width: SearchConstants.chipGap),
              _buildActionChip(
                label: 'Past 7 days',
                isSelected: is7DaysActive,
                onPressed: () {
                  _applyQuickFilter(7);
                  HapticFeedback.lightImpact();
                },
                context: context,
              ),
              const SizedBox(width: SearchConstants.chipGap),
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
    final colorScheme = context.colorScheme;

    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? colorScheme.onPrimaryContainer : null,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onPressed: onPressed,
      backgroundColor: isSelected
          ? colorScheme.primaryContainer.withValues(
              alpha: SearchConstants.selectedChipAlpha,
            )
          : (context.isDark ? Colors.grey[800] : Colors.grey[200]),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
    );
  }
}
