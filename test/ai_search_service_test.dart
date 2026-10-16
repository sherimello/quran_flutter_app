import 'package:flutter_test/flutter_test.dart';
import 'package:quran_flutter_app/services/ai_search_service.dart';

void main() {
  group('AiSearchService Tests', () {
    final aiSearchService = AiSearchService();

    test('Throws ArgumentError when API key is empty or whitespace', () async {
      expect(
        () => aiSearchService.search(
          query: 'patience in hardship',
          provider: 'groq',
          model: 'llama-3.3-70b-versatile',
          apiKey: '   ',
        ),
        throwsArgumentError,
      );
    });

    test('Throws UnsupportedError for unknown provider', () async {
      expect(
        () => aiSearchService.search(
          query: 'patience',
          provider: 'unknown_provider',
          model: 'some-model',
          apiKey: 'some_key',
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('formatModelLabel generates readable model titles', () {
      expect(
        AiSearchService.formatModelLabel('llama-3.3-70b-versatile'),
        'LLaMA 3.3 70B Versatile',
      );
      expect(
        AiSearchService.formatModelLabel('deepseek-r1-distill-llama-70b'),
        'DeepSeek R1 70B',
      );
      expect(
        AiSearchService.formatModelLabel('qwen-2.5-coder-32b'),
        'Qwen 2.5 Coder 32B',
      );
    });

    test('fetchGroqModels falls back to default models when API key is empty', () async {
      final models = await aiSearchService.fetchGroqModels('');
      expect(models.isNotEmpty, true);
      expect(models.containsKey('llama-3.3-70b-versatile'), true);
    });

    test('fetchCohereModels falls back to default models when API key is empty', () async {
      final models = await aiSearchService.fetchCohereModels('');
      expect(models.isNotEmpty, true);
      expect(models.containsKey('command-r-plus'), true);
    });
  });
}
