import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  double _fontSize = 18.0;

  ThemeMode get themeMode => _themeMode;
  double get fontSize => _fontSize;

  SettingsProvider() {
    _loadSettings();
  }

  bool _showTafseer = false;

  bool get showTafseer => _showTafseer;

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme_mode') ?? 0;
    _themeMode = ThemeMode.values[themeIndex];
    _fontSize = prefs.getDouble('font_size') ?? 18.0;
    _showTafseer = prefs.getBool('show_tafseer') ?? false;
    notifyListeners();
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
}
