import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'quran_app.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        // Create Surahs table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS surahs(
            number INTEGER PRIMARY KEY,
            name TEXT,
            englishName TEXT,
            englishNameTranslation TEXT,
            numberOfAyahs INTEGER,
            revelationType TEXT
          )
        ''');

        // Create Ayahs table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ayahs(
            number INTEGER PRIMARY KEY,
            text TEXT,
            translation TEXT,
            numberInSurah INTEGER,
            juz INTEGER,
            manzil INTEGER,
            page INTEGER,
            ruku INTEGER,
            hizbQuarter INTEGER,
            sajda BOOLEAN,
            surahNumber INTEGER,
            FOREIGN KEY(surahNumber) REFERENCES surahs(number)
          )
        ''');

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
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE ayahs ADD COLUMN translation TEXT');
        }
        if (oldVersion < 3) {
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
        }
      },
    );
  }

  // Insert multiple Surahs efficiently
  Future<void> insertSurahs(List<Map<String, dynamic>> surahs) async {
    final db = await database;
    Batch batch = db.batch();
    for (var surah in surahs) {
      // Prepare valid surah map
      Map<String, dynamic> surahData = {
        'number': surah['number'],
        'name': surah['name'],
        'englishName': surah['englishName'],
        'englishNameTranslation': surah['englishNameTranslation'],
        'numberOfAyahs': surah['numberOfAyahs'],
        'revelationType': surah['revelationType'],
      };
      batch.insert(
        'surahs',
        surahData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // Insert Ayahs for a specific Surah
  Future<void> insertAyahs(int surahNumber, List<dynamic> ayahs) async {
    final db = await database;
    Batch batch = db.batch();
    for (var ayah in ayahs) {
      Map<String, dynamic> ayahData = {
        'number': ayah['number'],
        'text': ayah['text'],
        'translation': ayah['translation'], // Add translation
        'numberInSurah': ayah['numberInSurah'],
        'juz': ayah['juz'],
        'manzil': ayah['manzil'],
        'page': ayah['page'],
        'ruku': ayah['ruku'],
        'hizbQuarter': ayah['hizbQuarter'],
        'sajda': ayah['sajda'] is bool
            ? (ayah['sajda'] ? 1 : 0)
            : 0, // Handle boolean to int
        'surahNumber': surahNumber,
      };
      batch.insert(
        'ayahs',
        ayahData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // Update only translations for ayahs
  Future<void> updateTranslations(
    int surahNumber,
    List<String> translations,
  ) async {
    final db = await database;
    Batch batch = db.batch();

    // We need to know the numberInSurah or absolute number.
    // The translations list is ordered by numberInSurah (1-indexed).
    for (int i = 0; i < translations.length; i++) {
      batch.update(
        'ayahs',
        {'translation': translations[i]},
        where: 'surahNumber = ? AND numberInSurah = ?',
        whereArgs: [surahNumber, i + 1],
      );
    }
    await batch.commit(noResult: true);
  }

  // Check if database is populated
  Future<bool> isDatabasePopulated() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM surahs'),
    );
    return count != null && count > 0;
  }

  Future<List<Map<String, dynamic>>> getAllSurahs() async {
    final db = await database;
    return await db.query('surahs', orderBy: 'number ASC');
  }

  Future<Map<String, dynamic>?> getSurahByNumber(int number) async {
    final db = await database;
    final results = await db.query(
      'surahs',
      where: 'number = ?',
      whereArgs: [number],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAyahsForSurah(int surahNumber) async {
    final db = await database;
    return await db.query(
      'ayahs',
      where: 'surahNumber = ?',
      whereArgs: [surahNumber],
      orderBy: 'numberInSurah ASC',
    );
  }

  // Bookmark Local CRUD
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

  Future<void> clearQuranData() async {
    final db = await database;
    await db.delete('surahs');
    await db.delete('ayahs');
  }
}
