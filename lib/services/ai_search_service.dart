import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/tafseer_embedding.dart';
import 'database_service.dart';

class AiSearchResponse {
  final String answer;
  final List<SearchResult> results;
  const AiSearchResponse({required this.answer, required this.results});
}

class AiSearchService {
  static final AiSearchService _instance = AiSearchService._internal();
  factory AiSearchService() => _instance;
  AiSearchService._internal();

  final DatabaseService _dbService = DatabaseService();

  /// Clean Markdown wrappers from JSON string returned by LLMs
  String _cleanJsonResponse(String text) {
    text = text.trim();
    if (text.startsWith('```json')) {
      text = text.substring(7);
    } else if (text.startsWith('```')) {
      text = text.substring(3);
    }
    if (text.endsWith('```')) {
      text = text.substring(0, text.length - 3);
    }
    return text.trim();
  }

  /// Extract JSON object safely from a potentially conversational model response
  Map<String, dynamic>? _extractJsonObject(String text) {
    try {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        final jsonStr = text.substring(start, end + 1);
        return jsonDecode(jsonStr) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[AiSearch] Error parsing extracted JSON range: $e');
    }
    try {
      final cleaned = _cleanJsonResponse(text);
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[AiSearch] Direct jsonDecode failed: $e');
    }
    return null;
  }

  /// Perform AI contextual search using Groq or Cohere
  Future<AiSearchResponse> search({
    required String query,
    required String provider,
    required String model,
    required String apiKey,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw ArgumentError('API key is empty');
    }

    final systemPrompt = """
You are an expert Quranic scholar and AI assistant.

Your task is to answer the user's query using relevant Quran verses and return a structured JSON response with exactly two keys:

1. "answer": A fluent, insightful 3-6 sentence response that directly addresses the query. Within the answer, embed verse references INLINE using ONLY the format [surah:ayah] — for example [2:153] or [94:5]. Every verse you reference must also appear in "results".

2. "results": A list of all verses referenced in "answer", sorted from MOST to LEAST relevant. Each item must have:
   - "surah": integer (1–114)
   - "ayah": integer (1-indexed)
   - "explanation": 1-2 sentences on how this verse specifically relates to the query.

Strict rules:
- Only reference verses that genuinely exist in the Quran.
- Only include verses that are truly relevant — no padding.
- Use ONLY the format [surah:ayah] for inline references — no ranges, no surah names, no other bracket formats.
- Return pure JSON only — no markdown, no code fences, no conversational text outside the JSON.

Example:
{
  "answer": "Islam teaches that hardship is a test and a path to closeness with Allah. Believers are urged to seek help through patience and prayer [2:153], and are reassured that Allah is with those who persevere [2:286]. Every difficulty is balanced by ease [94:5], making patience the cornerstone of a believer's response to trial.",
  "results": [
    {"surah": 2, "ayah": 153, "explanation": "Commands believers to seek help through patience and prayer during hardship."},
    {"surah": 2, "ayah": 286, "explanation": "Assures that Allah does not burden a soul beyond what it can bear."},
    {"surah": 94, "ayah": 5, "explanation": "Promises that with every hardship comes ease — a direct comfort for those in difficulty."}
  ]
}
""";

    String responseText = '';

    if (provider == 'groq') {
      responseText = await _callGroq(
        query: query,
        model: model,
        apiKey: apiKey,
        systemPrompt: systemPrompt,
      );
    } else if (provider == 'cohere') {
      responseText = await _callCohere(
        query: query,
        model: model,
        apiKey: apiKey,
        systemPrompt: systemPrompt,
      );
    } else {
      throw UnsupportedError('Unknown search provider: $provider');
    }

    debugPrint('[AiSearch] Raw response from AI: $responseText');

    final jsonMap = _extractJsonObject(responseText);
    if (jsonMap == null || jsonMap['results'] is! List) {
      debugPrint('[AiSearch] Failed to extract results from JSON response');
      return AiSearchResponse(answer: '', results: []);
    }

    final String answer = (jsonMap['answer'] as String?) ?? '';
    final List<dynamic> resultsList = jsonMap['results'] as List;
    final List<Map<String, int>> references = [];
    final List<Map<String, dynamic>> rawResults = [];

    for (final item in resultsList) {
      if (item is Map && item.containsKey('surah') && item.containsKey('ayah')) {
        final surahVal = int.tryParse(item['surah'].toString());
        final ayahVal = int.tryParse(item['ayah'].toString());
        if (surahVal != null && ayahVal != null) {
          references.add({'surah': surahVal, 'ayah': ayahVal});
          rawResults.add({
            'surah': surahVal,
            'ayah': ayahVal,
            'explanation': item['explanation']?.toString() ?? '',
          });
        }
      }
    }

    if (references.isEmpty) return AiSearchResponse(answer: answer, results: []);

    // Hydrate verses with full translation text from database
    final translations = await _dbService.getBulkTranslations(references);

    final List<SearchResult> searchResults = [];
    for (int i = 0; i < rawResults.length; i++) {
      final ref = rawResults[i];
      final int surah = ref['surah'];
      final int ayah = ref['ayah'];
      final String explanation = ref['explanation'];
      final String key = '${surah}_$ayah';
      final String text = translations[key] ?? '';

      searchResults.add(
        SearchResult(
          entry: TafseerEmbedding(
            id: -1,
            surah: surah,
            ayah: ayah,
            verseKey: '$surah:$ayah',
            text: text,
            embedding: [],
          ),
          similarity: 1.0 - (i * 0.01),
          explanation: explanation,
          translation: text,
        ),
      );
    }

    return AiSearchResponse(answer: answer, results: searchResults);
  }

  /// Call Groq Chat Completions API
  Future<String> _callGroq({
    required String query,
    required String model,
    required String apiKey,
    required String systemPrompt,
  }) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': query}
        ],
        'temperature': 0.2,
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode != 200) {
      throw http.ClientException(
        'Groq API returned status ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] as String;
  }

  /// Call Cohere Chat API (v2)
  Future<String> _callCohere({
    required String query,
    required String model,
    required String apiKey,
    required String systemPrompt,
  }) async {
    final url = Uri.parse('https://api.cohere.com/v2/chat');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'X-Client-Name': 'quran-flutter-app',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': query},
        ],
      }),
    );

    debugPrint('[AiSearch] Cohere status: ${response.statusCode}');

    if (response.statusCode != 200) {
      throw http.ClientException(
        'Cohere API returned status ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // v2 response: { "message": { "content": [ { "type": "text", "text": "..." } ] } }
    final message = data['message'];
    if (message is Map) {
      final content = message['content'];
      if (content is List && content.isNotEmpty) {
        final first = content.first;
        if (first is Map && first['type'] == 'text') {
          return first['text'] as String;
        }
        // Some versions return plain string content items
        if (first is String) return first;
      }
    }

    // Fallback: look for top-level "text" key (older v2 variants)
    if (data.containsKey('text')) {
      return data['text'] as String;
    }

    throw http.ClientException(
      'Cohere v2: unexpected response shape — could not extract text. Body: ${response.body}',
    );
  }
}
