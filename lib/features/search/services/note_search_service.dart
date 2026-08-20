// Search service combines text matching, filters, and ranking for notes.
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/core/database/sqlite_fts_service.dart';
import 'package:notepad/features/search/models/search_date_selection.dart';
import 'package:notepad/features/search/models/search_state.dart';

/// Orchestrates search operations by coordinating between local cache and SQLite indices.
class NoteSearchService {
  /// Executes an asynchronous search based on the provided [searchState].
  static Future<List<NotesSection>> searchAsync(
    SearchState searchState, {
    NoteRepository? repository,
  }) async {
    final activeNotes = (repository ?? noteRepository).activeNotes;

    if (!searchState.hasAnyCriteria) {
      return const [];
    }

    final filters = searchState.filters;
    final startDate = _buildBoundary(filters.start, useMaxValues: false);
    final endDate = filters.isRangeSearch
        ? _buildBoundary(filters.end, useMaxValues: true)
        //If range search is false/no end date is passed,
        //we create a 24-hour time window of existing start date
        : _buildBoundary(filters.start, useMaxValues: true);

    Set<String> matchedIds;

    if (searchState.hasQuery && startDate != null && endDate != null) {
      // Hybrid: Text + Date Range
      matchedIds = await SqliteFtsService.searchIdsWithDateRange(
        searchState.normalizedQuery,
        startDate,
        endDate,
      );
    } else if (searchState.hasQuery) {
      // Text only
      matchedIds = await SqliteFtsService.searchIds(
        searchState.normalizedQuery,
      );
    } else {
      // Date only: Filter in memory for performance on smaller sets.
      return activeNotes
          .where((note) => _matchesFilters(note, startDate, endDate))
          .toList();
    }

    return activeNotes.where((note) => matchedIds.contains(note.id)).toList();
  }

  static bool _matchesFilters(
    NotesSection note,
    DateTime? start,
    DateTime? end,
  ) {
    if (start != null && note.updatedAt.isBefore(start)) return false;
    if (end != null && note.updatedAt.isAfter(end)) return false;
    return true;
  }

  static DateTime? _buildBoundary(
    SearchDateSelection selection, {
    required bool useMaxValues,
  }) {
    if (!selection.hasValues) return null;

    final now = DateTime.now();
    final year = selection.year ?? now.year;
    final month = selection.month ?? (useMaxValues ? 12 : 1);

    // If it's the end of a range and no day is specified, use the last day of that month.
    final day =
        selection.day ?? (useMaxValues ? DateTime(year, month + 1, 0).day : 1);

    final hour = selection.hour ?? (useMaxValues ? 23 : 0);
    final minute = selection.minute ?? (useMaxValues ? 59 : 0);
    final second = useMaxValues ? 59 : 0;

    // Hardened precision: Ensure notes created at the exact edge of a day are captured.
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
