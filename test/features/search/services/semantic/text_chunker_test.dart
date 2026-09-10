import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/search/services/semantic/text_chunker.dart';

void main() {
  group('TextChunker', () {
    test('chunkText returns empty list for empty or whitespace string', () {
      expect(TextChunker.chunkText(''), isEmpty);
      expect(TextChunker.chunkText('   \n  '), isEmpty);
    });

    test('chunkText breaks long document into sliding character chunks', () {
      final longText = '''
First paragraph discussing software architecture and microservices design patterns.
Second paragraph detailing database indexing strategies and query optimization techniques in SQLite.
Third paragraph explaining local neural network vector embedding generation using ONNX runtime and BERT tokenization.
''';

      final chunks = TextChunker.chunkText(
        longText,
        maxChunkChars: 120,
        minChunkChars: 20,
        overlapChars: 30,
      );

      expect(chunks, isNotEmpty);
      expect(chunks.length, greaterThan(1));
      expect(chunks.every((c) => c.length >= 20), isTrue);
    });

    test('chunkText handles single long block exceeding maxChunkChars', () {
      final singleLongWordBlock =
          'word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12 word13 word14 word15 word16 word17 word18 word19 word20';

      final chunks = TextChunker.chunkText(
        singleLongWordBlock,
        maxChunkChars: 50,
        minChunkChars: 10,
        overlapChars: 15,
      );

      expect(chunks, isNotEmpty);
      expect(chunks.length, greaterThan(1));
    });
  });
}
