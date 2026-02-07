import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/widget_service.dart';
import '../services/database_service.dart';

class WidgetSettingsScreen extends StatefulWidget {
  const WidgetSettingsScreen({super.key});

  @override
  State<WidgetSettingsScreen> createState() => _WidgetSettingsScreenState();
}

class _WidgetSettingsScreenState extends State<WidgetSettingsScreen> {
  List<Map<String, dynamic>> _playlist = [];
  bool _isLoading = true;
  bool _isDarkMode = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final playlist = await WidgetService.getPlaylist();
    final darkMode = await WidgetService.isDarkMode();
    final currentIndex = await WidgetService.getCurrentIndex();
    setState(() {
      _playlist = playlist;
      _isDarkMode = darkMode;
      _currentIndex = currentIndex;
      _isLoading = false;
    });
  }

  Future<void> _setVerse(int index) async {
    await WidgetService.setCurrentIndex(index);
    setState(() => _currentIndex = index);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Widget updated to selected verse')),
      );
    }
  }

  Future<void> _addRandomVerse() async {
    setState(() => _isLoading = true);
    await WidgetService.addRandomVerse();
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Random verse added!')));
    }
  }

  Future<void> _removeVerse(int index) async {
    await WidgetService.removeFromPlaylist(index);
    await _loadData();
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Playlist?'),
        content: const Text('Remove all verses from the widget?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await WidgetService.clearPlaylist();
      await _loadData();
    }
  }

  Future<void> _cycleNext() async {
    await WidgetService.showNextVerse();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Widget updated to next verse')),
    );
  }

  Future<void> _toggleTheme(bool isDark) async {
    await WidgetService.setDarkMode(isDark);
    setState(() => _isDarkMode = isDark);
  }

  Future<void> _showSurahPicker() async {
    final db = DatabaseService();
    final surahs = await db.getAllSurahs();

    if (!mounted) return;

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select a Surah',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: surahs.length,
                itemBuilder: (_, i) {
                  final surah = surahs[i];
                  return ListTile(
                    leading: CircleAvatar(child: Text('${surah['number']}')),
                    title: Text(surah['englishName'] ?? 'Surah'),
                    subtitle: Text('${surah['numberOfAyahs']} verses'),
                    onTap: () => Navigator.pop(ctx, surah),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      await _showAyahPicker(selected);
    }
  }

  Future<void> _showAyahPicker(Map<String, dynamic> surah) async {
    final db = DatabaseService();
    final ayahs = await db.getAyahsForSurah(
      surah['number'] as int,
      arabicScript: 'indopak',
      translation: 'sahih',
    );

    if (!mounted) return;

    final selectedAyah = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Ayah from ${surah['englishName']}',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: ayahs.length,
                itemBuilder: (_, i) {
                  final ayah = ayahs[i];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text('${ayah['numberInSurah'] ?? ayah['aya']}'),
                    ),
                    title: Text(
                      (ayah['text'] ?? ayah['arabic'] ?? '') as String,
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      (ayah['translation'] ?? '') as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.pop(ctx, ayah),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selectedAyah != null) {
      await WidgetService.addToPlaylist(
        surahNumber: surah['number'] as int,
        ayahNumber:
            (selectedAyah['numberInSurah'] ??
                    selectedAyah['aya'] ??
                    selectedAyah['number'])
                as int,
        surahName: surah['englishName'] as String,
        arabicText:
            (selectedAyah['text'] ?? selectedAyah['arabic'] ?? '') as String,
        translation: (selectedAyah['translation'] ?? '') as String,
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${surah['englishName']} ${selectedAyah['aya']}',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Widget Settings'),
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.skip_next),
          //   tooltip: 'Next Verse',
          //   onPressed: _cycleNext,
          // ),
          IconButton(
            icon: const Icon(CupertinoIcons.delete),
            tooltip: 'Clear All',
            onPressed: _clearAll,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(11.0),
        child: Column(
          children: [
            // Theme Toggle
            Card(
              margin: const EdgeInsets.all(16),
              child: SwitchListTile(
                title: const Text('Dark Mode Widget'),
                subtitle: Text(
                  _isDarkMode ? 'Using dark theme' : 'Using light theme',
                ),
                value: _isDarkMode,
                onChanged: _toggleTheme,
                secondary: Icon(_isDarkMode ? CupertinoIcons.moon : CupertinoIcons.sun_max),
              ),
            ),

            // Playlist
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _playlist.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.playlist_add,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No verses in widget playlist',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          const Text('Add verses to customize your widget'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _playlist.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (ctx, i) {
                        final verse = _playlist[i];
                        final isSelected = i == _currentIndex;
                        return Card(
                          color: isSelected
                              ? Theme.of(context).primaryColor.withOpacity(0.1)
                              : null,
                          shape: isSelected
                              ? RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(19),
                                  side: BorderSide(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 1,
                                  ),
                                )
                              : null,
                          child: ListTile(
                            contentPadding: EdgeInsets.all(11),
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? Theme.of(context).primaryColor
                                  : null,
                              foregroundColor: isSelected ? Colors.white : null,
                              child: Text('${i + 1}'),
                            ),
                            title: Padding(
                              padding: const EdgeInsets.only(bottom: 5.0),
                              child: Text(
                                '${verse['surahName']} ${verse['verseRef']}',
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                              ),
                            ),
                            subtitle: Text(
                              verse['translation'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red,
                              ),
                              onPressed: () => _removeVerse(i),
                            ),
                            onTap: () => _setVerse(i),
                          ),
                        );
                      },
                    ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addRandomVerse,
                      icon: const Icon(CupertinoIcons.shuffle),
                      label: const Text('Random'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showSurahPicker,
                      icon: const Icon(CupertinoIcons.arrow_down_doc),
                      label: const Text('Choose'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
