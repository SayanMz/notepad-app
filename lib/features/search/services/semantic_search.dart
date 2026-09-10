import 'dart:typed_data';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/features/search/services/semantic/onnx_embedding_engine.dart';
import 'package:notepad/features/search/services/semantic/semantic_maintenance.dart';
import 'package:notepad/features/search/services/semantic/topic_discovery_service.dart';
import 'package:notepad/features/search/services/semantic/vector_math.dart';

/// Facade exposing on-device semantic vector generation, ONNX inference, maintenance indexing, topic discovery, and vector math operations.
class SemanticSearchService {
  static void invalidateTopicCache() => TopicDiscoveryService.invalidateCache();
  static Future<bool> isModelAvailable() =>
      OnnxEmbeddingEngine.isModelAvailable();
  static Future<void> init() => OnnxEmbeddingEngine.init();

  static Future<List<Float32List>> generateDocumentEmbeddings(String text) =>
      OnnxEmbeddingEngine.generateDocumentEmbeddings(text);

  static Future<void> runMaintenanceSweep([List<dynamic>? notesList]) =>
      SemanticMaintenanceService.runMaintenanceSweep(notesList);

  static Future<void> embedNoteInBackground(NotesSection note) =>
      SemanticMaintenanceService.embedNoteInBackground(note);

  static Future<List<MapEntry<String, int>>> discoverSuggestedTopics({
    required Set<String> activeNoteIds,
    int maxTopics = 6,
    double minSimilarity = 0.32,
  }) => TopicDiscoveryService.discoverSuggestedTopics(
    activeNoteIds: activeNoteIds,
    maxTopics: maxTopics,
    minSimilarity: minSimilarity,
  );

  static Future<List<String>> getNoteIdsForTopic(
    String topic, {
    DateTime? start,
    DateTime? end,
    double minSimilarity = 0.32,
  }) => TopicDiscoveryService.getNoteIdsForTopic(
    topic,
    start: start,
    end: end,
    minSimilarity: minSimilarity,
  );

  static double computeCosineSimilarity(Float32List a, Float32List b) =>
      VectorMath.cosineSimilarity(a, b);
}
