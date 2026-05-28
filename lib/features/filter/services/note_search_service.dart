import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/data/notes_repository.dart';
import 'package:notepad/core/services/sqlite_fts_service.dart'; // Import service
import 'package:notepad/features/filter/models/search_date_selection.dart';
import 'package:notepad/features/filter/models/search_state.dart';

/// 🌟 CHANGED: Executed asynchronously to pull indexing bounds seamlessly
Future<List<NotesSection>> searchAsync(SearchState searchState) async {
  final activeNotes = noteRepository.activeNotes; //

  if (searchState.normalizedQuery.isEmpty && !searchState.hasFilters) {
    //
    return const []; //
  } //

  // 🌟 THE HYBRID ADVANTAGE: Fetch matching text ID lists instantly via SQLite index
  Set<String>? matchedIds;
  if (searchState.normalizedQuery.isNotEmpty) {
    final ids = await SqliteFtsService.searchIds(searchState.normalizedQuery);
    matchedIds = Set.from(ids);
    if (matchedIds.isEmpty) {
      return const []; // Return fast if no structural string hit matches
    }
  }

  final filters = searchState.filters; //
  final startDate = _buildBoundary(filters.start, isEndOfRange: false); //
  final endDate =
      filters
          .isRangeSearch //
      ? _buildBoundary(filters.end, isEndOfRange: true) //
      : _buildBoundary(filters.start, isEndOfRange: true); //

  return activeNotes.where((note) {
    //
    // Pass 1: Filter immediately using our SQLite O(1) matching ID table
    if (matchedIds != null && !matchedIds.contains(note.id)) return false;

    // Pass 2: Process localized chronological boundaries
    final date = note.updatedAt; //
    if (startDate != null && date.isBefore(startDate)) return false; //
    if (endDate != null && date.isAfter(endDate)) return false; //

    return true; //
  }).toList(); //
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
