import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  double _fontSize = 18.0;
  bool _showTafseer = false;

  // New settings for Quran.db
  String _arabicScript = 'indopak'; // 'indopak' or 'utsmani'
  String _translation = 'sahih'; // 'sahih' or 'jalalayn'
  String _pronunciation = 'latin_english'; // 'latin', 'latin_english', 'none'
  bool _showWordByWord = false;

  ThemeMode get themeMode => _themeMode;
  double get fontSize => _fontSize;
  bool get showTafseer => _showTafseer;
  String get arabicScript => _arabicScript;
  String get translation => _translation;
  String get pronunciation => _pronunciation;
  bool get showWordByWord => _showWordByWord;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_size', size);
    notifyListeners();
  }

  Future<void> setShowTafseer(bool value) async {
    _showTafseer = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_tafseer', value);
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

  // Tajweed Settings
  bool _enableTajweed = false;
  bool get enableTajweed => _enableTajweed;

  Future<void> setEnableTajweed(bool value) async {
    _enableTajweed = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_tajweed', value);
    notifyListeners();
  }

  // Load implementation override
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme_mode') ?? 0;
    _themeMode = ThemeMode.values[themeIndex];
    _fontSize = prefs.getDouble('font_size') ?? 18.0;
    _showTafseer = prefs.getBool('show_tafseer') ?? false;
    _arabicScript = prefs.getString('arabic_script') ?? 'indopak';
    _translation = prefs.getString('translation') ?? 'sahih';
    _pronunciation = prefs.getString('pronunciation') ?? 'latin_english';
    _showWordByWord = prefs.getBool('show_word_by_word') ?? false;
    _enableTajweed = prefs.getBool('enable_tajweed') ?? false;
    notifyListeners();
  }
}
