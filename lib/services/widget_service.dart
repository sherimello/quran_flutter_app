import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/quran_home_widget.dart';
import 'database_service.dart';

class WidgetService {
  static const String androidWidgetName = 'QuranWidgetProvider';
  static const String _playlistKey = 'widget_verse_playlist';
  static const String _currentIndexKey = 'widget_current_index';
  static const String _themeKey = 'widget_dark_mode';

  // ================= PLAYLIST =================

  static Future<List<Map<String, dynamic>>> getPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_playlistKey) ?? [];
    return jsonList.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  static Future<void> addToPlaylist({
    required int surahNumber,
    required int ayahNumber,
    required String surahName,
    required String arabicText,
    required String translation,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_playlistKey) ?? [];

    list.add(
      jsonEncode({
        'surahNumber': surahNumber,
        'ayahNumber': ayahNumber,
        'surahName': surahName,
        'verseRef': '$surahNumber:$ayahNumber',
        'arabic': arabicText,
        'translation': translation,
      }),
    );

    await prefs.setStringList(_playlistKey, list);
    await updateWidget();
  }

  static Future<void> removeFromPlaylist(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_playlistKey) ?? [];

    if (index < 0 || index >= list.length) return;

    list.removeAt(index);
    await prefs.setStringList(_playlistKey, list);
    await updateWidget();
  }

  static Future<void> clearPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_playlistKey);
    await prefs.remove(_currentIndexKey);
    await updateWidget();
  }

  // ================= DATABASE =================

  static Future<void> addRandomVerse() async {
    try {
      final db = DatabaseService();

      final surahs = await db.getAllSurahs();
      if (surahs.isEmpty) return;

      final surah = surahs[DateTime.now().millisecond % surahs.length];
      final maxAyah = surah['numberOfAyahs'] as int? ?? 1;
      final randomAyah = DateTime.now().second % maxAyah + 1;

      final ayahs = await db.getAyahsForSurah(
        surah['number'] as int,
        arabicScript: 'indopak',
        translation: 'sahih',
      );

      if (ayahs.isEmpty) return;

      final ayah = ayahs.firstWhere(
        (v) => (v['numberInSurah'] ?? v['aya']) == randomAyah,
        orElse: () => ayahs.first,
      );

      await addToPlaylist(
        surahNumber: surah['number'] as int,
        ayahNumber: (ayah['numberInSurah'] ?? ayah['aya'] ?? randomAyah) as int,
        surahName: surah['englishName'] as String,
        arabicText: (ayah['text'] ?? ayah['arabic'] ?? '') as String,
        translation: (ayah['translation'] ?? '') as String,
      );
    } catch (e) {
      debugPrint('addRandomVerse error: $e');
    }
  }

  // ================= THEME =================

  static Future<void> setDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
    await updateWidget();
  }

  static Future<bool> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_themeKey)) {
      return SchedulerBinding.instance.platformDispatcher.platformBrightness ==
          ui.Brightness.dark;
    }
    return prefs.getBool(_themeKey) ?? true;
  }

  // ================= NAVIGATION =================

  static Future<void> showNextVerse() async {
    final prefs = await SharedPreferences.getInstance();
    final playlist = await getPlaylist();
    if (playlist.isEmpty) return;

    final current = prefs.getInt(_currentIndexKey) ?? 0;
    await prefs.setInt(_currentIndexKey, (current + 1) % playlist.length);
    await updateWidget();
  }

  static Future<void> showPreviousVerse() async {
    final prefs = await SharedPreferences.getInstance();
    final playlist = await getPlaylist();
    if (playlist.isEmpty) return;

    int current = prefs.getInt(_currentIndexKey) ?? 0;
    current = (current - 1) < 0 ? playlist.length - 1 : current - 1;

    await prefs.setInt(_currentIndexKey, current);
    await updateWidget();
  }

  static Future<void> setCurrentIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final playlist = await getPlaylist();
    if (index < 0 || index >= playlist.length) return;

    await prefs.setInt(_currentIndexKey, index);
    await updateWidget();
  }

  static Future<int> getCurrentIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_currentIndexKey) ?? 0;
  }

  // ================= RENDER =================

  static Future<void> updateWidget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlist = await getPlaylist();
      final darkMode = await isDarkMode();

      final data = playlist.isEmpty
          ? {
              'surahName': 'Al-Fatiha',
              'verseRef': '1:1',
              'arabic': 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
              'translation':
                  'In the name of Allah, the Entirely Merciful, the Especially Merciful.',
            }
          : playlist[(prefs.getInt(_currentIndexKey) ?? 0) % playlist.length];

      final imagePath = await HomeWidget.renderFlutterWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            color: Colors.transparent,
            child: QuranHomeWidget(
              surahName: data['surahName'] ?? '',
              verseRef: data['verseRef'] ?? '',
              arabicText: data['arabic'] ?? '',
              translation: data['translation'] ?? '',
              isDarkMode: darkMode,
            ),
          ),
        ),
        key: 'quran_widget_image',
        logicalSize: const Size(400, 200),
        pixelRatio: 2.5,
      );

      if (imagePath == null) return;

      await HomeWidget.saveWidgetData<String>('widget_image_path', imagePath);

      await HomeWidget.updateWidget(
        name: androidWidgetName,
        iOSName: androidWidgetName,
      );
    } catch (e) {
      debugPrint('WidgetService update error: $e');
    }
  }
}
