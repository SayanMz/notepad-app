import 'package:flutter/foundation.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/data/notes_repository.dart';
import 'package:notepad/features/search/models/search_date_selection.dart';
import 'package:notepad/features/search/models/search_state.dart';

/// Data wrapper required to pass multiple arguments to the background Isolate.
class _SearchTask {
  final List<NotesSection> notes;
  final SearchState state;
  _SearchTask(this.notes, this.state);
}

/// The background worker function.
/// Being a top-level function, it has no access to global state.
List<NotesSection> _performSearch(_SearchTask task) {
  final normalizedQuery = task.state.normalizedQuery;
  final filters = task.state.filters;

  final startDate = _buildBoundary(filters.start, isEndOfRange: false);
  final endDate = _buildBoundary(filters.end, isEndOfRange: true);

  return task.notes.where((note) {
    final date = note.updatedAt;

    // --- PHASE 1: CHEAP DATE CHECKS ---
    if (!filters.isRangeSearch) {
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
      if (filters.start.minute != null && date.minute != filters.start.minute) {
        return false;
      }
    } else {
      if (startDate != null && date.isBefore(startDate)) return false;
      if (endDate != null && date.isAfter(endDate)) return false;
    }

    // --- PHASE 2: TEXT CHECK (Running safely in the background) ---
    if (normalizedQuery.isNotEmpty) {
      if (note.title.toLowerCase().contains(normalizedQuery)) return true;
      if (note.content.toLowerCase().contains(normalizedQuery)) return true;
    }

    return true;
  }).toList();
}

Future<List<NotesSection>> search(SearchState searchState) async {
  // 1. Fetch the live data inside the function to ensure it's never stale
  final activeNotes = noteRepository.activeNotes;

  if (searchState.normalizedQuery.isEmpty && !searchState.hasFilters) {
    return const [];
  }

  // 2. Offload the filtering to a background CPU core to prevent typing lag
  return await compute(_performSearch, _SearchTask(activeNotes, searchState));
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

  return DateTime(year, month, day, hour, minute);
}
