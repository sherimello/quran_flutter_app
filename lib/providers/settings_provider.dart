import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/supabase_service.dart';

class SettingsProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  double _arabicFontSize = 29.0;
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

  // AI Search Settings
  String _aiProvider = 'none'; // 'none', 'groq', 'cohere'
  String _groqApiKey = '';
  String _groqModel = 'llama-3.3-70b-versatile';
  String _cohereApiKey = '';
  String _cohereModel = 'command-r-plus';

  String get aiProvider => _aiProvider;
  String get groqApiKey => _groqApiKey;
  String get groqModel => _groqModel;
  String get cohereApiKey => _cohereApiKey;
  String get cohereModel => _cohereModel;

  Future<void> setEnableTajweed(bool value) async {
    _enableTajweed = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_tajweed', value);
    notifyListeners();
  }

  Future<void> setAiProvider(String provider) async {
    _aiProvider = provider;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_provider', provider);
    notifyListeners();
    _syncAiKeysToSupabase();
  }

  Future<void> setGroqApiKey(String key) async {
    _groqApiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('groq_api_key', key);
    notifyListeners();
    _syncAiKeysToSupabase();
  }

  Future<void> setGroqModel(String model) async {
    _groqModel = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('groq_model', model);
    notifyListeners();
    _syncAiKeysToSupabase();
  }

  Future<void> setCohereApiKey(String key) async {
    _cohereApiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cohere_api_key', key);
    notifyListeners();
    _syncAiKeysToSupabase();
  }

  Future<void> setCohereModel(String model) async {
    _cohereModel = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cohere_model', model);
    notifyListeners();
    _syncAiKeysToSupabase();
  }

  /// Push current AI keys to Supabase. Fire-and-forget — fails silently.
  void _syncAiKeysToSupabase() {
    SupabaseService().saveAiKeys(
      aiProvider: _aiProvider,
      groqApiKey: _groqApiKey,
      groqModel: _groqModel,
      cohereApiKey: _cohereApiKey,
      cohereModel: _cohereModel,
    );
  }

  /// Pull AI keys from Supabase and overwrite local state + prefs.
  /// Called once on startup after SharedPreferences load.
  Future<void> _loadAiKeysFromSupabase() async {
    try {
      final cloud = await SupabaseService().loadAiKeys();
      if (cloud == null) return;
      _aiProvider = cloud['ai_provider']!;
      _groqApiKey = cloud['groq_api_key']!;
      _groqModel = cloud['groq_model']!;
      _cohereApiKey = cloud['cohere_api_key']!;
      _cohereModel = cloud['cohere_model']!;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_provider', _aiProvider);
      await prefs.setString('groq_api_key', _groqApiKey);
      await prefs.setString('groq_model', _groqModel);
      await prefs.setString('cohere_api_key', _cohereApiKey);
      await prefs.setString('cohere_model', _cohereModel);
      notifyListeners();
    } catch (_) {
      // Fail silently — local prefs remain the source of truth
    }
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

    _arabicFontSize = prefs.getDouble('arabic_font_size') ?? 29.0;
    _translationFontSize = prefs.getDouble('translation_font_size') ?? 16.0;

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
    _aiProvider = prefs.getString('ai_provider') ?? 'none';
    _groqApiKey = prefs.getString('groq_api_key') ?? '';
    _groqModel = prefs.getString('groq_model') ?? 'llama-3.3-70b-versatile';
    _cohereApiKey = prefs.getString('cohere_api_key') ?? '';
    _cohereModel = prefs.getString('cohere_model') ?? 'command-r-plus';

    // Load Last Read data
    _lastReadSurah = prefs.getInt('last_read_surah');
    _lastReadAyah = prefs.getInt('last_read_ayah');
    _lastReadJuz = prefs.getInt('last_read_juz');
    _lastReadJuzAyah = prefs.getInt('last_read_juz_ayah');
    _wasLastReadJuz = prefs.getBool('was_last_read_juz') ?? false;

    notifyListeners();

    // Overlay with cloud AI keys if user is logged in (async, non-blocking)
    _loadAiKeysFromSupabase();
  }
}
