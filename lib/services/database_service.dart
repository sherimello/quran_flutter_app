import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;
  Database? _quranDatabase;
  Database? _tafseerDatabase;

  // Main app database (for bookmarks and settings)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  // Quran.db database (read-only)
  Future<Database> get quranDatabase async {
    if (_quranDatabase != null) return _quranDatabase!;
    _quranDatabase = await _initQuranDB();
    return _quranDatabase!;
  }

  // Tafseer database (read-only)
  Future<Database> get tafseerDatabase async {
    if (_tafseerDatabase != null) return _tafseerDatabase!;
    _tafseerDatabase = await _initTafseerDB();
    return _tafseerDatabase!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'quran_app.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        // Create Bookmarks table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS bookmarks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            remote_id INTEGER,
            folder_name TEXT,
            surah_number INTEGER,
            ayah_number INTEGER,
            user_id TEXT,
            updated_at TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 4) {
          // Migration: Remove old surahs and ayahs tables
          await db.execute('DROP TABLE IF EXISTS surahs');
          await db.execute('DROP TABLE IF EXISTS ayahs');
        }
      },
    );
  }

  Future<Database> _initQuranDB() async {
    String dbPath = join(await getDatabasesPath(), 'Quran.db');

    bool exists = await databaseExists(dbPath);

    if (!exists) {
      try {
        await Directory(dirname(dbPath)).create(recursive: true);

        ByteData data = await rootBundle.load('assets/db/Quran.db');
        List<int> bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await File(dbPath).writeAsBytes(bytes, flush: true);
      } catch (e) {
        print('Error copying Quran.db: $e');
      }
    }

    return await openDatabase(dbPath, readOnly: true);
  }

  Future<Database> _initTafseerDB() async {
    String dbPath = join(await getDatabasesPath(), 'quran_tafsir.db');

    bool exists = await databaseExists(dbPath);

    if (!exists) {
      try {
        await Directory(dirname(dbPath)).create(recursive: true);

        ByteData data = await rootBundle.load('assets/db/quran_tafsir.db');
        List<int> bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await File(dbPath).writeAsBytes(bytes, flush: true);
      } catch (e) {
        print('Error copying Tafseer DB: $e');
      }
    }

    return await openDatabase(dbPath, readOnly: true);
  }

  // ===== QURAN DATA METHODS =====

  /// Get all surahs (from sura_search_sura_search table)
  Future<List<Map<String, dynamic>>> getAllSurahs() async {
    final db = await quranDatabase;
    final results = await db.query(
      'sura_search_sura_search',
      orderBy: 'no ASC',
    );

    // Get ayah counts for each surah
    List<Map<String, dynamic>> surahs = [];
    for (var surah in results) {
      final count = await _getAyahCountForSurah(surah['no'] as int);
      surahs.add({
        'number': surah['no'],
        'name': surah['melayu'], // Arabic name
        'englishName': surah['english'],
        'englishNameTranslation': surah['english'],
        'numberOfAyahs': count,
        'revelationType': '', // Not available in this DB
      });
    }

    return surahs;
  }

  Future<int> _getAyahCountForSurah(int surahNumber) async {
    final db = await quranDatabase;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM al_quran_indopak_quran WHERE sura = ?',
      [surahNumber],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Map<String, dynamic>?> getSurahByNumber(int number) async {
    final db = await quranDatabase;
    final results = await db.query(
      'sura_search_sura_search',
      where: 'no = ?',
      whereArgs: [number],
    );

    if (results.isEmpty) return null;

    final surah = results.first;
    final count = await _getAyahCountForSurah(number);

    return {
      'number': surah['no'],
      'name': surah['melayu'], // Arabic name
      'englishName': surah['english'],
      'englishNameTranslation': surah['english'],
      'numberOfAyahs': count,
      'revelationType': '',
    };
  }

  /// Get ayahs for a specific surah with user preferences
  Future<List<Map<String, dynamic>>> getAyahsForSurah(
    int surahNumber, {
    String arabicScript = 'indopak',
    String translation = 'sahih',
    String pronunciation = 'latin_english',
  }) async {
    final db = await quranDatabase;

    // Determine table names based on preferences
    String arabicTable = arabicScript == 'indopak'
        ? 'al_quran_indopak_quran'
        : 'al_quran_utsmani_quran';

    String translationTable = translation == 'sahih'
        ? 'terjemahan_quran'
        : 'jalalayn_quran';

    String? pronunciationTable;
    if (pronunciation == 'latin') {
      pronunciationTable = 'latin_quran';
    } else if (pronunciation == 'latin_english') {
      pronunciationTable = 'latin_english_quran';
    }

    // Get Arabic text
    final arabicResults = await db.query(
      arabicTable,
      where: 'sura = ?',
      whereArgs: [surahNumber],
      orderBy: 'aya ASC',
    );

    // Get translations
    final translationResults = await db.query(
      translationTable,
      where: 'sura = ?',
      whereArgs: [surahNumber],
      orderBy: 'aya ASC',
    );

    // Get pronunciations (if requested)
    List<Map<String, dynamic>>? pronunciationResults;
    if (pronunciationTable != null) {
      pronunciationResults = await db.query(
        pronunciationTable,
        where: 'sura = ?',
        whereArgs: [surahNumber],
        orderBy: 'aya ASC',
      );
    }

    // Combine results
    List<Map<String, dynamic>> ayahs = [];
    for (int i = 0; i < arabicResults.length; i++) {
      Map<String, dynamic> ayah = {
        'number': i + 1, // Global verse number (not used much)
        'text': arabicResults[i]['text'],
        'numberInSurah': arabicResults[i]['aya'],
        'surahNumber': surahNumber,
      };

      if (i < translationResults.length) {
        ayah['translation'] = translationResults[i]['text'];
      }

      if (pronunciationResults != null && i < pronunciationResults.length) {
        ayah['pronunciation'] = pronunciationResults[i]['text'];
      }

      ayahs.add(ayah);
    }

    return ayahs;
  }

  /// Get word-by-word translation for a specific ayah
  Future<List<Map<String, dynamic>>> getWordByWordForAyah(
    int surah,
    int ayah,
  ) async {
    final db = await quranDatabase;

    final results = await db.query(
      'kata_quran',
      where: 'sura = ? AND aya = ?',
      whereArgs: [surah, ayah],
      orderBy: 'word ASC',
    );

    return results
        .map(
          (row) => {
            'word': row['word'],
            'arabic': row['ar'],
            'translation': row['tr'],
          },
        )
        .toList();
  }

  Future<Map<int, List<Map<String, dynamic>>>> getWordByWordForSurah(
    int surah,
  ) async {
    final db = await quranDatabase;

    final results = await db.query(
      'kata_quran',
      where: 'sura = ?',
      whereArgs: [surah],
      orderBy: 'aya ASC, word ASC',
    );

    Map<int, List<Map<String, dynamic>>> byAyah = {};
    for (var row in results) {
      int aya = row['aya'] as int;
      if (!byAyah.containsKey(aya)) byAyah[aya] = [];
      byAyah[aya]!.add({
        'word': row['word'],
        'arabic': row['ar'],
        'translation': row['tr'],
      });
    }
    return byAyah;
  }

  /// Search surahs by name (multi-language)
  Future<List<Map<String, dynamic>>> searchSurahs(String query) async {
    final db = await quranDatabase;

    final lowerQuery = query.toLowerCase();

    final results = await db.query(
      'sura_search_sura_search',
      orderBy: 'no ASC',
    );

    // Filter results
    List<Map<String, dynamic>> filtered = [];
    for (var surah in results) {
      bool matches = false;

      // Search in various fields
      if (surah['english']?.toString().toLowerCase().contains(lowerQuery) ==
              true ||
          surah['melayu']?.toString().toLowerCase().contains(lowerQuery) ==
              true ||
          surah['indonesia']?.toString().toLowerCase().contains(lowerQuery) ==
              true ||
          surah['bangla']?.toString().toLowerCase().contains(lowerQuery) ==
              true ||
          surah['urdu']?.toString().toLowerCase().contains(lowerQuery) ==
              true ||
          surah['francais']?.toString().toLowerCase().contains(lowerQuery) ==
              true ||
          surah['suggest']?.toString().toLowerCase().contains(lowerQuery) ==
              true ||
          surah['no'].toString().contains(query)) {
        matches = true;
      }

      if (matches) {
        final count = await _getAyahCountForSurah(surah['no'] as int);
        filtered.add({
          'number': surah['no'],
          'name': surah['melayu'],
          'englishName': surah['english'],
          'englishNameTranslation': surah['english'],
          'numberOfAyahs': count,
          'revelationType': '',
        });
      }
    }

    return filtered;
  }

  /// Get ayahs for a specific Juz
  /// Note: We need Juz boundary data - for now using standard 30 Juz division
  Future<List<Map<String, dynamic>>> getAyahsForJuz(
    int juzNumber, {
    String arabicScript = 'indopak',
    String translation = 'sahih',
    String pronunciation = 'latin_english',
  }) async {
    // Standard Juz boundaries (surah:ayah format)
    final juzBoundaries = _getJuzBoundaries();

    if (juzNumber < 1 || juzNumber > 30) {
      return [];
    }

    final boundary = juzBoundaries[juzNumber - 1];
    final startSurah = boundary['startSurah'] as int;
    final startAyah = boundary['startAyah'] as int;
    final endSurah = boundary['endSurah'] as int;
    final endAyah = boundary['endAyah'] as int;

    List<Map<String, dynamic>> allAyahs = [];

    // Fetch all surahs in this juz
    for (int surah = startSurah; surah <= endSurah; surah++) {
      final ayahs = await getAyahsForSurah(
        surah,
        arabicScript: arabicScript,
        translation: translation,
        pronunciation: pronunciation,
      );

      // Filter ayahs based on juz boundaries
      List<Map<String, dynamic>> filtered = [];
      for (var ayah in ayahs) {
        int ayahNum = ayah['numberInSurah'] as int;

        if (surah == startSurah && surah == endSurah) {
          // Same surah
          if (ayahNum >= startAyah && ayahNum <= endAyah) {
            filtered.add({...ayah, 'surahName': await _getSurahName(surah)});
          }
        } else if (surah == startSurah) {
          // First surah in juz
          if (ayahNum >= startAyah) {
            filtered.add({...ayah, 'surahName': await _getSurahName(surah)});
          }
        } else if (surah == endSurah) {
          // Last surah in juz
          if (ayahNum <= endAyah) {
            filtered.add({...ayah, 'surahName': await _getSurahName(surah)});
          }
        } else {
          // Middle surahs - include all ayahs
          filtered.add({...ayah, 'surahName': await _getSurahName(surah)});
        }
      }

      allAyahs.addAll(filtered);
    }

    return allAyahs;
  }

  Future<String> _getSurahName(int surahNumber) async {
    final surah = await getSurahByNumber(surahNumber);
    return surah?['englishName'] ?? 'Surah $surahNumber';
  }

  List<Map<String, dynamic>> _getJuzBoundaries() {
    // Standard 30 Juz boundaries
    return [
      {'startSurah': 1, 'startAyah': 1, 'endSurah': 2, 'endAyah': 141},
      {'startSurah': 2, 'startAyah': 142, 'endSurah': 2, 'endAyah': 252},
      {'startSurah': 2, 'startAyah': 253, 'endSurah': 3, 'endAyah': 92},
      {'startSurah': 3, 'startAyah': 93, 'endSurah': 4, 'endAyah': 23},
      {'startSurah': 4, 'startAyah': 24, 'endSurah': 4, 'endAyah': 147},
      {'startSurah': 4, 'startAyah': 148, 'endSurah': 5, 'endAyah': 81},
      {'startSurah': 5, 'startAyah': 82, 'endSurah': 6, 'endAyah': 110},
      {'startSurah': 6, 'startAyah': 111, 'endSurah': 7, 'endAyah': 87},
      {'startSurah': 7, 'startAyah': 88, 'endSurah': 8, 'endAyah': 40},
      {'startSurah': 8, 'startAyah': 41, 'endSurah': 9, 'endAyah': 92},
      {'startSurah': 9, 'startAyah': 93, 'endSurah': 11, 'endAyah': 5},
      {'startSurah': 11, 'startAyah': 6, 'endSurah': 12, 'endAyah': 52},
      {'startSurah': 12, 'startAyah': 53, 'endSurah': 14, 'endAyah': 52},
      {'startSurah': 15, 'startAyah': 1, 'endSurah': 16, 'endAyah': 128},
      {'startSurah': 17, 'startAyah': 1, 'endSurah': 18, 'endAyah': 74},
      {'startSurah': 18, 'startAyah': 75, 'endSurah': 20, 'endAyah': 135},
      {'startSurah': 21, 'startAyah': 1, 'endSurah': 22, 'endAyah': 78},
      {'startSurah': 23, 'startAyah': 1, 'endSurah': 25, 'endAyah': 20},
      {'startSurah': 25, 'startAyah': 21, 'endSurah': 27, 'endAyah': 55},
      {'startSurah': 27, 'startAyah': 56, 'endSurah': 29, 'endAyah': 45},
      {'startSurah': 29, 'startAyah': 46, 'endSurah': 33, 'endAyah': 30},
      {'startSurah': 33, 'startAyah': 31, 'endSurah': 36, 'endAyah': 27},
      {'startSurah': 36, 'startAyah': 28, 'endSurah': 39, 'endAyah': 31},
      {'startSurah': 39, 'startAyah': 32, 'endSurah': 41, 'endAyah': 46},
      {'startSurah': 41, 'startAyah': 47, 'endSurah': 45, 'endAyah': 37},
      {'startSurah': 46, 'startAyah': 1, 'endSurah': 51, 'endAyah': 30},
      {'startSurah': 51, 'startAyah': 31, 'endSurah': 57, 'endAyah': 29},
      {'startSurah': 58, 'startAyah': 1, 'endSurah': 66, 'endAyah': 12},
      {'startSurah': 67, 'startAyah': 1, 'endSurah': 77, 'endAyah': 50},
      {'startSurah': 78, 'startAyah': 1, 'endSurah': 114, 'endAyah': 6},
    ];
  }

  // ===== BOOKMARK METHODS =====

  Future<void> insertBookmark(Map<String, dynamic> bookmark) async {
    final db = await database;
    await db.insert(
      'bookmarks',
      bookmark,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteBookmarkLocally(int id) async {
    final db = await database;
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteFolderLocally(String folderName) async {
    final db = await database;
    await db.delete(
      'bookmarks',
      where: 'folder_name = ?',
      whereArgs: [folderName],
    );
  }

  Future<List<Map<String, dynamic>>> getAllBookmarks() async {
    final db = await database;
    return await db.query('bookmarks', orderBy: 'updated_at DESC');
  }

  Future<void> clearLocalBookmarks() async {
    final db = await database;
    await db.delete('bookmarks');
  }

  // ===== TAFSEER METHODS =====

  Future<String?> getTafseer(int surah, int ayah) async {
    try {
      final db = await tafseerDatabase;
      final results = await db.query(
        'tafseer',
        columns: ['text'],
        where: 'surah = ? AND ayah = ?',
        whereArgs: [surah, ayah],
      );

      if (results.isNotEmpty) {
        return results.first['text'] as String?;
      }
    } catch (e) {
      print('Error fetching tafseer: $e');
    }
    return null;
  }

  Future<Map<int, String>> getTafseersForSurah(int surah) async {
    try {
      final db = await tafseerDatabase;
      final results = await db.query(
        'tafseer',
        columns: ['ayah', 'text'],
        where: 'surah = ?',
        whereArgs: [surah],
      );

      return {
        for (final row in results) row['ayah'] as int: row['text'] as String,
      };
    } catch (e) {
      print('Error fetching bulk tafseers: $e');
    }
    return {};
  }
}
