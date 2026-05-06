import 'package:flutter/material.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/search/models/search_filters.dart';

/// ---------------------------------------------------------------------------
/// SEARCH FILTER BOTTOM SHEET
/// ---------------------------------------------------------------------------
///
/// UI component for configuring search filters (date & time).
///
/// Responsibilities:
/// - Capture user-selected date/time inputs
/// - Support both single-date and range-based filtering
/// - Return updated filter state to caller
///
/// Architectural Role:
/// - Pure UI layer (no business logic)
/// - Delegates filtering behavior to controller via returned state
///
/// Design:
/// - Local mutable state (_state) used for interactive updates
/// - Uses immutable SearchFilters model with copyWith
/// - Handles dynamic UI expansion via AnimatedSize
class SearchFilterBottomSheet extends StatefulWidget {
  const SearchFilterBottomSheet({required this.initialFilters, super.key});

  /// Initial filter state provided by caller
  final SearchFilters initialFilters;

  @override
  State<SearchFilterBottomSheet> createState() =>
      _SearchFilterBottomSheetState();
}

class _SearchFilterBottomSheetState extends State<SearchFilterBottomSheet> {
  /// Theme helper for styling decisions
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  /// Local working copy of filter state
  late SearchFilters _state;

  /// Precomputed dropdown values (date/time components)
  final List<String> _days = List.generate(
    31,
    (i) => (i + 1).toString().padLeft(2, '0'),
  );

  final List<String> _months = List.generate(
    12,
    (i) => (i + 1).toString().padLeft(2, '0'),
  );

  final List<String> _years = List.generate(
    10,
    (i) => (DateTime.now().year - i).toString(),
  );

  final List<String> _hours = List.generate(
    24,
    (i) => i.toString().padLeft(2, '0'),
  );

  final List<String> _minutes = List.generate(
    60,
    (i) => i.toString().padLeft(2, '0'),
  );

  @override
  void initState() {
    super.initState();

    /// Initialize local state from provided filters
    _state = widget.initialFilters;
  }

  /// Clears all filters and resets to default (non-range mode)
  void _clearFilters() {
    setState(() {
      _state = const SearchFilters(isRangeSearch: false);
    });
  }

  /// Submits selected filters and closes bottom sheet
  void _submit() => Navigator.pop(context, _state);

  @override
  Widget build(BuildContext context) {
    /// Handles keyboard/system UI overlap
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkScaffold
            : Theme.of(context).scaffoldBackgroundColor,

        /// Rounded top corners for bottom sheet
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),

      /// Padding includes dynamic bottom inset (keyboard safe)
      padding: EdgeInsets.only(
        left: 20.0,
        right: 20.0,
        top: 12.0,
        bottom: 24.0 + bottomInset,
      ),

