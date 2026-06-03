// Search state tracks the query text and active filters.
import 'package:notepad/features/filter/models/search_filters.dart';

// Search state tracks query text and the active filter set.
class SearchState {
  const SearchState({required this.query, required this.filters});

  final String query;
  final SearchFilters filters;

  String get normalizedQuery => query.trim().toLowerCase();
  bool get hasQuery => normalizedQuery.isNotEmpty;
  bool get hasFilters => filters.hasFilters;
  bool get hasAnyCriteria => hasQuery || hasFilters;

  SearchState copyWith({String? query, SearchFilters? filters}) {
    return SearchState(
      query: query ?? this.query,
      filters: filters ?? this.filters,
    );
  }
}

