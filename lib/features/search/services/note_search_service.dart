// Search service combines text matching, filters, and ranking for notes.
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/core/database/sqlite_fts_service.dart';
import 'package:notepad/features/search/models/search_date_selection.dart';
import 'package:notepad/features/search/models/search_state.dart';

Future<List<NotesSection>> searchAsync(SearchState searchState) async {
  final activeNotes = noteRepository.activeNotes;

  if (!searchState.hasAnyCriteria) {
    return const [];
  }

  final filters = searchState.filters;
  final startDate = _buildBoundary(filters.start, isEndOfRange: false);
  final endDate = filters.isRangeSearch
      ? _buildBoundary(filters.end, isEndOfRange: true)
      : _buildBoundary(filters.start, isEndOfRange: true);

  Set<String> matchedIds;

  if (searchState.hasQuery && startDate != null && endDate != null) {
    // Hybrid: Text + Date Range
    matchedIds = (await SqliteFtsService.searchIdsWithDateRange(
      searchState.normalizedQuery,
      startDate,
      endDate,
    ));
  } else if (searchState.hasQuery) {
    // Text only
    matchedIds = await SqliteFtsService.searchIds(searchState.normalizedQuery);
  } else {
    // Date only (Optional: Add a dedicated SQL method for date-only if needed)
    // For now, if only filters exist, we filter in memory or add a SQL method
    return activeNotes
        .where((note) => _matchesFilters(note, startDate, endDate))
        .toList();
  }

  return activeNotes.where((note) => matchedIds.contains(note.id)).toList();
}

bool _matchesFilters(NotesSection note, DateTime? start, DateTime? end) {
  if (start != null && note.updatedAt.isBefore(start)) return false;
  if (end != null && note.updatedAt.isAfter(end)) return false;
  return true;
}

DateTime? _buildBoundary(
  SearchDateSelection selection, {
  required bool isEndOfRange,
}) {
  if (!selection.hasValues) return null;

  final now = DateTime.now();
  final year = selection.year ?? now.year;
  final month = selection.month ?? (isEndOfRange ? 12 : 1);
  final day =
      selection.day ?? (isEndOfRange ? DateTime(year, month + 1, 0).day : 1);
  final hour = selection.hour ?? (isEndOfRange ? 23 : 0);
  final minute = selection.minute ?? (isEndOfRange ? 59 : 0);
  final second = isEndOfRange ? 59 : 0;
  final millisecond = isEndOfRange ? 999 : 0;

  return DateTime(year, month, day, hour, minute, second, millisecond);
}