      /// Prevents overflow when content expands (AnimatedSize)
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// -----------------------------------------------------------
            /// DRAG HANDLE (Isolated Swipe Trigger)
            /// -----------------------------------------------------------
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (details) {
                // Sensitivity threshold: pops only if swiping down[cite: 9]
                if (details.primaryDelta! > 7) {
                  Navigator.pop(context);
                }
              },
              child: Center(
                child: Container(
                  height: 4,
                  width: 40,
                  // Increased top margin to provide a larger invisible touch target
                  margin: const EdgeInsets.only(top: 10, bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            /// -----------------------------------------------------------
            /// START DATE (OR SINGLE DATE)
            /// -----------------------------------------------------------
            Text(
              _state.isRangeSearch ? 'START DATE' : 'DATE',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 8),

            /// Date selection (Day / Month / Year)
            Row(
              children: [
                Expanded(
                  child: _buildDropdownMenu(
                    hint: 'DD',
                    value: _state.startDay,
                    items: _days,

                    /// Updates day value
                    onChanged: (val) =>
                        setState(() => _state = _state.copyWith(startDay: val)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDropdownMenu(
                    hint: 'MM',
                    value: _state.startMonth,
                    items: _months,

                    /// Updates month value
                    onChanged: (val) => setState(
                      () => _state = _state.copyWith(startMonth: val),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _buildDropdownMenu(
                    hint: 'YYYY',
                    value: _state.startYear,
                    items: _years,

                    /// Updates year value
                    onChanged: (val) => setState(
                      () => _state = _state.copyWith(startYear: val),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// -----------------------------------------------------------
            /// START TIME + RANGE TOGGLE
            /// -----------------------------------------------------------
            Text(
              _state.isRangeSearch ? 'START TIME' : 'TIME',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                /// Hour selection
                Expanded(
                  flex: 2,
                  child: _buildDropdownMenu(
                    hint: 'HH',
                    value: _state.startHour,
                    items: _hours,
                    onChanged: (val) => setState(
                      () => _state = _state.copyWith(startHour: val),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                /// Minute selection
                Expanded(
                  flex: 2,
                  child: _buildDropdownMenu(
                    hint: 'MM',
                    value: _state.startMinute,
                    items: _minutes,
                    onChanged: (val) => setState(
                      () => _state = _state.copyWith(startMinute: val),
                    ),
                  ),
                ),

                const Spacer(flex: 1),

                /// Toggle range search mode
                Expanded(
                  flex: 4,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      /// Styling adapts to theme
                      style: ElevatedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        backgroundColor: isDark
                            ? Theme.of(context).colorScheme.primary
                            : const Color(0xFFF1F5F9),
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),

                      /// Toggle range mode
                      onPressed: () {
                        setState(() {
                          _state = _state.copyWith(
                            isRangeSearch: !_state.isRangeSearch,
                          );
                        });
                      },

                      icon: Icon(
                        _state.isRangeSearch ? Icons.close : Icons.date_range,
                        size: 18,
                        color: isDark ? Colors.black : const Color(0xFF475569),
                      ),

                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Search range',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.black
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            /// -----------------------------------------------------------
            /// END RANGE (VISIBLE ONLY IN RANGE MODE)
            /// -----------------------------------------------------------
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,

              child: !_state.isRangeSearch
                  ? const SizedBox.shrink()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// Divider between sections
                        const Divider(height: 1, color: Colors.grey),

                        const SizedBox(height: 20),

                        /// End date label
                        const Text(
                          'END DATE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),

                        const SizedBox(height: 8),

                        /// End date selection
                        Row(
                          children: [
                            Expanded(
                              child: _buildDropdownMenu(
                                hint: 'DD',
                                value: _state.endDay,
                                items: _days,
                                onChanged: (val) => setState(
                                  () => _state = _state.copyWith(endDay: val),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildDropdownMenu(
                                hint: 'MM',
                                value: _state.endMonth,
                                items: _months,
                                onChanged: (val) => setState(
                                  () => _state = _state.copyWith(endMonth: val),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: _buildDropdownMenu(
                                hint: 'YYYY',
                                value: _state.endYear,
                                items: _years,
                                onChanged: (val) => setState(
                                  () => _state = _state.copyWith(endYear: val),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        /// End time label
                        const Text(
                          'END TIME',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),

                        const SizedBox(height: 8),

                        /// End time selection
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildDropdownMenu(
                                hint: 'HH',
                                value: _state.endHour,
                                items: _hours,
                                onChanged: (val) => setState(
                                  () => _state = _state.copyWith(endHour: val),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: _buildDropdownMenu(
                                hint: 'MM',
                                value: _state.endMinute,
                                items: _minutes,
                                onChanged: (val) => setState(
                                  () =>
                                      _state = _state.copyWith(endMinute: val),
                                ),
                              ),
                            ),
                            const Spacer(flex: 5),
                          ],
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
            ),

            /// -----------------------------------------------------------
            /// ACTION BUTTONS (CLEAR / APPLY)
            /// -----------------------------------------------------------
            Row(
              children: [
                /// Clear filters button
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isDark
                            ? Theme.of(context).colorScheme.primary
                            : const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(
                          color: isDark
                              ? Theme.of(context).colorScheme.primary
                              : const Color(0xFF475569),
                        ),
                      ),
                      onPressed: () {
                        /// Reset and submit
                        _clearFilters();
                        _submit();
                      },
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark
                              ? Colors.black
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                /// Apply filters button
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        backgroundColor: isDark
                            ? Theme.of(context).colorScheme.primary
                            : const Color(0xFF334155),
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                      ),

                      /// Submit selected filters
                      onPressed: _submit,

                      child: Text(
                        'Get Search Results',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark
                              ? Colors.black
                              : const Color(0xFFFFFFFF),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// -------------------------------------------------------------------------
  /// REUSABLE DROPDOWN BUILDER
  /// -------------------------------------------------------------------------
  ///
  /// Ensures consistent styling and behavior across all date/time fields
  Widget _buildDropdownMenu({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),

      /// Dropdown container styling
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),

      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          menuMaxHeight: 250,

          /// Placeholder text
          hint: Text(
            hint,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),

          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: Colors.grey,
          ),

          /// Map items to dropdown entries
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: const TextStyle(fontSize: 14)),
            );
          }).toList(),

          /// Propagate selection change
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// INTERVIEW NOTE
/// ---------------------------------------------------------------------------
///
/// Role:
/// Acts as an interactive UI component for building search filters.
///
/// Why this design:
/// Uses a local mutable state to handle user input smoothly while
/// keeping the underlying SearchFilters model immutable.
///
/// Key Decisions:
/// - copyWith ensures controlled updates without mutating original state
/// - AnimatedSize provides smooth UX for range toggle
/// - Dropdown-based input simplifies structured date/time selection
///
/// Trade-offs:
/// - Uses local state instead of controller-managed state for simplicity
/// - UI handles input formatting (string-based dates), which could be
///   abstracted if complexity increases
