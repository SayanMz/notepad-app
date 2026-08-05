import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/features/search/models/search_date_selection.dart';
import 'package:notepad/features/search/models/search_filters.dart';
import 'package:notepad/features/search/models/search_state.dart';
import 'package:notepad/features/search/services/note_search_service.dart';

class FakeNoteRepository extends NoteRepository {
  FakeNoteRepository() : super.internalForTesting();
  List<NotesSection> mockActive = [];
  @override
  List<NotesSection> get activeNotes => mockActive;
}

void main() {
  group('NoteSearchService Logic', () {
    test('searchAsync returns empty list when no criteria provided', () async {
      final results = await NoteSearchService.searchAsync(
        const SearchState(query: '', filters: SearchFilters()),
      );
      expect(results, isEmpty);
    });

    test('searchAsync performs memory-only filter for date-only searches', () async {
      final repo = FakeNoteRepository();
      final note1 = NotesSection(
        title: 'Old Note',
        updatedAt: DateTime(2020, 1, 1),
      );
      final note2 = NotesSection(
        title: 'New Note',
        updatedAt: DateTime(2026, 1, 1),
      );
      repo.mockActive = [note1, note2];

      // Filter for year 2026
      final state = SearchState(
        query: '',
        filters: const SearchFilters(
          start: SearchDateSelection(year: 2026),
        ),
      );

      final results = await NoteSearchService.searchAsync(
        state,
        repository: repo,
      );

      expect(results, hasLength(1));
      expect(results.first.title, 'New Note');
    });
  });
}
