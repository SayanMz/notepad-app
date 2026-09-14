import 'package:flutter/foundation.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/features/search/services/semantic/onnx_embedding_engine.dart';
import 'package:notepad/features/search/services/semantic/semantic_maintenance.dart';
import 'package:notepad/features/search/services/semantic/topic_discovery_service.dart';
import 'package:notepad/features/search/services/semantic/vector_math.dart';

/// Facade exposing on-device semantic vector generation, ONNX inference, maintenance indexing, topic discovery, and vector math operations.
class SemanticSearchService {
  static void invalidateTopicCache() => TopicDiscoveryService.invalidateCache();
  static ValueListenable<int> get cacheRevision =>
      TopicDiscoveryService.cacheRevision;

  static Future<void> init() => OnnxEmbeddingEngine.init();
  static Future<bool> isModelAvailable() =>
      OnnxEmbeddingEngine.isModelAvailable();

  static Future<void> runMaintenanceSweep([List<dynamic>? notesList]) =>
      SemanticMaintenanceService.runMaintenanceSweep(notesList);
  static Future<void> warmupTaxonomyVectors() =>
      TopicDiscoveryService.warmupTaxonomyVectors();

  static Future<void> embedNoteInBackground(NotesSection note) =>
      SemanticMaintenanceService.embedNoteInBackground(note);

  static Future<List<MapEntry<String, int>>> discoverSuggestedTopics({
    required List<String> activeNoteIds,
  }) => TopicDiscoveryService.discoverSuggestedTopics(
    activeNoteIds: activeNoteIds,
  );
  static Future<List<String>> getNoteIdsForTopic(String topic) =>
      TopicDiscoveryService.getNoteIdsForTopic(topic);

  static double computeCosineSimilarity(Float32List a, Float32List b) =>
      VectorMath.cosineSimilarity(a, b);
}
