import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/services/search_indexer.dart';
import 'package:notepad/features/search/services/composite_search_indexer.dart';

void main() {
  final note = NotesSection(
    id: 'test-note-1',
    title: 'Indexer Test',
    content: 'Indexer content',
  );

  group('SearchIndexer', () {
    test('NoOpSearchIndexer executes all operations without throwing', () async {
      const indexer = NoOpSearchIndexer();

      expect(() async => await indexer.indexNote(note), returnsNormally);
      expect(() async => await indexer.indexNotesBulk([note]), returnsNormally);
      expect(() async => await indexer.removeNote(note.id), returnsNormally);
      expect(() async => await indexer.removeNotesBulk({note.id}), returnsNormally);
      expect(() async => await indexer.rebuildIndex([note]), returnsNormally);
      expect(() async => await indexer.triggerDeferredEmbedding(note), returnsNormally);
      expect(() async => await indexer.invalidateTopicCache(), returnsNormally);
      expect(() async => await indexer.runMaintenanceSweep([note]), returnsNormally);
    });

    test('CompositeSearchIndexer delegates index operations safely', () async {
      const indexer = CompositeSearchIndexer();

      expect(() async => await indexer.indexNote(note), returnsNormally);
      expect(() async => await indexer.indexNotesBulk([note]), returnsNormally);
      expect(() async => await indexer.removeNote(note.id), returnsNormally);
      expect(() async => await indexer.removeNotesBulk({note.id}), returnsNormally);
      expect(() async => await indexer.invalidateTopicCache(), returnsNormally);
    });
  });
}
