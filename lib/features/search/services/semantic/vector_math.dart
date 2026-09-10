import 'dart:math' as math;
import 'dart:typed_data';

/// Provides low-level vector operations including mean pooling, L2 unit normalization, and dot-product cosine similarity.
class VectorMath {
  /// Computes mean vector pooling across sequence embeddings, ignoring padded tokens (mask == 0).
  static List<double> meanPool(
    List<List<double>> sequenceEmbeddings,
    List<int> mask,
  ) {
    if (sequenceEmbeddings.isEmpty || mask.isEmpty) return [];

    final dim = sequenceEmbeddings[0].length;
    final result = List<double>.filled(dim, 0.0);
    int activeCount = 0;
    final limit = math.min(sequenceEmbeddings.length, mask.length);

    // Sum token vectors for non-padding tokens (attention_mask == 1) and divide by active token count.
    for (var j = 0; j < limit; j++) {
      if (mask[j] == 0) continue;
      activeCount++;
      final tokenVector = sequenceEmbeddings[j];
      for (var i = 0; i < dim; i++) {
        result[i] += tokenVector[i];
      }
    }

    if (activeCount > 0) {
      final invCount = 1.0 / activeCount;
      for (var i = 0; i < dim; i++) {
        result[i] *= invCount;
      }
    }
    return result;
  }

  /// Projects vector onto unit sphere (L2 norm = 1.0) so cosine similarity equals a fast dot product.
  static Float32List normalize(List<double> vector) {
    if (vector.isEmpty) return Float32List(0);

    double sumSq = 0.0;
    for (var i = 0; i < vector.length; i++) {
      final val = vector[i];
      sumSq += val * val;
    }

    final norm = math.sqrt(sumSq);
    if (norm < 1e-10) return Float32List.fromList(vector);

    final result = Float32List(vector.length);
    final invNorm = 1.0 / norm;
    for (int i = 0; i < vector.length; i++) {
      result[i] = vector[i] * invNorm;
    }
    return result;
  }

  /// Calculates dot-product cosine similarity between two unit-normalized Float32List vectors.
  static double cosineSimilarity(Float32List a, Float32List b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    double dotProduct = 0.0;
    final len = math.min(a.length, b.length);
    for (int i = 0; i < len; i++) {
      dotProduct += a[i] * b[i];
    }
    return dotProduct;
  }
}
