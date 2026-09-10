import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/core/database/sqlite_fts.dart';
import 'package:notepad/features/search/models/search_date_selection.dart';
import 'package:notepad/features/search/models/search_filters.dart';
import 'package:notepad/features/search/models/search_state.dart';
import 'package:notepad/features/search/services/note_search_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeNoteRepository extends NoteRepository {
  FakeNoteRepository() : super.internalForTesting();
  List<NotesSection> mockActive = [];
  @override
  List<NotesSection> get activeNotes => mockActive;
  @override
  Map<String, NotesSection> get cacheMap => {for (final n in mockActive) n.id: n};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

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
        id: 'note-1',
        title: 'Old Note',
        updatedAt: DateTime(2020, 1, 1),
      );
      final note2 = NotesSection(
        id: 'note-2',
        title: 'New Note',
        updatedAt: DateTime(2026, 1, 1),
      );
      repo.mockActive = [note1, note2];
      await SqliteFtsService.insertOrUpdateBulk([note1, note2]);

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
