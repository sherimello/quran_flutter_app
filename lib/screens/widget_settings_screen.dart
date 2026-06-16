import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran_flutter_app/providers/settings_provider.dart';

import '../services/database_service.dart';
import '../services/widget_service.dart';
import '../widgets/blurred_sheet.dart';

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

    var size = MediaQuery.of(context).size;

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      sheetAnimationStyle: AnimationStyle(
        curve: Curves.easeOut,
        reverseCurve: Curves.easeOut,
        duration: const Duration(milliseconds: 455),
        reverseDuration: const Duration(milliseconds: 455),
      ),
      elevation: 11,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(size.width * .11),
        ),
      ),
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final routeAnim = ModalRoute.of(ctx)?.animation;
        var size = MediaQuery.of(context).size;
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) => BlurredSheet(
            animation: routeAnim,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Select a Surah',
                    style: GoogleFonts.poppins(
                      fontSize: size.width * .041,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
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
                        leading: Container(
                          width: 37,
                          height: 37,

                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface,
                            // color: isDark ? Colors.white : const Color(0xff000000),
                            // color: const Color(0xff34da15),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(size.width * .65),
                              bottomLeft: Radius.circular(size.width * .5),
                              topRight: Radius.circular(size.width * .75),
                              bottomRight: Radius.circular(size.width * .75),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${surah['number']}',
                              style: GoogleFonts.poppins(
                                color: Theme.of(context).colorScheme.surface,
                                fontSize: size.width * .033,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        // leading: CircleAvatar(
                        //   child: Text('${surah['number']}'),
                        // ),
                        title: Text(
                          surah['englishName'] ?? 'Surah',
                          style: GoogleFonts.poppins(
                            fontSize: size.width * .035,
                            fontWeight: FontWeight.w700,
                            height: 0,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          '${surah['numberOfAyahs']} verses',
                          style: GoogleFonts.poppins(
                            fontSize: size.width * .027,
                            fontWeight: FontWeight.w500,
                            height: 0,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        onTap: () => Navigator.pop(ctx, surah),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

    var size = MediaQuery.of(context).size;
    final arabicFont = SettingsProvider().arabicScript == 'utsmani'
        ? 'hafs'
        : 'qalammajeed3';

    final selectedAyah = await showModalBottomSheet<Map<String, dynamic>>(
      sheetAnimationStyle: AnimationStyle(
        curve: Curves.easeOut,
        reverseCurve: Curves.easeOut,
        duration: const Duration(milliseconds: 455),
        reverseDuration: const Duration(milliseconds: 455),
      ),
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final routeAnim = ModalRoute.of(ctx)?.animation;
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) => BlurredSheet(
            animation: routeAnim,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Select Ayah from ${surah['englishName']}',
                    style: GoogleFonts.poppins(
                      fontSize: size.width * .041,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: ayahs.length,
                    itemBuilder: (_, i) {
                      final ayah = ayahs[i];
                      return Transform.scale(
                        scale: 0.9,
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(vertical: 7),
                          dense: true,
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                spacing: 19,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Verse number badge
                                  Wrap(
                                    direction: Axis.vertical,
                                    spacing: 7,
                                    children: [
                                      Container(
                                        width: 33,
                                        height: 33,
                                        margin: EdgeInsets.only(top: 14.5),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(
                                              size.width * .65,
                                            ),
                                            bottomLeft: Radius.circular(
                                              size.width * .5,
                                            ),
                                            topRight: Radius.circular(
                                              size.width * .75,
                                            ),
                                            bottomRight: Radius.circular(
                                              size.width * .75,
                                            ),
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${ayah['numberInSurah']}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            height: 0,
                                            fontWeight: FontWeight.w900,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.surface,
                                          ),
                                        ),
                                      ),
                                      if (DatabaseService.isSajdaVerse(
                                        surah['number'] as int,
                                        ayah['numberInSurah'] as int,
                                      ))
                                        SizedBox(
                                          width: 31,
                                          height: 31,
                                          child: Image.asset(
                                            'assets/images/sujood.png',
                                            fit: BoxFit.contain,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                        ),
                                    ],
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          ((ayah['text'] ?? ayah['arabic'] ?? '')
                                                  as String)
                                              .replaceAllMapped(
                                                RegExp(r'([\u06D6-\u06DC])'),
                                                (match) =>
                                                    '      ${match.group(0)} ',
                                              ),
                                          textAlign: TextAlign.right,
                                          textDirection: TextDirection.rtl,
                                          style: TextStyle(
                                            fontFamily: arabicFont,
                                            fontSize:
                                                SettingsProvider().arabicFontSize * .95,
                                            height: 1.8,
                                            wordSpacing: 0,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 17),
                                        Text(
                                          ayah['translation'],
                                          textAlign: TextAlign.left,
                                          style: GoogleFonts.poppins(
                                            height: 0,
                                            fontSize: SettingsProvider()
                                                .translationFontSize * .95,
                                            color: Theme.of(
                                              context,
                                            ).textTheme.bodyLarge?.color,
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  //
                                ],
                              ),
                              const SizedBox(height: 0),
                            ],
                          ),
                          // leading: CircleAvatar(
                          //   child: Text(
                          //     '${ayah['numberInSurah'] ?? ayah['aya']}',
                          //   ),
                          // ),
                          // title: Text(
                          //   (ayah['text'] ?? ayah['arabic'] ?? '') as String,
                          //   textDirection: TextDirection.rtl,
                          //   maxLines: 1,
                          //   overflow: TextOverflow.ellipsis,
                          // ),
                          // subtitle: Text(
                          //   (ayah['translation'] ?? '') as String,
                          //   maxLines: 2,
                          //   overflow: TextOverflow.ellipsis,
                          // ),
                          onTap: () => Navigator.pop(ctx, ayah),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    var size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Widget Settings',
          style: GoogleFonts.poppins(
            wordSpacing: 2.5,
            fontWeight: FontWeight.bold,
            fontSize: size.width * .041,
          ),
        ),
        toolbarHeight: AppBar().preferredSize.height * 1.5,
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.skip_next),
          //   tooltip: 'Next Verse',
          //   onPressed: _cycleNext,
          // ),
          IconButton(
            icon: Icon(CupertinoIcons.trash, size: size.width * .051),
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
              margin: const EdgeInsets.all(15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(19),
              ),
              child: SwitchListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(19),
                ),
                title: Text(
                  'Dark Mode Widget',
                  style: GoogleFonts.poppins(
                    fontSize: size.width * .035,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                dense: false,
                subtitle: Text(
                  _isDarkMode ? 'Using dark theme' : 'Using light theme',
                  style: GoogleFonts.poppins(
                    fontSize: size.width * .029,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                value: _isDarkMode,
                onChanged: _toggleTheme,
                secondary: Icon(
                  _isDarkMode
                      ? CupertinoIcons.moon_stars_fill
                      : CupertinoIcons.sun_min_fill,
                  size: size.width * .059,
                ),
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
                          // Icon(
                          //   Icons.playlist_add,
                          //   size: 64,
                          //   color: Colors.grey[400],
                          // ),
                          // const SizedBox(height: 16),
                          Text(
                            'No verses in widget playlist',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: size.width * .031,
                              height: 0,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Add verses to customize your widget',
                            style: GoogleFonts.poppins(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: size.width * .035,
                              fontWeight: FontWeight.w700,
                              height: 0,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _playlist.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (ctx, i) {
                        final verse = _playlist[i];
                        final isSelected = i == _currentIndex;
                        return Transform.scale(
                          scale: .95,
                          child: Card(
                            color: isSelected
                                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.075)
                                : null,
                            shape: isSelected
                                ? RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(31),
                                    side: BorderSide(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withValues(alpha: 0.25),
                                      width: .5,
                                    ),
                                  )
                                : null,
                            child: ListTile(
                              contentPadding: EdgeInsets.all(17),
                              leading: Container(
                                width: 29,
                                height: 29,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(
                                      size.width * .65,
                                    ),
                                    bottomLeft: Radius.circular(
                                      size.width * .5,
                                    ),
                                    topRight: Radius.circular(
                                      size.width * .75,
                                    ),
                                    bottomRight: Radius.circular(
                                      size.width * .75,
                                    ),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${i + 1}',
                                  style: GoogleFonts.poppins(
                                    fontSize: size.width * .03,
                                    height: 0,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                  ),
                                ),
                              ),
                              // leading: CircleAvatar(
                              //   backgroundColor: isSelected
                              //       ? Theme.of(context).primaryColor
                              //       : null,
                              //   foregroundColor: isSelected ? Colors.white : null,
                              //   child: Text('${i + 1}'),
                              // ),
                              title: Padding(
                                padding: const EdgeInsets.only(bottom: 0.0),
                                child: Text(
                                  '${verse['surahName']} ${verse['verseRef']}',
                                  style: GoogleFonts.poppins(
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    height: 0,
                                    color: isSelected
                                        ? const Color(0xff34da15)
                                        : null,
                                  ),
                                ),
                              ),
                              subtitle: Text(
                                verse['translation'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  height: 0,
                                  fontSize: size.width * .03
                                ),
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
                          ),
                        );
                      },
                    ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _addRandomVerse,
                    icon: const Icon(CupertinoIcons.arrow_swap),
                    label: Text(
                      'Random',
                      style: GoogleFonts.poppins(
                        fontSize: size.width * .031,
                        fontWeight: FontWeight.w500,
                        height: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _showSurahPicker,
                    icon: const Icon(CupertinoIcons.return_icon),
                    label: Text(
                      'Choose',
                      style: GoogleFonts.poppins(
                        fontSize: size.width * .031,
                        fontWeight: FontWeight.w500,
                        height: 0,
                      ),
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
