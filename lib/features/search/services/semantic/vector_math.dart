import 'dart:math' as math;
import 'dart:typed_data';

/// Low-level vector operations: L2 normalization, and cosine similarity.
class VectorMath {
  /// Scales a vector to unit length (L2 norm = 1.0).
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

  /// Computes dot-product cosine similarity between two unit-normalized vectors.
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
