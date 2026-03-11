import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  double _arabicFontSize = 24.0;
  double _translationFontSize = 16.0;
  bool _showTafseer = false;
  bool _isReadingMode = false;

  // New settings for Quran.db
  String _arabicScript = 'indopak'; // 'indopak' or 'utsmani'
  String _translation = 'sahih'; // 'sahih' or 'jalalayn'
  String _pronunciation = 'latin_english'; // 'latin', 'latin_english', 'none'
  bool _showWordByWord = false;
  bool _showWbwTransliteration = true;

  // Last Read Tracking
  int? _lastReadSurah;
  int? _lastReadAyah;
  int? _lastReadJuz;
  int? _lastReadJuzAyah;
  bool _wasLastReadJuz = false;

  ThemeMode get themeMode => _themeMode;
  double get arabicFontSize => _arabicFontSize;
  double get translationFontSize => _translationFontSize;
  bool get showTafseer => _showTafseer;
  bool get isReadingMode => _isReadingMode;
  String get arabicScript => _arabicScript;
  String get translation => _translation;
  String get pronunciation => _pronunciation;
  bool get showWordByWord => _showWordByWord;
  bool get showWbwTransliteration => _showWbwTransliteration;

  int? get lastReadSurah => _lastReadSurah;
  int? get lastReadAyah => _lastReadAyah;
  int? get lastReadJuz => _lastReadJuz;
  int? get lastReadJuzAyah => _lastReadJuzAyah;
  bool get wasLastReadJuz => _wasLastReadJuz;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }

  Future<void> setArabicFontSize(double size) async {
    _arabicFontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('arabic_font_size', size);
    notifyListeners();
  }

  Future<void> setTranslationFontSize(double size) async {
    _translationFontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('translation_font_size', size);
    notifyListeners();
  }

  Future<void> setShowTafseer(bool value) async {
    _showTafseer = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_tafseer', value);
    notifyListeners();
  }

  Future<void> setIsReadingMode(bool value) async {
    _isReadingMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_reading_mode', value);
    notifyListeners();
  }

  Future<void> setArabicScript(String script) async {
    _arabicScript = script;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('arabic_script', script);
    notifyListeners();
  }

  Future<void> setTranslation(String trans) async {
    _translation = trans;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('translation', trans);
    notifyListeners();
  }

  Future<void> setPronunciation(String pron) async {
    _pronunciation = pron;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pronunciation', pron);
    notifyListeners();
  }

  Future<void> setShowWordByWord(bool value) async {
    _showWordByWord = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_word_by_word', value);
    notifyListeners();
  }

  Future<void> setShowWbwTransliteration(bool value) async {
    _showWbwTransliteration = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_wbw_transliteration', value);
    notifyListeners();
  }

  // Word By Word Settings
  String _wordByWordLanguage = 'en'; // Fixed to 'en'
  String _wordByWordTransliteration = 'en_trans';

  String get wordByWordLanguage => _wordByWordLanguage;
  String get wordByWordTransliteration => _wordByWordTransliteration;

  Future<void> setWordByWordLanguage(String lang) async {
    // Only 'en' is allowed now, but we'll keep the method for compatibility
    _wordByWordLanguage = 'en';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wbw_language', 'en');
    notifyListeners();
  }

  Future<void> setWordByWordTransliteration(String trans) async {
    _wordByWordTransliteration = trans;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wbw_transliteration', trans);
    notifyListeners();
  }

  // Tajweed Settings
  bool _enableTajweed = false;
  bool get enableTajweed => _enableTajweed;

  Future<void> setEnableTajweed(bool value) async {
    _enableTajweed = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_tajweed', value);
    notifyListeners();
  }

  // Last Read Methods
  Future<void> saveLastReadSurah(int surah, int ayah) async {
    _lastReadSurah = surah;
    _lastReadAyah = ayah;
    _wasLastReadJuz = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_read_surah', surah);
    await prefs.setInt('last_read_ayah', ayah);
    await prefs.setBool('was_last_read_juz', false);
    notifyListeners();
  }

  Future<void> saveLastReadJuz(int juz, int ayahIndex) async {
    _lastReadJuz = juz;
    _lastReadJuzAyah = ayahIndex;
    _wasLastReadJuz = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_read_juz', juz);
    await prefs.setInt('last_read_juz_ayah', ayahIndex);
    await prefs.setBool('was_last_read_juz', true);
    notifyListeners();
  }

  // Load implementation override
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme_mode') ?? 0;
    _themeMode = ThemeMode.values[themeIndex];

    // Migration logic from single font_size to separate ones
    final oldFontSize = prefs.getDouble('font_size') ?? 18.0;
    _arabicFontSize =
        prefs.getDouble('arabic_font_size') ?? (oldFontSize + 6.0);
    _translationFontSize =
        prefs.getDouble('translation_font_size') ?? oldFontSize;

    _showTafseer = prefs.getBool('show_tafseer') ?? false;
    _isReadingMode = prefs.getBool('is_reading_mode') ?? false;
    _arabicScript = prefs.getString('arabic_script') ?? 'indopak';
    _translation = prefs.getString('translation') ?? 'sahih';
    _pronunciation = prefs.getString('pronunciation') ?? 'latin_english';
    _showWordByWord = prefs.getBool('show_word_by_word') ?? false;
    _wordByWordLanguage = 'en'; // Force English
    _wordByWordTransliteration =
        prefs.getString('wbw_transliteration') ?? 'en_trans';
    _enableTajweed = prefs.getBool('enable_tajweed') ?? false;
    _showWbwTransliteration = prefs.getBool('show_wbw_transliteration') ?? true;

    // Load Last Read data
    _lastReadSurah = prefs.getInt('last_read_surah');
    _lastReadAyah = prefs.getInt('last_read_ayah');
    _lastReadJuz = prefs.getInt('last_read_juz');
    _lastReadJuzAyah = prefs.getInt('last_read_juz_ayah');
    _wasLastReadJuz = prefs.getBool('was_last_read_juz') ?? false;

    notifyListeners();
  }
}
