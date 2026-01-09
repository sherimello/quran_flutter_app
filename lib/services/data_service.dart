import 'package:dio/dio.dart';
import 'database_service.dart';

class DataService {
  final Dio _dio = Dio();
  final DatabaseService _databaseService = DatabaseService();

  Future<void> fetchAndStoreQuranData(Function(double) onProgress) async {
    try {
      // Fetch Surah list
      onProgress(0.05);
      final surahResponse = await _dio.get('http://api.alquran.cloud/v1/surah');
      final surahs = List<Map<String, dynamic>>.from(
        surahResponse.data['data'],
      );

      await _databaseService.insertSurahs(surahs);
      onProgress(0.1);

      // Fetch Arabic Quran
      final quranResponse = await _dio.get(
        'http://api.alquran.cloud/v1/quran/quran-uthmani',
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(0.1 + ((received / total) * 0.3)); // 0.1 -> 0.4
          }
        },
      );

      // Fetch English Translation
      final transResponse = await _dio.get(
        'http://api.alquran.cloud/v1/quran/en.pickthall',
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(0.4 + ((received / total) * 0.3)); // 0.4 -> 0.7
          }
        },
      );

      onProgress(0.7);

      final arabicSurahs = quranResponse.data['data']['surahs'] as List;
      final transSurahs = transResponse.data['data']['surahs'] as List;

      // Process and insert ayahs
      int totalSurahs = arabicSurahs.length;
      for (int i = 0; i < totalSurahs; i++) {
        var surah = arabicSurahs[i];
        var transSurah = transSurahs[i];

        int surahNumber = surah['number'];
        List<dynamic> ayahs = surah['ayahs'];
        List<dynamic> transAyahs = transSurah['ayahs'];

        // Merge translation
        if (ayahs.length == transAyahs.length) {
          for (int j = 0; j < ayahs.length; j++) {
            ayahs[j]['translation'] = transAyahs[j]['text'];
          }
        }

        await _databaseService.insertAyahs(surahNumber, ayahs);

        // Scale progress from 0.7 to 1.0 based on insertion
        onProgress(0.7 + ((i / totalSurahs) * 0.3));
      }

      onProgress(1.0);
    } catch (e) {
      throw Exception('Failed to fetch and store Quran data: $e');
    }
  }

  Future<void> repairTranslations(Function(double) onProgress) async {
    try {
      // Fetch English Translation
      onProgress(0.05);
      final transResponse = await _dio.get(
        'http://api.alquran.cloud/v1/quran/en.pickthall',
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(0.05 + ((received / total) * 0.65)); // 0.05 -> 0.7
          }
        },
      );

      final transSurahs = transResponse.data['data']['surahs'] as List;
      int totalSurahs = transSurahs.length;

      for (int i = 0; i < totalSurahs; i++) {
        var transSurah = transSurahs[i];
        int surahNumber = transSurah['number'];
        List<dynamic> transAyahsList = transSurah['ayahs'];
        List<String> translations = transAyahsList
            .map((e) => e['text'] as String)
            .toList();

        await _databaseService.updateTranslations(surahNumber, translations);

        // Scale progress from 0.7 to 1.0 based on update
        onProgress(0.7 + ((i / totalSurahs) * 0.3));
      }

      onProgress(1.0);
    } catch (e) {
      throw Exception('Failed to repair translations: $e');
    }
  }
}
