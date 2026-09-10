import 'package:flutter/foundation.dart';
import 'package:notepad/core/database/vector_storage.dart';

import 'onnx_embedding_engine.dart';
import 'semantic_taxonomy.dart';
import 'vector_math.dart';

/// Discovers candidate taxonomy topics and matches notes against topic vector embeddings.
class TopicDiscoveryService {
  static List<MapEntry<String, int>>? _cachedTopics;
  static final Map<String, List<String>> _topicNoteIdsCache = {};

  // Runtime vector cache for candidate taxonomy strings to avoid redundant neural passes.
  static final Map<String, Float32List> _topicVectorCache = {};
  static final Map<String, String> _candidateTaxonomy =
      SemanticTaxonomy.topicDescriptions;

  /// Clears in-memory topic suggestion and note ID caches.
  static void invalidateCache() {
    _cachedTopics = null;
    _topicNoteIdsCache.clear();
  }

  /// Computes or retrieves cached 384-d vector embedding for a taxonomy topic string.
  static Future<Float32List?> _getOrComputeTopicVector(
    String topicTitle,
    String description,
  ) async {
    Float32List? topicVector = _topicVectorCache[topicTitle];
    if (topicVector == null) {
      // We embed the rich description, not just the short title, to cast a wider semantic net.
      final vecs = await OnnxEmbeddingEngine.generateDocumentEmbeddings(
        description,
      );
      if (vecs.isNotEmpty) {
        topicVector = vecs.first;
        _topicVectorCache[topicTitle] = topicVector;
      }
    }
    return topicVector;
  }

  /// Evaluates candidate topics against active note vector embeddings and returns top qualified topic matches.
  static Future<List<MapEntry<String, int>>> discoverSuggestedTopics({
    required Set<String> activeNoteIds,
    int maxTopics = 6,
    double minSimilarity = 0.32,
  }) async {
    if (_cachedTopics != null && _cachedTopics!.isNotEmpty) {
      return _cachedTopics!;
    }
    if (!await OnnxEmbeddingEngine.isModelAvailable()) return [];
    await OnnxEmbeddingEngine.init();

    try {
      // Fetch all stored vector blobs from SQLite and parse Uint8List buffers into Float32List vectors.
      final allEmbeddings = await VectorStorageService.to.fetchAllEmbeddings();
      final activeEmbeddings = allEmbeddings
          .where((e) => activeNoteIds.contains(e['note_id'] as String))
          .toList();
      if (activeEmbeddings.isEmpty) return [];

      final List<Map<String, dynamic>> parsedEntries = activeEmbeddings.map((
        e,
      ) {
        final blob = e['embedding'] as Uint8List;
        return {
          'note_id': e['note_id'] as String,
          'vector': Uint8List.fromList(blob).buffer.asFloat32List(),
        };
      }).toList();

      // Intermediate score collection: { topicTitle: { noteId: maxChunkScore } }
      final Map<String, Map<String, double>> rawTopicNoteScores = {};
      // Tracks the absolute highest score and winning topic per note across all candidate topics.
      final Map<String, double> noteGlobalBestScore = {};
      final Map<String, String> noteWinningTopic = {};

      // Cross-reference candidate taxonomy topic vectors against note chunk vectors using cosine similarity.
      for (final taxonomyEntry in _candidateTaxonomy.entries) {
        final topicTitle = taxonomyEntry.key;
        final topicDescription = taxonomyEntry.value;

        final topicVector = await _getOrComputeTopicVector(
          topicTitle,
          topicDescription,
        );
        if (topicVector == null) continue;

        final Map<String, double> noteScores = {};

        for (final entry in parsedEntries) {
          final noteId = entry['note_id'] as String;
          final chunkVector = entry['vector'] as Float32List;

          final chunkScore = VectorMath.cosineSimilarity(
            topicVector,
            chunkVector,
          );
          if (chunkScore >= minSimilarity) {
            final currentBestScore = noteScores[noteId] ?? 0.0;
            if (chunkScore > currentBestScore) {
              noteScores[noteId] = chunkScore;
            }
          }
        }

        if (noteScores.isNotEmpty) {
          rawTopicNoteScores[topicTitle] = noteScores;

          // Track which topic yields the global maximum score for each note.
          for (final e in noteScores.entries) {
            final noteId = e.key;
            final score = e.value;
            final currentMax = noteGlobalBestScore[noteId] ?? 0.0;
            if (score > currentMax) {
              noteGlobalBestScore[noteId] = score;
              noteWinningTopic[noteId] = topicTitle;
            }
          }
        }
      }

      final List<MapEntry<String, int>> qualifiedTopics = [];
      _topicNoteIdsCache.clear();

      // Global winner-take-all pass: Retain a note strictly within its highest-scoring topic.
      for (final entry in rawTopicNoteScores.entries) {
        final topicTitle = entry.key;
        final noteScores = entry.value;

        final winningNotesForTopic =
            noteScores.entries
                .where((e) => noteWinningTopic[e.key] == topicTitle)
                .toList()
              ..sort((a, b) => b.value.compareTo(a.value));

        if (winningNotesForTopic.isNotEmpty) {
          qualifiedTopics.add(
            MapEntry(topicTitle, winningNotesForTopic.length),
          );
          _topicNoteIdsCache[topicTitle] = winningNotesForTopic
              .map((e) => e.key)
              .toList();
        }
      }

      // Cache top qualified topic matches and their corresponding note IDs sorted by similarity score.
      qualifiedTopics.sort((a, b) => b.value.compareTo(a.value));
      _cachedTopics = qualifiedTopics.take(maxTopics).toList();
      return _cachedTopics!;
    } catch (e) {
      debugPrint('TopicDiscoveryService: Discovery error: $e');
      return [];
    }
  }

  /// Retrieves note IDs matching a specific topic string, filtered by optional date boundaries.
  static Future<List<String>> getNoteIdsForTopic(
    String topicTitle, {
    DateTime? start,
    DateTime? end,
    double minSimilarity = 0.32,
  }) async {
    if (start == null && end == null) {
      final cachedIds = _topicNoteIdsCache[topicTitle];
      if (cachedIds != null && cachedIds.isNotEmpty) return cachedIds;
    }

    if (!await OnnxEmbeddingEngine.isModelAvailable()) return [];
    await OnnxEmbeddingEngine.init();

    try {
      final topicDescription = _candidateTaxonomy[topicTitle];
      if (topicDescription == null) return [];

      final topicVector = await _getOrComputeTopicVector(
        topicTitle,
        topicDescription,
      );
      if (topicVector == null) return [];

      final candidates = await VectorStorageService.to.fetchAllEmbeddings(
        start: start,
        end: end,
      );

      final Map<String, double> noteBestScores = {};

      for (final entry in candidates) {
        final noteId = entry['note_id'] as String;
        final blob = entry['embedding'] as Uint8List;
        final chunkVector = Uint8List.fromList(blob).buffer.asFloat32List();

        final chunkScore = VectorMath.cosineSimilarity(
          topicVector,
          chunkVector,
        );
        if (chunkScore >= minSimilarity) {
          final currentBestScore = noteBestScores[noteId] ?? 0.0;
          if (chunkScore > currentBestScore) {
            noteBestScores[noteId] = chunkScore;
          }
        }
      }

      final sorted = noteBestScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final resultIds = sorted.map((e) => e.key).toList();

      if (start == null && end == null && resultIds.isNotEmpty) {
        _topicNoteIdsCache[topicTitle] = resultIds;
      }
      return resultIds;
    } catch (e) {
      debugPrint('TopicDiscoveryService: getNoteIdsForTopic error: $e');
      return [];
    }
  }
}
