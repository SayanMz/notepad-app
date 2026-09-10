import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/sqlite_fts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await SqliteFtsService.close();
  });

  group('SqliteFtsService', () {
    test('insertOrUpdate and searchIds finds matching note by term', () async {
      final note1 = NotesSection(
        id: 'fts-note-1',
        title: 'Flutter Database Optimization',
        content: 'Using FTS5 and SQLite in-memory tables for instant search.',
        updatedAt: DateTime(2026, 1, 1),
      );
      final note2 = NotesSection(
        id: 'fts-note-2',
        title: 'Cooking Sourdough',
        content: 'Baking sourdough bread with active starter.',
        updatedAt: DateTime(2026, 1, 2),
      );

      await SqliteFtsService.insertOrUpdateBulk([note1, note2]);

      final results = await SqliteFtsService.searchIds('Optimization');
      expect(results, contains('fts-note-1'));
      expect(results, isNot(contains('fts-note-2')));
    });

    test('searchIdsWithDateRange filters results by date boundaries', () async {
      final note1 = NotesSection(
        id: 'range-1',
        title: 'Project Update',
        content: 'Detailed discussion on release strategy.',
        updatedAt: DateTime(2026, 1, 10),
      );
      final note2 = NotesSection(
        id: 'range-2',
        title: 'Project Review',
        content: 'Post-mortem discussion on release deployment.',
        updatedAt: DateTime(2026, 5, 10),
      );

      await SqliteFtsService.insertOrUpdateBulk([note1, note2]);

      final results = await SqliteFtsService.searchIdsWithDateRange(
        'Project',
        DateTime(2026, 1, 1),
        DateTime(2026, 2, 1),
      );

      expect(results, equals(['range-1']));
    });

    test('remove and removeBulk deletes items from the search index', () async {
      final note1 = NotesSection(
        id: 'del-1',
        title: 'Temporary Note 1',
        content: 'Content 1',
        updatedAt: DateTime.now(),
      );
      final note2 = NotesSection(
        id: 'del-2',
        title: 'Temporary Note 2',
        content: 'Content 2',
        updatedAt: DateTime.now(),
      );

      await SqliteFtsService.insertOrUpdateBulk([note1, note2]);
      await SqliteFtsService.remove('del-1');

      var results = await SqliteFtsService.searchIds('Temporary');
      expect(results, equals(['del-2']));

      await SqliteFtsService.removeBulk({'del-2'});
      results = await SqliteFtsService.searchIds('Temporary');
      expect(results, isEmpty);
    });

    test('reindexAllNotes replaces entire index atomically', () async {
      final note1 = NotesSection(
        id: 'reindex-1',
        title: 'Old Title',
        content: 'Old Content',
        updatedAt: DateTime.now(),
      );
      await SqliteFtsService.insertOrUpdate(note1);

      final newNote = NotesSection(
        id: 'reindex-2',
        title: 'New Fresh Title',
        content: 'Fresh Content',
        updatedAt: DateTime.now(),
      );
      await SqliteFtsService.reindexAllNotes([newNote]);

      expect(await SqliteFtsService.searchIds('Old'), isEmpty);
      expect(await SqliteFtsService.searchIds('Fresh'), equals(['reindex-2']));
    });
  });
}
