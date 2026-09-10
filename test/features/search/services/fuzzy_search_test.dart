import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/features/search/services/fuzzy_search.dart';

void main() {
  group('FuzzySearchService', () {
    final note1 = NotesSection(
      id: 'fz-1',
      title: 'Architectural Blueprint',
      content: 'Designing resilient software architecture and microservices.',
    );
    final note2 = NotesSection(
      id: 'fz-2',
      title: 'Grocery Checklist',
      content: 'Sourdough flour, organic butter, and sea salt.',
    );

    setUp(() async {
      await FuzzySearchService.rebuildIndex([note1, note2]);
    });

    test('findMatches returns note IDs matching query terms with small typos', () {
      // Typo: "Blueprint" -> "Blueprnt"
      final results = FuzzySearchService.findMatches('Blueprnt');
      expect(results, contains('fz-1'));
    });

    test('findMatches returns empty when distance exceeds threshold', () {
      // Large typo on short word
      final results = FuzzySearchService.findMatches('xyzabc');
      expect(results, isEmpty);
    });

    test('removeNote cleans index for a specific note ID', () {
      FuzzySearchService.removeNote('fz-1');
      final results = FuzzySearchService.findMatches('Architectural');
      expect(results, isEmpty);
    });

    test('indexNote ignores deleted notes', () {
      final deletedNote = NotesSection(
        id: 'fz-deleted',
        title: 'Deleted Confidential',
        content: 'Secret content',
        isDeleted: true,
      );
      FuzzySearchService.indexNote(deletedNote);

      final results = FuzzySearchService.findMatches('Confidential');
      expect(results, isEmpty);
    });
  });
}
