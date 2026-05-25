import 'package:notepad/features/filter/models/search_filters.dart';

/// Holds the full search state: query text plus filters.
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
