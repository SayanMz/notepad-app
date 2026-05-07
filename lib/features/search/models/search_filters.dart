/// ---------------------------------------------------------------------------
/// SEARCH FILTERS MODEL
/// ---------------------------------------------------------------------------
///
/// Represents the date/time filtering portion of search state.
///
/// Responsibilities:
/// - Encapsulate all filter-related fields
/// - Support both single-date and range-based filtering
/// - Provide utility helpers (e.g., hasFilters)
/// - Enable immutable updates via copyWith
///
/// Design:
/// - Immutable data model
/// - Nullable fields represent "not selected"
/// - Used by controller and UI as a single source of filter truth
class SearchFilters {
  const SearchFilters({
    this.isRangeSearch = false,
    this.startDay,
    this.startMonth,
    this.startYear,
    this.startHour,
    this.startMinute,
    this.endDay,
    this.endMonth,
    this.endYear,
    this.endHour,
    this.endMinute,
  });

  /// Indicates whether search is range-based or single-point
  final bool isRangeSearch;

  /// ---------------------------------------------------------------
  /// START DATE / TIME (OR SINGLE DATE/TIME)
  /// ---------------------------------------------------------------
  final String? startDay;
  final String? startMonth;
  final String? startYear;
  final String? startHour;
  final String? startMinute;

  /// ---------------------------------------------------------------
  /// END DATE / TIME (ONLY USED IN RANGE MODE)
  /// ---------------------------------------------------------------
  final String? endDay;
  final String? endMonth;
  final String? endYear;
  final String? endHour;
  final String? endMinute;

  /// Indicates whether any filter field is set
  ///
  /// Used to:
  /// - Determine if filtering should be applied
  /// - Control UI states (empty vs filtered search)
  bool get hasFilters =>
      startDay != null ||
      startMonth != null ||
      startYear != null ||
      startHour != null ||
      startMinute != null ||
      endDay != null ||
      endMonth != null ||
      endYear != null ||
      endHour != null ||
      endMinute != null;

  /// Creates a modified copy of the current filter state
  ///
  /// Pattern:
  /// - Only provided values override existing ones
  /// - Unspecified fields retain previous values
  ///
  /// Enables:
  /// - Immutable updates
  /// - Safe state transitions in UI and controller
  SearchFilters copyWith({
    bool? isRangeSearch,
    String? startDay,
    String? startMonth,
    String? startYear,
    String? startHour,
    String? startMinute,
    String? endDay,
    String? endMonth,
    String? endYear,
    String? endHour,
    String? endMinute,
  }) {
    //?? (The Null-Coalescing Operator)
    return SearchFilters(
      isRangeSearch: isRangeSearch ?? this.isRangeSearch,
      startDay: startDay ?? this.startDay,
      startMonth: startMonth ?? this.startMonth,
      startYear: startYear ?? this.startYear,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endDay: endDay ?? this.endDay,
      endMonth: endMonth ?? this.endMonth,
      endYear: endYear ?? this.endYear,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
    );
  }
}
