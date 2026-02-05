import 'dart:typed_data';

/// Optimized model for search comparisons (no text, minimal memory)
class LightweightEmbedding {
  final int id;
  final int surah;
  final int ayah;
  final List<double> embedding;

  LightweightEmbedding({
    required this.id,
    required this.surah,
    required this.ayah,
    required this.embedding,
  });

  /// Calculate cosine similarity with query vector
  double cosineSimilarity(List<double> queryVector) {
    if (embedding.length != queryVector.length) return 0.0;

    double dotProduct = 0.0;
    // We assume both vectors are already normalized for performance!
    // If not, we still compute dot product which correlates with cosine similarity
    for (int i = 0; i < embedding.length; i++) {
      dotProduct += embedding[i] * queryVector[i];
    }
    return dotProduct;
  }
}

/// Binary file reader
class EmbeddingLoader {
  static List<LightweightEmbedding> parseBinary(Uint8List bytes) {
    final buffer = bytes.buffer;
    var offset = 0;

    final view = ByteData.view(buffer);

    // Read Header
    // "TAF1" -> 0x54414631
    // Check magic (flexible)
    if (bytes[0] != 84 || bytes[1] != 65 || bytes[2] != 70 || bytes[3] != 49) {
      throw Exception('Invalid magic bytes');
    }
    offset += 4;

    final count = view.getUint32(offset, Endian.little);
    offset += 4;

    final dim = view.getUint32(offset, Endian.little);
    offset += 4;

    print('Loading binary embeddings: Count=$count, Dim=$dim');

    final embeddings = <LightweightEmbedding>[];
    embeddings.length = count; // Pre-allocate

    for (int i = 0; i < count; i++) {
      final id = view.getUint16(offset, Endian.little);
      offset += 2;

      final surah = view.getUint8(offset);
      offset += 1;

      final ayah = view.getUint16(offset, Endian.little);
      offset += 2;

      final vector = List<double>.filled(dim, 0.0);
      for (int j = 0; j < dim; j++) {
        vector[j] = view.getFloat32(offset, Endian.little);
        offset += 4;
      }

      embeddings[i] = LightweightEmbedding(
        id: id,
        surah: surah,
        ayah: ayah,
        embedding: vector,
      );
    }

    return embeddings;
  }
}
