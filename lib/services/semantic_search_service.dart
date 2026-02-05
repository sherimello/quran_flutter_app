import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/tafseer_embedding.dart';
import '../models/lightweight_embedding.dart';
import 'onnx_bert_service.dart';
import 'database_service.dart';

class SemanticSearchService {
  static final SemanticSearchService _instance =
      SemanticSearchService._internal();
  factory SemanticSearchService() => _instance;
  SemanticSearchService._internal();

  List<LightweightEmbedding>? _embeddings;
  final OnnxBertService _bertService = OnnxBertService();
  bool _isLoading = false;
  bool _isLoaded = false;

  /// Check if embeddings are loaded
  bool get isLoaded => _isLoaded;

  /// Check if BERT model is loaded
  bool get modelLoaded => _bertService.isLoaded;

  /// Load binary embeddings
  Future<void> loadEmbeddings() async {
    if (_isLoaded || _isLoading) return;

    _isLoading = true;
    try {
      final byteData = await rootBundle.load(
        'assets/embeddings/tafseer_embeddings.bin',
      );
      final bytes = byteData.buffer.asUint8List();

      _embeddings = EmbeddingLoader.parseBinary(bytes);
      _isLoaded = true;
      print('Loaded ${_embeddings!.length} embeddings from binary');
    } catch (e) {
      print('Error loading binary embeddings: $e');
      _embeddings = [];
      _isLoaded = false;
    } finally {
      _isLoading = false;
    }
  }

  /// Initialize the BERT model
  Future<bool> initializeBert() async {
    return await _bertService.initialize();
  }

  /// Search using semantic similarity with BERT embeddings
  Future<List<SearchResult>> search(
    String query, {
    int maxResults = 20,
    double minSimilarity = 0.3,
  }) async {
    if (!_isLoaded) {
      await loadEmbeddings();
    }

    // 1. Get query embedding (Semantic) OR null (Keyword fallback)
    List<double>? queryEmbedding;

    // Try BERT first
    if (_bertService.isLoaded || await _bertService.initialize()) {
      queryEmbedding = await _bertService.embed(query);
    }

    if (queryEmbedding != null) {
      print('Using BERT semantic search for: "$query"');
      return _performSemanticSearch(queryEmbedding, maxResults, minSimilarity);
    } else {
      print('Using keyword search (fallback) for: "$query"');
      return _performKeywordSearchDb(query, maxResults);
    }
  }

  /// Perform semantic search using in-memory embeddings
  Future<List<SearchResult>> _performSemanticSearch(
    List<double> queryEmbedding,
    int maxResults,
    double minSimilarity,
  ) async {
    if (_embeddings == null || _embeddings!.isEmpty) return [];

    // 1. Compute scores
    final scored = <_ScoredEntry>[];
    for (final entry in _embeddings!) {
      final score = entry.cosineSimilarity(queryEmbedding);
      if (score >= minSimilarity) {
        scored.add(_ScoredEntry(entry, score));
      }
    }

    // 2. Sort top N
    scored.sort((a, b) => b.score.compareTo(a.score));
    final topResults = scored.take(maxResults).toList();

    if (topResults.isEmpty) return [];

    // 3. Hydrate with text from DB
    final ids = topResults.map((e) => e.entry.id).toList();
    final dbData = await DatabaseService().getTafseerByIds(ids);

    // 4. Map back to SearchResults
    final results = <SearchResult>[];
    for (final item in topResults) {
      final data = dbData[item.entry.id];
      if (data != null) {
        results.add(
          SearchResult(
            entry: TafseerEmbedding(
              id: item.entry.id,
              surah: item.entry.surah,
              ayah: item.entry.ayah,
              verseKey: data['verse_key'] as String,
              text: data['text'] as String,
              embedding: [], // Don't need to pass back to UI
            ),
            similarity: item.score,
          ),
        );
      }
    }

    return results;
  }

  /// Perform keyword search using SQLite fallback
  Future<List<SearchResult>> _performKeywordSearchDb(
    String query,
    int maxResults,
  ) async {
    final results = await DatabaseService().searchTafseerKeywords(query);

    return results
        .map(
          (data) => SearchResult(
            entry: TafseerEmbedding(
              id: data['id'] as int,
              surah: data['surah'] as int,
              ayah: data['ayah'] as int,
              verseKey: data['verse_key'] as String,
              text: data['text'] as String,
              embedding: [],
            ),
            similarity: 1.0, // Exact match
          ),
        )
        .toList();
  }

  void dispose() {
    _bertService.dispose();
  }
}

class _ScoredEntry {
  final LightweightEmbedding entry;
  final double score;
  _ScoredEntry(this.entry, this.score);
}
