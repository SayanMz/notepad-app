import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/sqlite_fts.dart';
import 'package:notepad/features/search/models/search_date_selection.dart';
import 'package:notepad/features/search/models/search_filters.dart';
import 'package:notepad/features/search/models/search_state.dart';
import 'package:notepad/features/search/services/note_search_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
        liveCacheMap: const {},
      );
      expect(results, isEmpty);
    });

    test(
      'searchAsync performs memory-only filter for date-only searches',
      () async {
        final mockCache = <String, NotesSection>{};
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
        mockCache['note-1'] = note1;
        mockCache['note-2'] = note2;

        await SqliteFtsService.insertOrUpdateBulk([note1, note2]);

        // Filter for year 2026
        final state = SearchState(
          query: '',
          filters: const SearchFilters(start: SearchDateSelection(year: 2026)),
        );

        final results = await NoteSearchService.searchAsync(
          state,
          liveCacheMap: mockCache,
        );

        expect(results, hasLength(1));
        expect(results.first.title, 'New Note');
      },
    );

    test(
      'searchAsync excludes soft-deleted notes during hydration',
      () async {
        final mockCache = <String, NotesSection>{};
        final activeNote = NotesSection(
          id: 'active-1',
          title: 'Active Note',
          isDeleted: false,
          updatedAt: DateTime(2026, 1, 1),
        );
        final deletedNote = NotesSection(
          id: 'deleted-1',
          title: 'Deleted Note',
          isDeleted: true,
          updatedAt: DateTime(2026, 1, 1),
        );
        mockCache['active-1'] = activeNote;
        mockCache['deleted-1'] = deletedNote;

        await SqliteFtsService.insertOrUpdateBulk([activeNote, deletedNote]);

        final state = const SearchState(
          query: 'Note',
          filters: SearchFilters(),
        );

        final results = await NoteSearchService.searchAsync(
          state,
          liveCacheMap: mockCache,
        );

        expect(results.any((n) => n.id == 'deleted-1'), isFalse);
      },
    );
  });
}
