import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/core/services/ui_management/scaffold_messenger_notifier.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/search/controllers/search_controller.dart'
    as search_ctrl;
import 'package:notepad/features/search/models/search_date_selection.dart';
import 'package:notepad/features/search/models/search_filters.dart';
import 'package:notepad/features/search/search_constants.dart';
import 'package:notepad/features/search/services/model_download_service.dart';

/// Renders horizontal quick-date filter chips and ONNX AI semantic topic discovery chips.
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

  void _showDownloadDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('✨ Enable Smart Search'),
          content: const Text(
            'Smart classification organizes your notes into instant topic chips by understanding their core themes.\n\n'
            'We will download a lightweight AI model (~33MB) in the background so you can continue using the app uninterrupted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Maybe Later'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                ModelDownloadService.startBackgroundDownload().then((didStart) {
                  if (!didStart && context.mounted) {
                    showErrorSnackBar(
                      'Download failed to start. Please check your internet connection and try again.',
                    );
                  }
                });
              },
              child: const Text('Download Now'),
            ),
          ],
        );
      },
    );
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
        final topicsCount = controller.suggestedTopics.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Date Filters
            SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(
                  left: SearchConstants.chipLeftPadding,
                ),
                child: Row(
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

            const SizedBox(height: 12),

            // Header: Smart Search with Topic Count Badge
            Padding(
              padding: const EdgeInsets.only(
                left: SearchConstants.chipLeftPadding,
                right: SearchConstants.chipLeftPadding,
              ),
              child: Row(
                children: [
                  Text(
                    'Smart Search',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.colorScheme.secondary.withValues(
                        alpha: 0.8,
                      ),
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (topicsCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: context.colorScheme.secondaryContainer
                            .withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$topicsCount',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: context.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Row 2: Semantic Topic Discoveries
            Padding(
              padding: const EdgeInsets.only(
                left: SearchConstants.chipLeftPadding,
                right: SearchConstants.chipLeftPadding + 10,
                bottom: SearchConstants.chipBottomPadding,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: SearchConstants.chipIconSize,
                    color: context.colorScheme.secondary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: SearchConstants.chipBoltGap),

                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) => true,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.only(
                          right: SearchConstants.chipLeftPadding,
                        ),
                        child: ValueListenableBuilder<ModelDownloadState>(
                          valueListenable: ModelDownloadService.statusNotifier,
                          builder: (context, downloadState, _) {
                            switch (downloadState) {
                              case ModelDownloadState.downloading:
                                return ValueListenableBuilder<double>(
                                  valueListenable:
                                      ModelDownloadService.progressNotifier,
                                  builder: (context, progress, _) {
                                    return _buildActionChip(
                                      label:
                                          '✨ Downloading AI model ${(progress * 100).toInt()}%...',
                                      isSelected: false,
                                      onPressed: () {},
                                      context: context,
                                    );
                                  },
                                );

                              case ModelDownloadState.ready:
                                if (controller.isAnalyzing) {
                                  return _buildActionChip(
                                    label: '✨ Analyzing your notes... ',
                                    isSelected: false,
                                    onPressed: () {},
                                    context: context,
                                  );
                                }

                                if (controller.suggestedTopics.isNotEmpty) {
                                  return Row(
                                    children: controller.suggestedTopics.map((
                                      entry,
                                    ) {
                                      final topic = entry.key;
                                      final count = entry.value;
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: SearchConstants.chipGap,
                                        ),
                                        child: _buildActionChip(
                                          label: '$topic ($count)',
                                          isSelected:
                                              controller.selectedTopic == topic,
                                          onPressed: () {
                                            HapticFeedback.lightImpact();
                                            controller.selectTopic(topic);
                                          },
                                          context: context,
                                          isAI: true,
                                        ),
                                      );
                                    }).toList(),
                                  );
                                }

                                return _buildStaticInfoChip(
                                  label: 'No matching topics found',
                                  context: context,
                                );

                              case ModelDownloadState.idle:
                                return _buildActionChip(
                                  label: '✨ Enable Smart Search',
                                  isSelected: false,
                                  onPressed: () async {
                                    HapticFeedback.mediumImpact();
                                    if (context.mounted) {
                                      _showDownloadDialog(context);
                                    }
                                  },
                                  context: context,
                                );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionChip({
    required String label,
    required bool isSelected,
    required VoidCallback onPressed,
    required BuildContext context,
    bool isAI = false,
  }) {
    final colorScheme = context.colorScheme;

    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? (isAI
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onPrimaryContainer)
              : null,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onPressed: onPressed,
      backgroundColor: isSelected
          ? (isAI
                    ? colorScheme.secondaryContainer
                    : colorScheme.primaryContainer)
                .withValues(alpha: SearchConstants.selectedChipAlpha)
          : (context.isDark
                ? AppColors.searchChipSurfaceDark
                : AppColors.searchChipSurfaceLight),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
    );
  }

  Widget _buildStaticInfoChip({
    required String label,
    required BuildContext context,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color:
            (context.isDark
                    ? AppColors.searchChipSurfaceDark
                    : AppColors.searchChipSurfaceLight)
                .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: context.theme.disabledColor,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
