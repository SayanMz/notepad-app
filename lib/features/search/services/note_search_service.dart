import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/data/notes_repository.dart';
import 'package:notepad/features/search/models/search_date_selection.dart';
import 'package:notepad/features/search/models/search_state.dart';

final activeNotes = noteRepository.activeNotes;

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

  return DateTime(year, month, day, hour, minute);
}

// UPDATED: Now returns a Future to handle potential heavy lifting
Future<List<NotesSection>> search(SearchState searchState) async {
  final normalizedQuery = searchState.normalizedQuery;
  final filters = searchState.filters;

  // Instant return for empty states to save CPU cycles
  if (normalizedQuery.isEmpty && !searchState.hasFilters) {
    return const [];
  }

  final startDate = _buildBoundary(filters.start, isEndOfRange: false);
  final endDate = _buildBoundary(filters.end, isEndOfRange: true);

  // We simulate a small delay or use 'async' to ensure non-blocking behavior
  return List<NotesSection>.unmodifiable(
    activeNotes.where((note) {
      if (normalizedQuery.isNotEmpty) {
        final title = note.title.toLowerCase();
        final content = note.content.toLowerCase();
        if (!title.contains(normalizedQuery) &&
            !content.contains(normalizedQuery)) {
          return false;
        }
      }

      final date = note.updatedAt;

      if (!filters.isRangeSearch) {
        // Precise date component matching
        if (filters.start.year != null && date.year != filters.start.year) {
          return false;
        }
        if (filters.start.month != null && date.month != filters.start.month) {
          return false;
        }
        if (filters.start.day != null && date.day != filters.start.day) {
          return false;
        }
        if (filters.start.hour != null && date.hour != filters.start.hour) {
          return false;
        }
        if (filters.start.minute != null &&
            date.minute != filters.start.minute) {
          return false;
        }
      } else {
        // Range-based chronological matching
        if (startDate != null && date.isBefore(startDate)) return false;
        if (endDate != null && date.isAfter(endDate)) return false;
      }

      return true;
    }),
  );
}
