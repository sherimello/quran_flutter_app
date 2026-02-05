import 'dart:math';

class TafseerEmbedding {
  final int id;
  final int surah;
  final int ayah;
  final String verseKey;
  final String text;
  final List<double> embedding;

  TafseerEmbedding({
    required this.id,
    required this.surah,
    required this.ayah,
    required this.verseKey,
    required this.text,
    required this.embedding,
  });

  factory TafseerEmbedding.fromJson(Map<String, dynamic> json) {
    return TafseerEmbedding(
      id: json['id'] as int,
      surah: json['surah'] as int,
      ayah: json['ayah'] as int,
      verseKey: json['verse_key'] as String,
      text: json['text'] as String,
      embedding: (json['embedding'] as List)
          .map((e) => (e as num).toDouble())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'surah': surah,
      'ayah': ayah,
      'verse_key': verseKey,
      'text': text,
      'embedding': embedding,
    };
  }

  /// Calculate cosine similarity with another embedding
  double cosineSimilarity(List<double> otherEmbedding) {
    if (embedding.length != otherEmbedding.length) {
      throw ArgumentError('Embeddings must have the same dimension');
    }

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < embedding.length; i++) {
      dotProduct += embedding[i] * otherEmbedding[i];
      normA += embedding[i] * embedding[i];
      normB += otherEmbedding[i] * otherEmbedding[i];
    }

    if (normA == 0.0 || normB == 0.0) {
      return 0.0;
    }

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Get a short snippet of the text (first 150 characters)
  String get snippet {
    if (text.length <= 150) return text;
    return '${text.substring(0, 147)}...';
  }
}

class SearchResult {
  final TafseerEmbedding entry;
  final double similarity;

  SearchResult({required this.entry, required this.similarity});

  int get surah => entry.surah;
  int get ayah => entry.ayah;
  String get verseKey => entry.verseKey;
  String get text => entry.text;
  String get snippet => entry.snippet;
}
