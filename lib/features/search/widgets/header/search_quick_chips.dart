import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/search/controllers/search_controller.dart'
    as search_ctrl;
import 'package:notepad/features/search/models/search_date_selection.dart';
import 'package:notepad/features/search/models/search_filters.dart';
import 'package:notepad/features/search/search_constants.dart';

// Quick chips apply common date-range filters for fast search narrowing.
class SearchQuickChips extends StatelessWidget {
  const SearchQuickChips({super.key, required this.controller});

  final search_ctrl.SearchController controller;

  SearchDateSelection _midnightSelection(DateTime value) {
    return SearchDateSelection(
      year: value.year,
      month: value.month,
      day: value.day,
    );
  }

  void _applyQuickFilter(int daysBack) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: daysBack));
    final isSpecificDay = daysBack == 1;

    final filter = SearchFilters(
      isRangeSearch: !isSpecificDay,
      start: _midnightSelection(start),
      end: isSpecificDay
          ? const SearchDateSelection()
          : _midnightSelection(today),
    );

    controller.applyFilters(filter);
  }

  bool _isQuickChipActive(SearchFilters currentFilters, int daysBack) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: daysBack));

    if (daysBack == 1) {
      return !currentFilters.isRangeSearch &&
          currentFilters.start.year == start.year &&
          currentFilters.start.month == start.month &&
          currentFilters.start.day == start.day;
    }

    if (!currentFilters.isRangeSearch) return false;

    return currentFilters.start.year == start.year &&
        currentFilters.start.month == start.month &&
        currentFilters.start.day == start.day &&
        currentFilters.end.year == today.year &&
        currentFilters.end.month == today.month &&
        currentFilters.end.day == today.day;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
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
                        : context.theme.disabledColor,
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
      },
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
          : (context.isDark
                ? AppColors.searchChipSurfaceDark
                : AppColors.searchChipSurfaceLight),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
    );
  }
}
