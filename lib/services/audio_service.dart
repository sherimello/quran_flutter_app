import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class AudioService {
  final Dio _dio = Dio();

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> getLocalAudioFile(int surahNumber, int ayahNumber) async {
    final path = await _localPath;
    String fileName =
        '${surahNumber.toString().padLeft(3, '0')}${ayahNumber.toString().padLeft(3, '0')}.mp3';
    return File('$path/$fileName');
  }

  Future<bool> isSurahDownloaded(int surahNumber, int totalAyahs) async {
    final path = await _localPath;
    String surahPrefix = surahNumber.toString().padLeft(3, '0');

    for (int i = 1; i <= totalAyahs; i++) {
      String ayahSuffix = i.toString().padLeft(3, '0');
      File file = File('$path/$surahPrefix$ayahSuffix.mp3');
      if (!await file.exists()) {
        return false;
      }
    }
    return true;
  }

  Future<void> downloadSurahAudio(
    int surahNumber,
    int totalAyahs,
    Function(double) onProgress,
  ) async {
    final path = await _localPath;
    String surahPrefix = surahNumber.toString().padLeft(3, '0');

    for (int i = 1; i <= totalAyahs; i++) {
      String ayahSuffix = i.toString().padLeft(3, '0');
      String fileName = '$surahPrefix$ayahSuffix.mp3';
      String tmpFileName = '$fileName.tmp';
      String url = 'https://everyayah.com/data/Alafasy_128kbps/$fileName';

      File finalFile = File('$path/$fileName');
      File tmpFile = File('$path/$tmpFileName');

      if (!await finalFile.exists()) {
        try {
          // Download to temporary file
          await _dio.download(url, tmpFile.path);
          // Rename to final file only after successful download
          await tmpFile.rename(finalFile.path);
        } catch (e) {
          // Cleanup partial file on failure
          if (await tmpFile.exists()) {
            await tmpFile.delete();
          }
          throw Exception('Failed to download ayah $i: $e');
        }
      }

      onProgress(i / totalAyahs);
    }
  }

  Future<void> deleteSurahAudio(int surahNumber, int totalAyahs) async {
    final path = await _localPath;
    String surahPrefix = surahNumber.toString().padLeft(3, '0');

    for (int i = 1; i <= totalAyahs; i++) {
      String ayahSuffix = i.toString().padLeft(3, '0');
      File file = File('$path/$surahPrefix$ayahSuffix.mp3');
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<String> getAudioFilePath(int surahNumber, int ayahNumber) async {
    final file = await getLocalAudioFile(surahNumber, ayahNumber);
    if (await file.exists()) {
      return file.path;
    }
    throw Exception('Audio file not found');
  }
}
