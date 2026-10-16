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

  static const Map<String, String> defaultGroqModels = {
    'llama-3.3-70b-versatile': 'LLaMA 3.3 70B Versatile',
    'llama-3.1-8b-instant': 'LLaMA 3.1 8B Instant',
    'llama-3.2-3b-preview': 'LLaMA 3.2 3B Preview',
    'llama-3.2-1b-preview': 'LLaMA 3.2 1B Preview',
    'gemma2-9b-it': 'Gemma 2 9B IT',
    'deepseek-r1-distill-llama-70b': 'DeepSeek R1 70B',
    'qwen-2.5-coder-32b': 'Qwen 2.5 Coder 32B',
    'mixtral-8x7b-32768': 'Mixtral 8x7B',
  };

  static const Map<String, String> defaultCohereModels = {
    'command-r-plus': 'Command R+',
    'command-r': 'Command R',
    'command-a-03-2025': 'Command A (2025)',
    'command-light': 'Command Light',
  };

  /// Format raw model ID into user-friendly title
  static String formatModelLabel(String id) {
    if (id.isEmpty) return id;
    if (defaultGroqModels.containsKey(id)) return defaultGroqModels[id]!;
    if (defaultCohereModels.containsKey(id)) return defaultCohereModels[id]!;

    final parts = id.split(RegExp(r'[-_]'));
    final formattedParts = parts.map((part) {
      final p = part.toLowerCase();
      if (p == 'llama') return 'LLaMA';
      if (p == 'gemma' || p == 'gemma2') return 'Gemma';
      if (p == 'deepseek') return 'DeepSeek';
      if (p == 'qwen') return 'Qwen';
      if (p == 'mixtral') return 'Mixtral';
      if (p == 'command') return 'Command';
      if (p.length <= 3 && RegExp(r'^\d+[akmb]$').hasMatch(p)) return p.toUpperCase();
      if (p.length == 1) return p.toUpperCase();
      return p[0].toUpperCase() + p.substring(1);
    }).toList();

    return formattedParts.join(' ');
  }

  /// Fetch available Groq models in real-time from API endpoint
  Future<Map<String, String>> fetchGroqModels(String apiKey) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) return Map.from(defaultGroqModels);

    try {
      final url = Uri.parse('https://api.groq.com/openai/v1/models');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $cleanKey'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('data') && data['data'] is List) {
          final Map<String, String> dynamicModels = {};
          for (final item in data['data']) {
            if (item is Map && item.containsKey('id')) {
              final id = item['id'].toString();
              final isActive = item['active'] == null || item['active'] == true;
              if (isActive &&
                  !id.contains('whisper') &&
                  !id.contains('safetensors') &&
                  !id.contains('embed')) {
                dynamicModels[id] = formatModelLabel(id);
              }
            }
          }
          if (dynamicModels.isNotEmpty) {
            return dynamicModels;
          }
        }
      }
    } catch (e) {
      debugPrint('[AiSearch] Error fetching live Groq models: $e');
    }

    return Map.from(defaultGroqModels);
  }

  /// Fetch available Cohere models in real-time from API endpoint
  Future<Map<String, String>> fetchCohereModels(String apiKey) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) return Map.from(defaultCohereModels);

    try {
      final url = Uri.parse('https://api.cohere.com/v1/models');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $cleanKey'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('models') && data['models'] is List) {
          final Map<String, String> dynamicModels = {};
          for (final item in data['models']) {
            if (item is Map && item.containsKey('name')) {
              final name = item['name'].toString();
              final endpoints = item['endpoints'];
              final isChat = endpoints is List && endpoints.contains('chat');
              if (isChat || endpoints == null) {
                dynamicModels[name] = formatModelLabel(name);
              }
            }
          }
          if (dynamicModels.isNotEmpty) {
            return dynamicModels;
          }
        }
      }
    } catch (e) {
      debugPrint('[AiSearch] Error fetching live Cohere models: $e');
    }

    return Map.from(defaultCohereModels);
  }

  /// Strip reasoning/thinking blocks enclosed in think tags
  String _stripThinking(String text) {
    return text.replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '').trim();
  }

  /// Clean Markdown wrappers from JSON string returned by LLMs
  String _cleanJsonResponse(String text) {
    text = _stripThinking(text);
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

  /// Extract JSON object safely from a potentially conversational or reasoning model response
  Map<String, dynamic>? _extractJsonObject(String text) {
    final cleanedText = _cleanJsonResponse(text);
    try {
      final start = cleanedText.indexOf('{');
      final end = cleanedText.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        final jsonStr = cleanedText.substring(start, end + 1);
        return jsonDecode(jsonStr) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[AiSearch] Error parsing extracted JSON range: $e');
    }
    try {
      return jsonDecode(cleanedText) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[AiSearch] Direct jsonDecode failed: $e');
    }
    return null;
  }

  /// Parse user-friendly error messages from API JSON error responses
  String _parseApiErrorMessage(int statusCode, String responseBody, String providerName) {
    try {
      final data = jsonDecode(responseBody);
      if (data is Map<String, dynamic>) {
        if (data.containsKey('error')) {
          final errObj = data['error'];
          if (errObj is Map<String, dynamic> && errObj.containsKey('message')) {
            return '$providerName: ${errObj['message']}';
          } else if (errObj is String && errObj.isNotEmpty) {
            return '$providerName: $errObj';
          }
        }
        if (data.containsKey('message') && data['message'] is String) {
          return '$providerName: ${data['message']}';
        }
      }
    } catch (_) {
      // Fallback to raw or status message if body isn't JSON
    }
    return '$providerName API returned status $statusCode';
  }

  /// Perform AI contextual search using Groq or Cohere
  Future<AiSearchResponse> search({
    required String query,
    required String provider,
    required String model,
    required String apiKey,
  }) async {
    final cleanApiKey = apiKey.trim();
    if (cleanApiKey.isEmpty) {
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
        apiKey: cleanApiKey,
        systemPrompt: systemPrompt,
      );
    } else if (provider == 'cohere') {
      responseText = await _callCohere(
        query: query,
        model: model,
        apiKey: cleanApiKey,
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
    final isReasoningModel = model.contains('deepseek') ||
        model.contains('qwq') ||
        model.contains('r1');

    Future<http.Response> postGroq({required bool includeResponseFormat}) {
      final Map<String, dynamic> bodyMap = {
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': query}
        ],
        'temperature': 0.2,
      };
      if (includeResponseFormat) {
        bodyMap['response_format'] = {'type': 'json_object'};
      }

      return http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(bodyMap),
      );
    }

    // Reasoning models do not support response_format on Groq API
    bool useResponseFormat = !isReasoningModel;
    var response = await postGroq(includeResponseFormat: useResponseFormat);

    // Auto-retry without response_format if Groq returns 400 for unsupported response_format
    if (response.statusCode == 400 && useResponseFormat) {
      final errBody = response.body.toLowerCase();
      if (errBody.contains('response_format') || errBody.contains('unsupported')) {
        debugPrint('[AiSearch] Retrying Groq call without response_format for model: $model');
        response = await postGroq(includeResponseFormat: false);
      }
    }

    if (response.statusCode == 404) {
      throw http.ClientException(
        'Groq: Model \'$model\' is decommissioned or unavailable. Please select an active model in settings.',
      );
    }

    if (response.statusCode != 200) {
      final errorMessage = _parseApiErrorMessage(response.statusCode, response.body, 'Groq');
      if (errorMessage.toLowerCase().contains('decommission') ||
          errorMessage.toLowerCase().contains('does not exist')) {
        throw http.ClientException(
          'Groq: Model \'$model\' is decommissioned or unavailable. Please select an active model in settings.',
        );
      }
      throw http.ClientException(errorMessage);
    }

    final data = jsonDecode(response.body);
    final choices = data['choices'];
    if (choices is List && choices.isNotEmpty) {
      final firstChoice = choices.first;
      if (firstChoice is Map && firstChoice.containsKey('message')) {
        final message = firstChoice['message'];
        if (message is Map && message.containsKey('content')) {
          return (message['content'] as String?) ?? '';
        }
      }
    }

    throw http.ClientException('Groq API returned an unexpected response structure.');
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
      final errorMessage = _parseApiErrorMessage(response.statusCode, response.body, 'Cohere');
      throw http.ClientException(errorMessage);
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
        if (first is String) return first;
      }
    }

    // Fallback: look for top-level "text" key (older v2 variants)
    if (data.containsKey('text')) {
      return data['text'] as String;
    }

    throw http.ClientException(
      'Cohere v2: unexpected response shape — could not extract text.',
    );
  }
}
