import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/surah.dart';
import '../models/ayah.dart';

class ApiService {
  static const String baseUrl = 'https://api.alquran.cloud/v1';

  Future<List<Surah>> getAllSurahs() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/surah'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200 && data['data'] != null) {
          final List<dynamic> surahsJson = data['data'];
          return surahsJson.map((json) => Surah.fromJson(json)).toList();
        }
      }
      throw Exception('Failed to load surahs');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<Map<String, dynamic>> getSurahDetails(int surahNumber) async {
    try {
      // Fetch Arabic Text
      final arabicResponse = await http.get(
        Uri.parse('$baseUrl/surah/$surahNumber'),
      );
      // Fetch English Translation (Asad)
      final translationResponse = await http.get(
        Uri.parse('$baseUrl/surah/$surahNumber/en.asad'),
      );
      // Fetch Audio (Alafasy)
      final audioResponse = await http.get(
        Uri.parse('$baseUrl/surah/$surahNumber/ar.alafasy'),
      );

      if (arabicResponse.statusCode == 200 &&
          translationResponse.statusCode == 200 &&
          audioResponse.statusCode == 200) {
        final arabicData = json.decode(arabicResponse.body);
        final translationData = json.decode(translationResponse.body);
        final audioData = json.decode(audioResponse.body);

        if (arabicData['code'] == 200 &&
            translationData['code'] == 200 &&
            audioData['code'] == 200) {
          final surahInfo = Surah.fromJson(arabicData['data']);

          final List<dynamic> arabicAyahs = arabicData['data']['ayahs'];
          final List<dynamic> translationAyahs =
              translationData['data']['ayahs'];
          final List<dynamic> audioAyahs = audioData['data']['ayahs'];

          List<Ayah> ayahs = [];

          for (int i = 0; i < arabicAyahs.length; i++) {
            ayahs.add(
              Ayah(
                number: arabicAyahs[i]['number'],
                numberInSurah: arabicAyahs[i]['numberInSurah'],
                text: arabicAyahs[i]['text'],
                translation: translationAyahs[i]['text'],
                audio: audioAyahs[i]['audio'],
              ),
            );
          }

          return {'surah': surahInfo, 'ayahs': ayahs};
        }
      }
      throw Exception('Failed to load surah details');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}
