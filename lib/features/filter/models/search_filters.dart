// Search filters model the date, pin, and delete toggles in the dialog.
import 'package:notepad/features/filter/models/search_date_selection.dart';

// Search filters model the checkbox and chip state shown in the dialog.
class SearchFilters {
  const SearchFilters({
    this.isRangeSearch = false,
    this.start = const SearchDateSelection(),
    this.end = const SearchDateSelection(),
  });

  final bool isRangeSearch;
  final SearchDateSelection start;
  final SearchDateSelection end;

  bool get hasFilters => start.hasValues || end.hasValues;

  SearchFilters copyWith({
    bool? isRangeSearch,
    SearchDateSelection? start,
    SearchDateSelection? end,
  }) {
    return SearchFilters(
      isRangeSearch: isRangeSearch ?? this.isRangeSearch,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }
}

