import 'package:notepad/features/search/models/search_date_selection.dart';

// SearchFilters stores the active date-range criteria and range mode for search.
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

