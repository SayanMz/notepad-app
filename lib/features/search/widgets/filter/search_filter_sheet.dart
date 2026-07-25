import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/search/models/search_date_selection.dart';
import 'package:notepad/features/search/models/search_filters.dart';
import 'package:notepad/features/search/search_constants.dart';

// Search filter sheet owns date-range criteria editing and submission.
class SearchFilterBottomSheet extends StatefulWidget {
  const SearchFilterBottomSheet({required this.initialFilters, super.key});

  final SearchFilters initialFilters;

  @override
  State<SearchFilterBottomSheet> createState() =>
      _SearchFilterBottomSheetState();
}

class _SearchFilterBottomSheetState extends State<SearchFilterBottomSheet> {
  late SearchFilters _filterState;
  bool get isDarkMode => context.isDark;

  static final List<String> _dayItems = List.generate(
    SearchConstants.filterDayOptionCount,
    (index) => (index + 1).toString().padLeft(2, '0'),
  );
  static final List<String> _monthItems = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  static final List<String> _yearItems = List.generate(
    SearchConstants.filterYearOptionCount,
    (index) => (DateTime.now().year - index).toString(),
  );
  static final List<String> _hourItems = List.generate(
    SearchConstants.filterHourOptionCount,
    (index) => index.toString().padLeft(2, '0'),
  );
  static final List<String> _minuteItems = List.generate(
    SearchConstants.filterMinuteOptionCount,
    (index) => index.toString().padLeft(2, '0'),
  );

  @override
  void initState() {
    super.initState();
    _filterState = widget.initialFilters;
  }

  //Converts month or numeric string items into their corresponding integer values.
  int? _parseFromUi(String? selectedString, List<String> items) {
    if (selectedString == null) return null;

    if (items == _monthItems) {
      final index = _monthItems.indexOf(selectedString);
      return index != -1 ? index + 1 : null;
    }

    return int.tryParse(selectedString);
  }

  //Formats model integers into zero-padded strings or month abbreviations for dropdown matching.
  String? _formatForUi(int? modelValue, List<String> availableItems) {
    if (modelValue == null || availableItems.isEmpty) return null;

    if (availableItems == _monthItems) {
      return (modelValue >= 1 && modelValue <= 12)
          ? _monthItems[modelValue - 1]
          : null;
    }

    final padding = (availableItems == _yearItems)
        ? SearchConstants.filterYearDisplayPadding
        : SearchConstants.filterDateTimeDisplayPadding;
    return modelValue.toString().padLeft(padding, '0');
  }

  //Ensures filter inputs are complete and chronologically ordered before enabling submission.
  bool get _isSubmitEnabled {
    if (!_filterState.start.hasValues) return false;
    if (!_filterState.isRangeSearch) return true;
    if (!_filterState.end.hasValues) return false;

    // Converts date components into a single comparable integer weight.
    int score(SearchDateSelection selection) =>
        (selection.year ?? 0) * 100000000 +
        (selection.month ?? 0) * 1000000 +
        (selection.day ?? 0) * 10000 +
        (selection.hour ?? 0) * 100 +
        (selection.minute ?? 0);

    return score(_filterState.start) < score(_filterState.end);
  }

