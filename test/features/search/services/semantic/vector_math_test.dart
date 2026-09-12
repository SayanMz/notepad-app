import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/search/services/semantic/vector_math.dart';

void main() {
  group('VectorMath', () {
    test('normalize projects vector onto unit sphere (L2 norm = 1.0)', () {
      final vector = [3.0, 4.0];
      final normalized = VectorMath.normalize(vector);

      // Magnitude of [3.0, 4.0] is 5.0, so normalized is [0.6, 0.8]
      expect(normalized[0], closeTo(0.6, 1e-5));
      expect(normalized[1], closeTo(0.8, 1e-5));
    });

    test('cosineSimilarity calculates exact dot product of normalized vectors', () {
      final vecA = Float32List.fromList([1.0, 0.0, 0.0]);
      final vecB = Float32List.fromList([1.0, 0.0, 0.0]);
      final vecC = Float32List.fromList([0.0, 1.0, 0.0]);

      expect(VectorMath.cosineSimilarity(vecA, vecB), closeTo(1.0, 1e-5));
      expect(VectorMath.cosineSimilarity(vecA, vecC), closeTo(0.0, 1e-5));
    });
  });
}
