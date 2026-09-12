/// Splits document text into overlapping character chunks fitting safely within BERT token sequence limits.
class TextChunker {
  /// Breaks [text] into sliding character windows bounded by [maxChunkChars], sharing [overlapChars] across chunks.
  /// Scaled up to 1500 chars (~375 tokens) to fully utilize BGE's 512-token context window.
  static List<String> chunkText(
    String text, {
    int maxChunkChars = 1500,
    int minChunkChars = 30,
    int overlapChars = 150, // preserves wider semantic continuity
  }) {
    final normalized = text.toLowerCase().trim();
    if (normalized.isEmpty) return [];

    // Split raw text across paragraph/line breaks.
    final rawBlocks = normalized
        .split(RegExp(r'\n+'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();

    final List<String> chunks = [];
    var currentChunk = StringBuffer();

    for (final block in rawBlocks) {
      if (currentChunk.length + block.length + 1 <= maxChunkChars) {
        if (currentChunk.isNotEmpty) currentChunk.write(' ');
        currentChunk.write(block);
      } else {
        if (currentChunk.isNotEmpty) {
          final currentStr = currentChunk.toString();
          chunks.add(currentStr);
          currentChunk.clear();

          // Seed next chunk with trailing overlap text from preceding chunk to preserve semantic continuity across breaks.
          if (currentStr.length > overlapChars) {
            currentChunk.write(
              currentStr.substring(currentStr.length - overlapChars).trim(),
            );
            currentChunk.write(' ');
          }
        }

        // Handle single paragraph blocks exceeding maxChunkChars by splitting across word boundaries.
        if (block.length > maxChunkChars) {
          final words = block.split(RegExp(r'\s+'));
          for (final word in words) {
            if (currentChunk.length + word.length + 1 > maxChunkChars) {
              if (currentChunk.isNotEmpty) chunks.add(currentChunk.toString());
              currentChunk.clear();
            }
            if (currentChunk.isNotEmpty) currentChunk.write(' ');
            currentChunk.write(word);
          }
        } else {
          currentChunk.write(block);
        }
      }
    }

    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk.toString());
    }

    final filtered = chunks.where((c) => c.length >= minChunkChars).toList();
    return filtered.isNotEmpty ? filtered : [normalized];
  }
}