  void _submitFilters() {
    Navigator.pop(context, _filterState);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = context.viewInsetsBottom;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkDialogSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SearchConstants.filterSheetRadius),
        ),
      ),
      padding: EdgeInsets.only(
        left: SearchConstants.filterSheetPaddingH,
        right: SearchConstants.filterSheetPaddingH,
        top: SearchConstants.filterSheetPaddingTop,
        bottom: SearchConstants.filterSheetPaddingBottom + keyboardInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDragHandle(),
            _buildSectionTitle(
              _filterState.isRangeSearch ? 'START DATE' : 'DATE',
            ),
            const SizedBox(height: SearchConstants.filterSectionGap),
            _buildDateRow(),
            const SizedBox(height: SearchConstants.filterGroupGap),
            _buildSectionTitle(
              _filterState.isRangeSearch ? 'START TIME' : 'TIME',
            ),
            const SizedBox(height: SearchConstants.filterSectionGap),
            _buildTimeAndToggleRow(),
            AnimatedSize(
              duration: AnimationConstants.medium,
              curve: Curves.easeInOutCubic,
              child: !_filterState.isRangeSearch
                  ? const SizedBox.shrink()
                  : _buildEndRangeArea(),
            ),
            const SizedBox(height: SearchConstants.filterFooterGap),
            _buildFooterButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildEndRangeArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(
          height: SearchConstants.filterDividerHeight,
          color: Colors.grey,
        ),
        _buildSectionTitle('END DATE'),
        const SizedBox(height: SearchConstants.filterSectionGap),
        _buildDateRow(isRangeSearch: true),
        const SizedBox(height: SearchConstants.filterGroupGap),
        _buildSectionTitle('END TIME'),
        const SizedBox(height: SearchConstants.filterSectionGap),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildDropdown(
                hintText: 'HH',
                selectedValue: _formatForUi(_filterState.end.hour, _hourItems),
                items: _hourItems,
                onChanged: (value) =>
                    _updateSelection(isRangeSearch: true, hour: value),
              ),
            ),
            const SizedBox(width: SearchConstants.filterSectionGap),
            Expanded(
              flex: 2,
              child: _buildDropdown(
                hintText: 'MM',
                selectedValue: _formatForUi(
                  _filterState.end.minute,
                  _minuteItems,
                ),
                items: _minuteItems,
                onChanged: (value) =>
                    _updateSelection(isRangeSearch: true, minute: value),
              ),
            ),
            const Spacer(flex: 5),
          ],
        ),
      ],
    );
  }

  Widget _buildFooterButtons() {
    final squircleShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SearchConstants.filterButtonRadius),
    );

    return Row(
      children: [
        Expanded(
          flex: 1,
          child: SizedBox(
            height: SearchConstants.filterButtonHeight,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: squircleShape,
                backgroundColor: isDarkMode
                    ? Colors.grey[900]
                    : AppColors.searchFilterButtonLight,
                side: BorderSide(
                  color: isDarkMode
                      ? Colors.grey[700]!
                      : AppColors.searchFilterTextLight,
                ),
              ),
              onPressed: _filterState.hasFilters
                  ? () {
                      setState(() {
                        _filterState = SearchFilters(
                          isRangeSearch: _filterState.isRangeSearch,
                        );
                      });
                    }
                  : null,

              child: Text(
                'Clear',
                style: TextStyle(
                  color: isDarkMode
                      ? Colors.white
                      : AppColors.searchFilterTextLight,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: SearchConstants.filterButtonGap),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: SearchConstants.filterButtonHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: squircleShape,
                backgroundColor: isDarkMode
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.9)
                    : AppColors.searchFilterSubmitLight,
              ),
              onPressed: _isSubmitEnabled
                  ? () {
                      _submitFilters();
                      HapticFeedback.lightImpact();
                    }
                  : null,
              child: Text(
                'Get Search Results',
                style: TextStyle(
                  color: isDarkMode ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeAndToggleRow() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildDropdown(
            hintText: 'HH',
            selectedValue: _formatForUi(_filterState.start.hour, _hourItems),
            items: _hourItems,
            onChanged: (value) => _updateSelection(hour: value),
          ),
        ),
        const SizedBox(width: SearchConstants.filterSectionGap),
        Expanded(
          flex: 2,
          child: _buildDropdown(
            hintText: 'MM',
            selectedValue: _formatForUi(
              _filterState.start.minute,
              _minuteItems,
            ),
            items: _minuteItems,
            onChanged: (value) => _updateSelection(minute: value),
          ),
        ),
        const SizedBox(width: SearchConstants.filterButtonGap),
        Expanded(
          flex: 4,
          child: SizedBox(
            height: SearchConstants.filterButtonHeight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    SearchConstants.filterButtonRadius,
                  ),
                ),
                backgroundColor: isDarkMode
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.9)
                    : AppColors.searchFilterButtonLight,
                padding: const EdgeInsets.symmetric(
                  horizontal: SearchConstants.filterTogglePaddingH,
                ),
              ),
              onPressed: _toggleRangeSearch,
              icon: Icon(
                _filterState.isRangeSearch ? Icons.close : Icons.date_range,
                size: SearchConstants.chipIconSize,
                color: isDarkMode
                    ? Colors.black
                    : AppColors.searchFilterTextLight,
              ),
              label: Text(
                'Search range',
                style: TextStyle(
                  fontSize: SearchConstants.filterLabelFontSize,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode
                      ? Colors.black
                      : AppColors.searchFilterTextLight,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateRow({bool isRangeSearch = false}) {
    final currentSelection = !isRangeSearch
        ? _filterState.start
        : _filterState.end;

    return Row(
      children: [
        Expanded(
          child: _buildDropdown(
            hintText: 'DD',
            selectedValue: _formatForUi(currentSelection.day, _dayItems),
            items: _dayItems,
            onChanged: (value) =>
                _updateSelection(isRangeSearch: isRangeSearch, day: value),
          ),
        ),
        const SizedBox(width: SearchConstants.filterSectionGap),
        Expanded(
          child: _buildDropdown(
            hintText: 'MM',
            selectedValue: _formatForUi(currentSelection.month, _monthItems),
            items: _monthItems,
            onChanged: (value) =>
                _updateSelection(isRangeSearch: isRangeSearch, month: value),
          ),
        ),
        const SizedBox(width: SearchConstants.filterSectionGap),
        Expanded(
          flex: 2,
          child: _buildDropdown(
            hintText: 'YYYY',
            selectedValue: _formatForUi(currentSelection.year, _yearItems),
            items: _yearItems,
            onChanged: (value) =>
                _updateSelection(isRangeSearch: isRangeSearch, year: value),
          ),
        ),
      ],
    );
  }

  void _updateSelection({
    bool isRangeSearch = false,
    String? day,
    String? month,
    String? year,
    String? hour,
    String? minute,
  }) {
    final targetSelection = !isRangeSearch
        ? _filterState.start
        : _filterState.end;

    final updatedSelection = targetSelection.copyWith(
      day: _parseFromUi(day, _dayItems) ?? targetSelection.day,
      month: _parseFromUi(month, _monthItems) ?? targetSelection.month,
      year: _parseFromUi(year, _yearItems) ?? targetSelection.year,
      hour: _parseFromUi(hour, _hourItems) ?? targetSelection.hour,
      minute: _parseFromUi(minute, _minuteItems) ?? targetSelection.minute,
    );

    _filterState = !isRangeSearch
        ? _filterState.copyWith(start: updatedSelection)
        : _filterState.copyWith(end: updatedSelection);
  }

  Widget _buildDragHandle() => Center(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (dragDetails) {
        if (dragDetails.primaryDelta! >
            SearchConstants.filterDragDismissDistance) {
          Navigator.pop(context);
        }
      },
      child: Container(
        height: SearchConstants.filterSheetHandleHeight,
        width: SearchConstants.filterSheetHandleWidth,
        margin: const EdgeInsets.only(
          top: SearchConstants.filterSheetHandleTopMargin,
          bottom: SearchConstants.filterSheetHandleBottomMargin,
        ),
        decoration: BoxDecoration(
          color: Colors.grey.shade400,
          borderRadius: BorderRadius.circular(
            SearchConstants.filterSheetHandleRadius,
          ),
        ),
      ),
    ),
  );

  Widget _buildSectionTitle(String title) => Text(
    title,
    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
  );

  Widget _buildDropdown({
    required String hintText,
    required String? selectedValue,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    String? localValue = selectedValue;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SearchConstants.filterDropdownPaddingH,
        vertical: SearchConstants.filterDropdownPaddingV,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(SearchConstants.filterButtonRadius),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: localValue,
          onChanged: (value) {
            onChanged(value);
            setState(() {
              localValue = value;
            });
          },
          menuMaxHeight: SearchConstants.filterDropdownMaxHeight,
          hint: Text(
            hintText,
            style: const TextStyle(
              fontSize: SearchConstants.filterDropdownFontSize,
            ),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: SearchConstants.filterDropdownFontSize,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _toggleRangeSearch() {
    setState(() {
      _filterState = _filterState.copyWith(
        isRangeSearch: !_filterState.isRangeSearch,
      );
    });
  }
}
