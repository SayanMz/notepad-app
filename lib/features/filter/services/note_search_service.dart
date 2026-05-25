import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/data/notes_repository.dart';
import 'package:notepad/features/filter/models/search_date_selection.dart';
import 'package:notepad/features/filter/models/search_state.dart';

/// Runs a synchronous search on the active notes list using chronological windowing.
List<NotesSection> searchSync(SearchState searchState) {
  final activeNotes = noteRepository.activeNotes;

  if (searchState.normalizedQuery.isEmpty && !searchState.hasFilters) {
    return const [];
  }

  return _performSearchSync(activeNotes, searchState);
}

List<NotesSection> _performSearchSync(
  List<NotesSection> notes,
  SearchState state,
) {
  final normalizedQuery = state.normalizedQuery;
  final filters = state.filters;

  // Consolidate Logic: Build a start and end point for every search
  final startDate = _buildBoundary(filters.start, isEndOfRange: false);

  // If it's a single search, use the start criteria to build the upper bound of the window
  final endDate = filters.isRangeSearch
      ? _buildBoundary(filters.end, isEndOfRange: true)
      : _buildBoundary(filters.start, isEndOfRange: true);

  return notes.where((note) {
    final date = note.updatedAt;

    // --- PHASE 1: CHRONOLOGICAL WINDOW CHECK ---
    // Single comparison is faster than multiple attribute checks
    if (startDate != null && date.isBefore(startDate)) return false;
    if (endDate != null && date.isAfter(endDate)) return false;

    // --- PHASE 2: TEXT CHECK ---
    if (normalizedQuery.isNotEmpty) {
      final titleMatch = note.title.toLowerCase().contains(normalizedQuery);
      final contentMatch = note.content.toLowerCase().contains(normalizedQuery);
      return titleMatch || contentMatch;
    }

    return true;
  }).toList();
}

DateTime? _buildBoundary(
  SearchDateSelection selection, {
  required bool isEndOfRange,
}) {
  if (!selection.hasValues) return null; //

  final now = DateTime.now();
  final year = selection.year ?? now.year;
  final month = selection.month ?? (isEndOfRange ? 12 : 1);

  // Automatically calculate the last day of the month for end-boundaries
  final day =
      selection.day ?? (isEndOfRange ? DateTime(year, month + 1, 0).day : 1);

  final hour = selection.hour ?? (isEndOfRange ? 23 : 0);
  final minute = selection.minute ?? (isEndOfRange ? 59 : 0);

  return DateTime(year, month, day, hour, minute); //
}
