import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/tafseer_embedding.dart';

class SemanticSearchService {
  static final SemanticSearchService _instance =
      SemanticSearchService._internal();
  factory SemanticSearchService() => _instance;
  SemanticSearchService._internal();

  List<TafseerEmbedding>? _embeddings;
  bool _isLoading = false;
  bool _isLoaded = false;

  /// Check if embeddings are loaded
  bool get isLoaded => _isLoaded;

  /// Load embeddings from assets
  Future<void> loadEmbeddings() async {
    if (_isLoaded || _isLoading) return;

    _isLoading = true;
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/embeddings/tafseer_embeddings.json',
      );
      final List<dynamic> jsonList = json.decode(jsonString);

      _embeddings = jsonList
          .map((json) => TafseerEmbedding.fromJson(json))
          .toList();
      _isLoaded = true;
      print('Loaded ${_embeddings!.length} Tafseer embeddings');
    } catch (e) {
      print('Error loading embeddings: $e');
      _embeddings = [];
      _isLoaded = false;
    } finally {
      _isLoading = false;
    }
  }

  /// Search using keyword matching (fallback when no query embedding)
  Future<List<SearchResult>> searchByKeywords(
    String query, {
    int maxResults = 20,
  }) async {
    if (!_isLoaded) {
      await loadEmbeddings();
    }

    if (_embeddings == null || _embeddings!.isEmpty) {
      return [];
    }

    final keywords = query
        .toLowerCase()
        .split(' ')
        .where((w) => w.length > 2)
        .toList();
    if (keywords.isEmpty) return [];

    final results = <SearchResult>[];

    for (final entry in _embeddings!) {
      final textLower = entry.text.toLowerCase();

      // Count keyword matches
      int matches = 0;
      for (final keyword in keywords) {
        if (textLower.contains(keyword)) {
          matches++;
        }
      }

      if (matches > 0) {
        // Simple scoring: percentage of keywords matched
        final score = matches / keywords.length;
        results.add(SearchResult(entry: entry, similarity: score));
      }
    }

    // Sort by similarity (descending)
    results.sort((a, b) => b.similarity.compareTo(a.similarity));

    return results.take(maxResults).toList();
  }

  /// Search using semantic similarity (requires query embedding)
  Future<List<SearchResult>> searchBySemantic(
    List<double> queryEmbedding, {
    int maxResults = 20,
    double minSimilarity = 0.3,
  }) async {
    if (!_isLoaded) {
      await loadEmbeddings();
    }

    if (_embeddings == null || _embeddings!.isEmpty) {
      return [];
    }

    final results = <SearchResult>[];

    for (final entry in _embeddings!) {
      final similarity = entry.cosineSimilarity(queryEmbedding);

      if (similarity >= minSimilarity) {
        results.add(SearchResult(entry: entry, similarity: similarity));
      }
    }

    // Sort by similarity (descending)
    results.sort((a, b) => b.similarity.compareTo(a.similarity));

    return results.take(maxResults).toList();
  }

  /// Get embedding by surah and ayah
  TafseerEmbedding? getEmbedding(int surah, int ayah) {
    if (_embeddings == null) return null;

    try {
      return _embeddings!.firstWhere((e) => e.surah == surah && e.ayah == ayah);
    } catch (e) {
      return null;
    }
  }

  /// Get total number of loaded embeddings
  int get embeddingsCount => _embeddings?.length ?? 0;
}
