import 'package:flutter/foundation.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/core/database/vector_storage.dart';

import 'onnx_embedding_engine.dart';
import 'semantic_taxonomy.dart';
import 'vector_math.dart';

class _DiscoveryComputationResult {
  final List<MapEntry<String, int>> qualifiedTopics;
  final Map<String, List<String>> topicNoteIds;

  _DiscoveryComputationResult({
    required this.qualifiedTopics,
    required this.topicNoteIds,
  });
}

/// Evaluates topic scores and applies winner-take-all filtering synchronously.
_DiscoveryComputationResult _evaluateTopics({
  required Map<String, Float32List> topicVectors,
  required List<Map<String, dynamic>> parsedEntries,
  required double minSimilarity,
  required int? maxTopics,
}) {
  final rawTopicNoteScores = <String, Map<String, double>>{};
  final noteGlobalBestScore = <String, double>{};
  final noteWinningTopic = <String, String>{};

  for (final entry in topicVectors.entries) {
    final topicTitle = entry.key;
    final topicVector = entry.value;
    final noteScores = <String, double>{};

    for (final note in parsedEntries) {
      final noteId = note['note_id'] as String;
      final chunkVector = note['vector'] as Float32List;

      final chunkScore = VectorMath.cosineSimilarity(topicVector, chunkVector);
      if (chunkScore >= minSimilarity) {
        final currentBest = noteScores[noteId] ?? 0.0;
        if (chunkScore > currentBest) {
          noteScores[noteId] = chunkScore;
        }
      }
    }

    if (noteScores.isNotEmpty) {
      rawTopicNoteScores[topicTitle] = noteScores;
      for (final e in noteScores.entries) {
        final currentMax = noteGlobalBestScore[e.key] ?? 0.0;
        if (e.value > currentMax) {
          noteGlobalBestScore[e.key] = e.value;
          noteWinningTopic[e.key] = topicTitle;
        }
      }
    }
  }

  final qualifiedTopics = <MapEntry<String, int>>[];
  final topicNoteIds = <String, List<String>>{};

  for (final entry in rawTopicNoteScores.entries) {
    final topicTitle = entry.key;
    final noteScores = entry.value;

    final winningNotes =
        noteScores.entries
            .where((e) => noteWinningTopic[e.key] == topicTitle)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    if (winningNotes.isNotEmpty) {
      qualifiedTopics.add(MapEntry(topicTitle, winningNotes.length));
      topicNoteIds[topicTitle] = winningNotes.map((e) => e.key).toList();
    }
  }

  qualifiedTopics.sort((a, b) => b.value.compareTo(a.value));
  return _DiscoveryComputationResult(
    qualifiedTopics: maxTopics != null
        ? qualifiedTopics.take(maxTopics).toList()
        : qualifiedTopics,
    topicNoteIds: topicNoteIds,
  );
}

/// Discovers candidate taxonomy topics and matches notes against topic vector embeddings using BGE v1.5 queries.
class TopicDiscoveryService {
  static List<MapEntry<String, int>>? _discoveredTopicChips;
  static final Map<String, List<String>> _topicMatchedNoteIds = {};

  static final Map<String, String> _candidateTaxonomy =
      SemanticTaxonomy.topicDescriptions;

  static final ValueNotifier<int> cacheRevision = ValueNotifier<int>(0);

  // BGE v1.5 official instruction prefix required to align asymmetric query/document vector spaces.
  static const String _bgeQueryPrefix =
      'Represent this sentence for searching relevant passages: ';

  /// Clears in-memory topic suggestion and note ID caches.
  static void invalidateCache() {
    _discoveredTopicChips = null;
    _topicMatchedNoteIds.clear();

    //Trigger the Search UI to refresh its chips
    cacheRevision.value++;
  }

  /// Computes a single topic vector using ONNX and writes it directly to SQLite.
  static Future<Float32List?> _computeAndSaveTopicVector(
    String topicTitle,
    String description,
  ) async {
    final queryText = '$_bgeQueryPrefix$description';
    final vecs = await OnnxEmbeddingEngine.generateDocumentEmbeddings(
      queryText,
    );
    if (vecs.isNotEmpty) {
      final topicVector = vecs.first;
      await VectorStorageService.to.saveTaxonomyVector(
        topicTitle,
        topicVector.buffer.asUint8List(),
      );
      return topicVector;
    }
    return null;
  }

  /// Loads taxonomy vectors directly from SQLite, computing any missing ones sequentially.
  static Future<Map<String, Float32List>> _loadTaxonomyVectorsFromDb() async {
    final storedTaxonomy = await VectorStorageService.to
        .fetchAllTaxonomyVectors();

    final result = <String, Float32List>{
      for (final entry in storedTaxonomy.entries)
        entry.key: entry.value.buffer.asFloat32List(),
    };

    final missingEntries = _candidateTaxonomy.entries
        .where((e) => !result.containsKey(e.key))
        .toList();

    if (missingEntries.isNotEmpty) {
      for (final entry in missingEntries) {
        final vec = await _computeAndSaveTopicVector(entry.key, entry.value);
        if (vec != null) {
          result[entry.key] = vec;
        }
      }
    }

    return result;
  }

  /// Evaluates candidate topics against active note vector embeddings and returns top qualified topic matches.
  static Future<List<MapEntry<String, int>>> discoverSuggestedTopics({
    required List<String> activeNoteIds,
    int? maxTopics,
    double minSimilarity = 0.45,
  }) async {
    if (_discoveredTopicChips != null && _discoveredTopicChips!.isNotEmpty) {
      return _discoveredTopicChips!;
    }
    if (!await OnnxEmbeddingEngine.isModelAvailable()) return [];
    await OnnxEmbeddingEngine.init();

    try {
      // 1. Fetch only active note vectors directly from the SQLite index.
      final activeEmbeddings = await VectorStorageService.to.fetchAllEmbeddings(
        noteIds: activeNoteIds,
      );
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

      // 2. Load taxonomy vectors from SQLite
      final topicVectors = await _loadTaxonomyVectorsFromDb();

      // 3. Perform vector dot-product scoring and winner-take-all evaluation synchronously
      final result = _evaluateTopics(
        topicVectors: topicVectors,
        parsedEntries: parsedEntries,
        minSimilarity: minSimilarity,
        maxTopics: maxTopics,
      );

      _topicMatchedNoteIds
        ..clear()
        ..addAll(result.topicNoteIds);

      _discoveredTopicChips = result.qualifiedTopics;
      return _discoveredTopicChips!;
    } catch (e) {
      debugPrint('TopicDiscoveryService: Discovery error: $e');
      return [];
    }
  }

  /// Retrieves note IDs matching a specific topic
  static Future<List<String>> getNoteIdsForTopic(
    String topicTitle, {
    double minSimilarity = 0.45,
  }) async {
    // 1. Force Winner-Take-All recalculation
    if (_topicMatchedNoteIds.isEmpty) {
      final activeIds = noteRepository.activeNotes.map((n) => n.id).toList();
      await discoverSuggestedTopics(
        activeNoteIds: activeIds,
        minSimilarity: minSimilarity,
      );
    }

    // 2. Return winning IDs directly
    return _topicMatchedNoteIds[topicTitle] ?? [];
  }

  /// Pre-computes and caches taxonomy embeddings in SQLite
  static Future<void> warmupTaxonomyVectors() async {
    if (!await OnnxEmbeddingEngine.isModelAvailable()) return;
    await OnnxEmbeddingEngine.init();

    try {
      await _loadTaxonomyVectorsFromDb();
    } catch (e) {
      debugPrint('TopicDiscoveryService: Warmup error: $e');
    }
  }
}
