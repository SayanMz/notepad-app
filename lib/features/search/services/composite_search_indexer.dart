import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/services/search_indexer.dart';
import 'package:notepad/features/search/services/fuzzy_search.dart';
import 'package:notepad/features/search/services/semantic_search.dart';

/// Concrete search indexer bridging core repository mutations to [FuzzySearchService] and [SemanticSearchService].
class CompositeSearchIndexer implements SearchIndexerApi {
  const CompositeSearchIndexer();

  @override
  Future<void> indexNote(NotesSection note) async {
    FuzzySearchService.indexNote(note);
  }

  @override
  Future<void> indexNotesBulk(Iterable<NotesSection> notes) async {
    FuzzySearchService.indexNotesBulk(notes);
  }

  @override
  Future<void> removeNote(String noteId) async {
    FuzzySearchService.removeNote(noteId);
  }

  @override
  Future<void> removeNotesBulk(Set<String> noteIds) async {
    FuzzySearchService.removeNotesBulk(noteIds);
  }

  @override
  Future<void> rebuildIndex(List<NotesSection> notes) async {
    await FuzzySearchService.rebuildIndex(notes);
  }

  @override
  Future<void> triggerDeferredEmbedding(NotesSection note) async {
    await SemanticSearchService.embedNoteInBackground(note);
  }

  @override
  Future<void> invalidateTopicCache() async {
    SemanticSearchService.invalidateTopicCache();
  }

  @override
  Future<void> runMaintenanceSweep(List<NotesSection> notes) async {
    await SemanticSearchService.init();
    await SemanticSearchService.runMaintenanceSweep(notes);
  }
}
