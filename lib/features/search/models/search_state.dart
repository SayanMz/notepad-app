import 'package:notepad/features/search/models/search_filters.dart';

/// Immutable value model encapsulating search criteria
/// including query text, selected semantic topic, and date filter configurations.
class SearchState {
  const SearchState({
    this.query = '',
    this.filters = const SearchFilters(),
    this.selectedTopic,
  });

  final String query;
  final SearchFilters filters;
  final String? selectedTopic;

  String get normalizedQuery => query.trim().toLowerCase();
  bool get hasQuery => normalizedQuery.isNotEmpty;
  bool get hasFilters => filters.hasFilters;
  bool get hasTopic => selectedTopic != null && selectedTopic!.isNotEmpty;
  bool get hasAnyCriteria => hasQuery || hasFilters || hasTopic;

  SearchState copyWith({
    String? query,
    SearchFilters? filters,
    String? Function()? selectedTopic,
  }) {
    return SearchState(
      query: query ?? this.query,
      filters: filters ?? this.filters,
      selectedTopic: selectedTopic != null
          ? selectedTopic()
          : this.selectedTopic,
    );
  }
}
