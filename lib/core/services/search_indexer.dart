import 'package:notepad/core/database/app_data.dart';

/// Abstract contract for search indexing, vector embedding, and topic cache invalidation.
abstract class SearchIndexerApi {
  static SearchIndexerApi instance = const NoOpSearchIndexer();

  Future<void> indexNote(NotesSection note);
  Future<void> indexNotesBulk(Iterable<NotesSection> notes);
  Future<void> removeNote(String noteId);
  Future<void> removeNotesBulk(Set<String> noteIds);
  Future<void> rebuildIndex(List<NotesSection> notes);
  Future<void> triggerDeferredEmbedding(NotesSection note);
  Future<void> invalidateTopicCache();
  Future<void> runMaintenanceSweep(List<NotesSection> notes);
}

/// Fallback no-op search indexer used when search subsystem is uninitialized or during isolated testing.
class NoOpSearchIndexer implements SearchIndexerApi {
  const NoOpSearchIndexer();

  @override
  Future<void> indexNote(NotesSection note) async {}

  @override
  Future<void> indexNotesBulk(Iterable<NotesSection> notes) async {}

  @override
  Future<void> removeNote(String noteId) async {}

  @override
  Future<void> removeNotesBulk(Set<String> noteIds) async {}

  @override
  Future<void> rebuildIndex(List<NotesSection> notes) async {}

  @override
  Future<void> triggerDeferredEmbedding(NotesSection note) async {}

  @override
  Future<void> invalidateTopicCache() async {}

  @override
  Future<void> runMaintenanceSweep(List<NotesSection> notes) async {}
}
