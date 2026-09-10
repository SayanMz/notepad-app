import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/core/database/sqlite_fts.dart';
import 'package:notepad/features/search/models/search_date_selection.dart';
import 'package:notepad/features/search/models/search_state.dart';
import 'package:notepad/features/search/services/fuzzy_search.dart';
import 'package:notepad/features/search/services/semantic_search.dart';

/// Orchestrates multi-modal search execution across
/// ONNX semantic topics, SQLite FTS5 full-text queries, Fuzzy typo matching, and date-range filters.
class NoteSearchService {
  static Future<List<NotesSection>> searchAsync(
    SearchState searchState, {
    NoteRepository? repository,
  }) async {
    if (!searchState.hasAnyCriteria) return const [];

    final repo = repository ?? noteRepository;
    final filters = searchState.filters;
    final startDate = _buildBoundary(filters.start, useMaxValues: false);
    final endDate = filters.isRangeSearch
        ? _buildBoundary(filters.end, useMaxValues: true)
        : _buildBoundary(filters.start, useMaxValues: true);

    // 1. Semantic Topic Match
    List<String>? topicIds;
    if (searchState.hasTopic) {
      topicIds = await SemanticSearchService.getNoteIdsForTopic(
        searchState.selectedTopic!,
        start: startDate,
        end: endDate,
      );
    }

    // 2. Keyword Search
    List<String>? queryIds;
    if (searchState.hasQuery) {
      final query = searchState.normalizedQuery;
      if (startDate != null && endDate != null) {
        queryIds = await SqliteFtsService.searchIdsWithDateRange(
          query,
          startDate,
          endDate,
        );
      } else {
        queryIds = await SqliteFtsService.searchIds(query);
      }

      // Typo tolerance fallback when FTS5 misses:
      if (queryIds.isEmpty) {
        queryIds = FuzzySearchService.findMatches(query).toList();
      }
    }

    // 3. Resolve Final IDs (Text, Topic, or Date-Only)
    List<String> finalOrderedIds;

    if (queryIds != null && topicIds != null) {
      final topicSet = topicIds.toSet();
      finalOrderedIds = queryIds.where((id) => topicSet.contains(id)).toList();
    } else if (queryIds != null || topicIds != null) {
      finalOrderedIds = queryIds ?? topicIds!;
    } else if (startDate != null && endDate != null) {
      finalOrderedIds = await SqliteFtsService.searchIdsByDateRange(
        startDate,
        endDate,
      );
    } else {
      return const [];
    }

    // 4. O(M) Hydration via repository cache
    final cache = repo.cacheMap;
    return finalOrderedIds
        .map((id) => cache[id])
        .whereType<NotesSection>()
        .where((n) => !n.isDeleted)
        .toList();
  }

  static DateTime? _buildBoundary(
    SearchDateSelection selection, {
    required bool useMaxValues,
  }) {
    if (!selection.hasValues) return null;

    final now = DateTime.now();
    final year = selection.year ?? now.year;
    final month = selection.month ?? (useMaxValues ? 12 : 1);
    final day =
        selection.day ?? (useMaxValues ? DateTime(year, month + 1, 0).day : 1);
    final hour = selection.hour ?? (useMaxValues ? 23 : 0);
    final minute = selection.minute ?? (useMaxValues ? 59 : 0);
    final second = useMaxValues ? 59 : 0;
    final millisecond = useMaxValues ? 999 : 0;
    final microsecond = useMaxValues ? 999 : 0;

    return DateTime(
      year,
      month,
      day,
      hour,
      minute,
      second,
      millisecond,
      microsecond,
    );
  }
}
