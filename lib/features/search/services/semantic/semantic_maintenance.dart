import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/vector_storage.dart';
import 'onnx_embedding_engine.dart';

/// Coordinates background maintenance sweeps and asynchronous note vector indexing.
class SemanticMaintenanceService {
  static bool _isIndexing = false;

  /// Runs background maintenance sweep to index active notes missing vector embeddings.
  static Future<void> runMaintenanceSweep([List<dynamic>? notesList]) async {
    if (_isIndexing) return;
    if (!await OnnxEmbeddingEngine.isModelAvailable()) return;
    await OnnxEmbeddingEngine.init();

    _isIndexing = true;
    try {
      final activeNoteIds = (notesList ?? [])
          .map((n) => n.id as String)
          .toList();

      // Compare active note IDs against stored SQLite vectors to identify notes missing embeddings.
      final missingIds = await VectorStorageService.to
          .getNoteIdsMissingEmbeddings(activeNoteIds);
      if (missingIds.isEmpty) return;

      if (notesList != null && notesList.isNotEmpty) {
        final notesMap = {for (var n in notesList) n.id: n};
        for (final id in missingIds) {
          final note = notesMap[id];
          if (note == null) continue;
          final text = '${note.title}\n\n${note.content}';

          // Process unindexed notes in batch, chunking text and persisting Float32 Uint8List blobs to vector DB.
          final vectors = await OnnxEmbeddingEngine.generateDocumentEmbeddings(
            text,
          );
          if (vectors.isNotEmpty) {
            final blobs = vectors.map((v) => v.buffer.asUint8List()).toList();
            await VectorStorageService.to.upsertEmbeddings(
              id,
              blobs,
              note.updatedAt,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('SemanticMaintenanceService: Sweep error: $e');
    } finally {
      _isIndexing = false;
    }
  }

  /// Fire-and-forget background indexing wrapper for newly saved or updated notes.
  static Future<void> embedNoteInBackground(NotesSection note) async {
    unawaited(() async {
      final text = '${note.title}\n\n${note.content}';
      final vectors = await OnnxEmbeddingEngine.generateDocumentEmbeddings(
        text,
      );
      if (vectors.isNotEmpty) {
        final blobs = vectors.map((v) => v.buffer.asUint8List()).toList();
        await VectorStorageService.to.upsertEmbeddings(
          note.id,
          blobs,
          note.updatedAt,
        );
      }
    }());
  }
}
