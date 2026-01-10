// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import '../models/surah.dart';
// import '../models/ayah.dart';
//
// class ApiService {
//   static const String baseUrl = 'https://api.alquran.cloud/v1';
//
//   Future<List<Surah>> getAllSurahs() async {
//     try {
//       final response = await http.get(Uri.parse('$baseUrl/surah'));
//
//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         if (data['code'] == 200 && data['data'] != null) {
//           final List<dynamic> surahsJson = data['data'];
//           return surahsJson.map((json) => Surah.fromJson(json)).toList();
//         }
//       }
//       throw Exception('Failed to load surahs');
//     } catch (e) {
//       throw Exception('Error: $e');
//     }
//   }
//
//   Future<Map<String, dynamic>> getSurahDetails(int surahNumber) async {
//     try {
//       // Fetch Arabic Text
//       final arabicResponse = await http.get(
//         Uri.parse('$baseUrl/surah/$surahNumber'),
//       );
//       // Fetch English Translation (Sahih International)
//       final translationResponse = await http.get(
//         Uri.parse('$baseUrl/surah/$surahNumber/en.sahih'),
//       );
//       // Fetch Audio (Alafasy)
//       final audioResponse = await http.get(
//         Uri.parse('$baseUrl/surah/$surahNumber/ar.alafasy'),
//       );
//
//       if (arabicResponse.statusCode == 200 &&
//           translationResponse.statusCode == 200 &&
//           audioResponse.statusCode == 200) {
//         final arabicData = json.decode(arabicResponse.body);
//         final translationData = json.decode(translationResponse.body);
//         final audioData = json.decode(audioResponse.body);
//
//         if (arabicData['code'] == 200 &&
//             translationData['code'] == 200 &&
//             audioData['code'] == 200) {
//           final surahInfo = Surah.fromJson(arabicData['data']);
//
//           final List<dynamic> arabicAyahs = arabicData['data']['ayahs'];
//           final List<dynamic> translationAyahs =
//               translationData['data']['ayahs'];
//           final List<dynamic> audioAyahs = audioData['data']['ayahs'];
//
//           List<Ayah> ayahs = [];
//
//           for (int i = 0; i < arabicAyahs.length; i++) {
//             ayahs.add(
//               Ayah(
//                 number: arabicAyahs[i]['number'],
//                 numberInSurah: arabicAyahs[i]['numberInSurah'],
//                 text: arabicAyahs[i]['text'],
//                 translation: translationAyahs[i]['text'],
//                 audio: audioAyahs[i]['audio'],
//               ),
//             );
//           }
//
//           return {'surah': surahInfo, 'ayahs': ayahs};
//         }
//       }
//       throw Exception('Failed to load surah details');
//     } catch (e) {
//       throw Exception('Error: $e');
//     }
//   }
// }


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

  /// ✅ This version guarantees you get the right translation (Sahih International)
  /// because Arabic + Translation + Audio are fetched together and aligned.
  Future<Map<String, dynamic>> getSurahDetails(int surahNumber) async {
    try {
      // ✅ One request for all editions
      final response = await http.get(
        Uri.parse(
          '$baseUrl/surah/$surahNumber/editions/quran-indopak,en.sahih,ar.alafasy',
        ),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load surah details: HTTP ${response.statusCode}');
      }

      final decoded = json.decode(response.body);

      if (decoded['code'] != 200 || decoded['data'] == null) {
        throw Exception('Invalid API response');
      }

      // editions response structure:
      // data: [
      //   { edition: {...}, ayahs: [...] },  // quran-uthmani
      //   { edition: {...}, ayahs: [...] },  // en.sahih
      //   { edition: {...}, ayahs: [...] },  // ar.alafasy
      // ]
      final List editions = decoded['data'];

      if (editions.length < 3) {
        throw Exception('Editions response incomplete');
      }

      final arabicEdition = editions[0];
      final sahihEdition = editions[1];
      final audioEdition = editions[2];

      final List<dynamic> arabicAyahs = arabicEdition['ayahs'];
      final List<dynamic> translationAyahs = sahihEdition['ayahs'];
      final List<dynamic> audioAyahs = audioEdition['ayahs'];

      // ✅ Surah info can be taken from any edition (they contain same meta)
      final surahInfo = Surah.fromJson(arabicEdition);

      // ✅ Build maps by numberInSurah (NOT by index)
      final Map<int, dynamic> translationByAyah = {};
      for (final a in translationAyahs) {
        translationByAyah[a['numberInSurah']] = a;
      }

      final Map<int, dynamic> audioByAyah = {};
      for (final a in audioAyahs) {
        audioByAyah[a['numberInSurah']] = a;
      }

      List<Ayah> ayahs = [];

      for (final arAyah in arabicAyahs) {
        final int numInSurah = arAyah['numberInSurah'];

        final tr = translationByAyah[numInSurah];
        final au = audioByAyah[numInSurah];

        ayahs.add(
          Ayah(
            number: arAyah['number'],
            numberInSurah: numInSurah,
            text: arAyah['text'],
            translation: tr?['text'] ?? '',
            audio: au?['audio'] ?? '',
          ),
        );
      }

      return {
        'surah': surahInfo,
        'ayahs': ayahs,
      };
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}
