import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notepad/features/search/models/search_filters.dart';

class SearchFilterBottomSheet extends StatefulWidget {
  const SearchFilterBottomSheet({required this.initialFilters, super.key});

  final SearchFilters initialFilters;

  @override
  State<SearchFilterBottomSheet> createState() =>
      _SearchFilterBottomSheetState();
}

class _SearchFilterBottomSheetState extends State<SearchFilterBottomSheet> {
  late SearchFilters _filterState;
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;

  // Precomputed values for dropdown menus
  static final List<String> _dayItems = List.generate(
    31,
    (index) => (index + 1).toString().padLeft(2, '0'),
  );
  static final List<String> _monthItems = List.generate(
    12,
    (index) => (index + 1).toString().padLeft(2, '0'),
  );
  static final List<String> _yearItems = List.generate(
    10,
    (index) => (DateTime.now().year - index).toString(),
  );
  static final List<String> _hourItems = List.generate(
    24,
    (index) => index.toString().padLeft(2, '0'),
  );
  static final List<String> _minuteItems = List.generate(
    60,
    (index) => index.toString().padLeft(2, '0'),
  );

  @override
  void initState() {
    super.initState();
    _filterState = widget.initialFilters;
  }

  // Model-to-UI conversion logic
  int? _parseSelection(String? selectedString) =>
      selectedString == null ? null : int.tryParse(selectedString);

  String? _getFormattedValue(int? modelValue, List<String> availableItems) {
    if (modelValue == null || availableItems.isEmpty) return null; //

    // Year doesn't need padding; everything else (day, month, time) is 2 digits
    final padding = (availableItems == _yearItems) ? 4 : 2;
    final paddedValue = modelValue.toString().padLeft(padding, '0');

    return availableItems.contains(paddedValue) ? paddedValue : null;
  }

  void _submitFilters() {
    Navigator.pop(context, _filterState);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: 24 + keyboardInset,
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
            const SizedBox(height: 8),
            _buildDateRow(isStartRange: true),
            const SizedBox(height: 20),
            _buildSectionTitle(
              _filterState.isRangeSearch ? 'START TIME' : 'TIME',
            ),
            const SizedBox(height: 8),
            _buildTimeAndToggleRow(),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              child: !_filterState.isRangeSearch
                  ? const SizedBox.shrink()
                  : _buildEndRangeArea(),
            ),
            const SizedBox(height: 24),
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
        const Divider(height: 40, color: Colors.grey),
        _buildSectionTitle('END DATE'),
        const SizedBox(height: 8),
        _buildDateRow(isStartRange: false),
        const SizedBox(height: 20),
        _buildSectionTitle('END TIME'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildDropdown(
                hintText: 'HH',
                selectedValue: _getFormattedValue(
                  _filterState.end.hour,
                  _hourItems,
                ),
                items: _hourItems,
                onChanged: (value) =>
                    _updateSelection(isStart: false, hour: value),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _buildDropdown(
                hintText: 'MM',
                selectedValue: _getFormattedValue(
                  _filterState.end.minute,
                  _minuteItems,
                ),
                items: _minuteItems,
                onChanged: (value) =>
                    _updateSelection(isStart: false, minute: value),
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
      borderRadius: BorderRadius.circular(8),
    );
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: squircleShape,
                backgroundColor: isDarkMode
                    ? Colors.grey[900]
                    : const Color(0xFFF1F5F9),
                side: BorderSide(
                  color: isDarkMode
                      ? Colors.grey[700]!
                      : const Color(0xFF475569),
                ),
              ),
              onPressed: () {
                setState(
                  () =>
                      _filterState = const SearchFilters(isRangeSearch: false),
                );
                _submitFilters();
              },
              child: Text(
                'Clear',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: squircleShape,
                backgroundColor: isDarkMode
                    ? Theme.of(context).colorScheme.primary
                    : const Color(0xFF334155),
              ),
              onPressed: () {
                _submitFilters();
                HapticFeedback.lightImpact();
              },
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
            selectedValue: _getFormattedValue(
              _filterState.start.hour,
              _hourItems,
            ),
            items: _hourItems,
            onChanged: (value) => _updateSelection(isStart: true, hour: value),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _buildDropdown(
            hintText: 'MM',
            selectedValue: _getFormattedValue(
              _filterState.start.minute,
              _minuteItems,
            ),
            items: _minuteItems,
            onChanged: (value) =>
                _updateSelection(isStart: true, minute: value),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor: isDarkMode
                    ? Theme.of(context).colorScheme.primary
                    : const Color(0xFFF1F5F9),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: () => setState(
                () => _filterState = _filterState.copyWith(
                  isRangeSearch: !_filterState.isRangeSearch,
                ),
              ),
              icon: Icon(
                _filterState.isRangeSearch ? Icons.close : Icons.date_range,
                size: 18,
                color: isDarkMode ? Colors.black : const Color(0xFF475569),
              ),
              label: Text(
                'Search range',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.black : const Color(0xFF475569),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Refined update logic with named parameters to match calls
  void _updateSelection({
    required bool isStart,
    String? day,
    String? month,
    String? year,
    String? hour,
    String? minute,
  }) {
    setState(() {
      final targetSelection = isStart ? _filterState.start : _filterState.end;
      final updatedSelection = targetSelection.copyWith(
        day: day != null ? _parseSelection(day) : targetSelection.day,
        month: month != null ? _parseSelection(month) : targetSelection.month,
        year: year != null ? _parseSelection(year) : targetSelection.year,
        hour: hour != null ? _parseSelection(hour) : targetSelection.hour,
        minute: minute != null
            ? _parseSelection(minute)
            : targetSelection.minute,
      );
      _filterState = isStart
          ? _filterState.copyWith(start: updatedSelection)
          : _filterState.copyWith(end: updatedSelection);
    });
  }

  Widget _buildDateRow({required bool isStartRange}) {
    final currentSelection = isStartRange
        ? _filterState.start
        : _filterState.end;
    return Row(
      children: [
        Expanded(
          child: _buildDropdown(
            hintText: 'DD',
            selectedValue: _getFormattedValue(currentSelection.day, _dayItems),
            items: _dayItems,
            onChanged: (value) =>
                _updateSelection(isStart: isStartRange, day: value),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildDropdown(
            hintText: 'MM',
            selectedValue: _getFormattedValue(
              currentSelection.month,
              _monthItems,
            ),
            items: _monthItems,
            onChanged: (value) =>
                _updateSelection(isStart: isStartRange, month: value),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _buildDropdown(
            hintText: 'YYYY',
            selectedValue: _getFormattedValue(
              currentSelection.year,
              _yearItems,
            ),
            items: _yearItems,
            onChanged: (value) =>
                _updateSelection(isStart: isStartRange, year: value),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) => Text(
    title,
    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
  );

  Widget _buildDragHandle() => Center(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (dragDetails) {
        if (dragDetails.primaryDelta! > 10) Navigator.pop(context);
      },
      child: Container(
        height: 4,
        width: 40,
        margin: const EdgeInsets.only(top: 10, bottom: 24),
        decoration: BoxDecoration(
          color: Colors.grey.shade400,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );

  Widget _buildDropdown({
    required String hintText,
    required String? selectedValue,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedValue,
          menuMaxHeight: 300,
          hint: Text(hintText, style: const TextStyle(fontSize: 14)),
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(item, style: const TextStyle(fontSize: 14)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
