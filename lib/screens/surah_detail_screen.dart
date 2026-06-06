import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../providers/settings_provider.dart';
import '../services/audio_service.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';
import '../services/tajweed_service.dart';
import '../widgets/auto_hide_scrollbar.dart';
import 'settings_screen.dart';

class SurahDetailScreen extends StatefulWidget {
  final Map<String, dynamic> surah;
  final int? initialAyah;

  const SurahDetailScreen({super.key, required this.surah, this.initialAyah});

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<Map<String, dynamic>> _ayahs = [];
  bool _isLoading = true;
  bool _isAudioDownloaded = false;
  bool _isDownloadingAudio = false;
  double _downloadProgress = 0.0;
  int? _playingAyahId;
  bool _isAutoPlaying = false;

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  Timer? _scrollDebounce;

  // Track settings to detect changes
  String? _currentScript;
  String? _currentTranslation;
  String? _currentPronunciation;
  bool? _currentShowWordByWord;
  String? _currentWbwLanguage;
  String? _currentWbwTransliteration;
  bool? _currentShowWbwTransliteration;
  bool? _currentShowTafseer;
  bool? _currentEnableTajweed;
  Map<String, dynamic>? _chapterInfo;

  @override
  void initState() {
    super.initState();
    // Audio player listeners
    _audioPlayer.onPlayerComplete.listen((event) {
      if (!mounted) return;
      if (_isAutoPlaying && _playingAyahId != null) {
        _playNextAyah();
      } else {
        setState(() {
          _playingAyahId = null;
        });
      }
    });

    // Save reading progress when scrolling stops
    _itemPositionsListener.itemPositions.addListener(() {
      _scrollDebounce?.cancel();
      _scrollDebounce = Timer(const Duration(milliseconds: 500), () {
        if (!mounted || _isLoading || _ayahs.isEmpty) return;

        final positions = _itemPositionsListener.itemPositions.value;
        if (positions.isNotEmpty) {
          // Find the first fully or partially visible item starting from the top
          final topItem = positions
              .where((ItemPosition position) => position.itemTrailingEdge > 0)
              .reduce(
                (min, position) =>
                    position.itemLeadingEdge < min.itemLeadingEdge
                    ? position
                    : min,
              );

          // List index 0 is the Surah header; ayahs start at list index 1.
          final listIndex = topItem.index;
          if (listIndex > 0 && listIndex <= _ayahs.length) {
            final ayahData = _ayahs[listIndex - 1];
            final ayahNumber = (ayahData['numberInSurah'] as int?) ?? 1;

            final settings = Provider.of<SettingsProvider>(
              context,
              listen: false,
            );
            settings.saveLastReadSurah(widget.surah['number'], ayahNumber);
          }
        }
      });
    });

    // Check audio status
    _checkAudioStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check for settings changes and refetch if needed
    final settings = Provider.of<SettingsProvider>(context);
    if (_currentScript != settings.arabicScript ||
        _currentTranslation != settings.translation ||
        _currentPronunciation != settings.pronunciation ||
        _currentShowWordByWord != settings.showWordByWord ||
        _currentWbwLanguage != settings.wordByWordLanguage ||
        _currentWbwTransliteration != settings.wordByWordTransliteration ||
        _currentShowWbwTransliteration != settings.showWbwTransliteration ||
        _currentShowTafseer != settings.showTafseer ||
        _currentEnableTajweed != settings.enableTajweed) {
      _currentScript = settings.arabicScript;
      _currentTranslation = settings.translation;
      _currentPronunciation = settings.pronunciation;
      _currentShowWordByWord = settings.showWordByWord;
      _currentWbwLanguage = settings.wordByWordLanguage;
      _currentWbwTransliteration = settings.wordByWordTransliteration;
      _currentShowWbwTransliteration = settings.showWbwTransliteration;
      _currentShowTafseer = settings.showTafseer;
      _currentEnableTajweed = settings.enableTajweed;

      _fetchAyahs();
    }
  }

  Future<void> _fetchAyahs() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final settings = Provider.of<SettingsProvider>(context, listen: false);

    try {
      // 1. Fetch Ayahs with selected script, translation, pronunciation
      final ayahsFuture = DatabaseService().getAyahsForSurah(
        widget.surah['number'],
        arabicScript: settings.arabicScript,
        translation: settings.translation,
        pronunciation: settings.pronunciation,
      );

      // 2. Fetch Word-by-Word data if enabled
      Future<Map<int, List<Map<String, dynamic>>>>? wbwFuture;
      if (settings.showWordByWord) {
        wbwFuture = DatabaseService().getWordByWordForSurah(
          widget.surah['number'],
          language: settings.wordByWordLanguage,
          transliteration: settings.wordByWordTransliteration,
        );
      }

      // 3. Fetch Tafseer if enabled
      Future<Map<int, String>>? tafseerFuture;
      if (settings.showTafseer) {
        tafseerFuture = DatabaseService().getTafseersForSurah(
          widget.surah['number'],
        );
      }

      // 4. Fetch Chapter Info
      final chapterInfoFuture = DatabaseService().getChapterInfo(
        widget.surah['number'],
      );

      final results = await Future.wait([
        ayahsFuture,
        if (wbwFuture != null) wbwFuture,
        if (tafseerFuture != null) tafseerFuture,
        chapterInfoFuture,
      ]);

      List<Map<String, dynamic>> ayahs = List.from(results[0] as List);

      // Determine indices in results array
      int resultIndex = 1;
      Map<int, List<Map<String, dynamic>>>? wbwData;
      if (wbwFuture != null) {
        wbwData =
            results[resultIndex++] as Map<int, List<Map<String, dynamic>>>;
      }

      Map<int, String>? tafseerData;
      if (tafseerFuture != null) {
        tafseerData = results[resultIndex++] as Map<int, String>;
      }

      // Merge data
      for (var i = 0; i < ayahs.length; i++) {
        final ayahNum = ayahs[i]['numberInSurah'];

        // Add Word-by-Word directly from DB (already contains Arabic text)
        if (wbwData != null && wbwData.containsKey(ayahNum)) {
          ayahs[i]['words'] = wbwData[ayahNum];
        }

        // Add Tafseer
        if (tafseerData != null && tafseerData.containsKey(ayahNum)) {
          final tafseer = tafseerData[ayahNum]!;
          ayahs[i]['tafseer'] = tafseer;
          ayahs[i]['tafseerSnippet'] = _stripHtml(tafseer);
          ayahs[i]['isTafseerExpanded'] = false;
        }
      }

      if (mounted) {
        setState(() {
          _ayahs = ayahs;
          _chapterInfo = results[results.length - 1] as Map<String, dynamic>?;
          _isLoading = false;
        });

        // Scroll to initial ayah if provided
        if (widget.initialAyah != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToAyah(widget.initialAyah!);
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching ayahs: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showChapterInfo() {
    if (_chapterInfo == null) return;

    var size = MediaQuery.of(context).size;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          bottom: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(size.width * .11),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Text(
                        //   'Surah Information',
                        //   style: GoogleFonts.poppins(
                        //     fontSize: 21,
                        //     fontWeight: FontWeight.w900,
                        //     color: const Color(0xff34da15),
                        //   ),
                        // ),
                        const SizedBox(height: 16),
                        if (_chapterInfo!['chapter_info'] != null &&
                            _chapterInfo!['chapter_info']
                                .toString()
                                .isNotEmpty) ...[
                          Text(
                            'About this Surah',
                            style: GoogleFonts.poppins(
                              fontSize: size.width * .039,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _chapterInfo!['chapter_info'],
                            style: GoogleFonts.poppins(
                              fontSize: size.width * .035,
                              height: 0,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (_chapterInfo!['chapter_virtue'] != null &&
                            _chapterInfo!['chapter_virtue']
                                .toString()
                                .isNotEmpty) ...[
                          Text(
                            'Virtues',
                            style: GoogleFonts.poppins(
                              fontSize: size.width * .039,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          HtmlWidget(
                            _chapterInfo!['chapter_virtue'],
                            textStyle: GoogleFonts.poppins(
                              fontSize: size.width * .035,
                              height: 0,
                            ),
                          ),
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _checkAudioStatus() async {
    final exists = await AudioService().isSurahDownloaded(
      widget.surah['number'],
      widget.surah['numberOfAyahs'],
    );
    if (mounted) {
      setState(() {
        _isAudioDownloaded = exists;
      });
    }
  }

  Future<void> _downloadAudio() async {
    setState(() {
      _isDownloadingAudio = true;
    });
    try {
      await AudioService().downloadSurahAudio(
        widget.surah['number'],
        widget.surah['numberOfAyahs'],
        (progress) {
          if (mounted) setState(() => _downloadProgress = progress);
        },
      );
      if (mounted) {
        setState(() {
          _isAudioDownloaded = true;
          _isDownloadingAudio = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloadingAudio = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  Future<void> _playAyah(int ayahNumber) async {
    try {
      if (_playingAyahId == ayahNumber && !_isAutoPlaying) {
        await _audioPlayer.stop();
        setState(() {
          _playingAyahId = null;
        });
      } else {
        await _audioPlayer.stop();
        final path = await AudioService().getAudioFilePath(
          widget.surah['number'],
          ayahNumber,
        );
        // Using DeviceFileSource for local file
        await _audioPlayer.play(DeviceFileSource(path));
        if (mounted) {
          setState(() {
            _playingAyahId = ayahNumber;
          });
          // Auto-scroll to playing ayah
          _scrollToAyah(ayahNumber);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Playback failed: Audio not downloaded?'),
          ),
        );
      }
    }
  }

  void _scrollToAyah(int ayahNumber) {
    if (_ayahs.isNotEmpty) {
      final arrayIndex = _ayahs.indexWhere(
        (a) => a['numberInSurah'] == ayahNumber,
      );
      if (arrayIndex != -1) {
        try {
          // +1 because list index 0 is the surah header; ayahs start at index 1
          _itemScrollController.jumpTo(index: arrayIndex + 1);
        } catch (e) {
          // ignore scroll errors if controller not attached
        }
      }
    }
  }

  Future<void> _playNextAyah() async {
    if (_playingAyahId == null) return;
    int nextAyah = _playingAyahId! + 1;
    if (nextAyah <= widget.surah['numberOfAyahs']) {
      await _playAyah(nextAyah);
    } else {
      if (mounted) {
        setState(() {
          _playingAyahId = null;
          _isAutoPlaying = false;
        });
      }
    }
  }

  Future<void> _toggleSequentialPlay() async {
    if (_isAutoPlaying) {
      await _audioPlayer.stop();
      if (mounted) {
        setState(() {
          _isAutoPlaying = false;
          _playingAyahId = null;
        });
      }
    } else {
      setState(() {
        _isAutoPlaying = true;
      });
      await _playAyah(1);
    }
  }

  Future<void> _addToBookmark(int surahId, int ayahId) async {
    final folders = await SupabaseService().getFolders();
    final controller = TextEditingController();
    String? selectedFolder;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Bookmark'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (folders.isNotEmpty) ...[
                  const Text('Select Existing Folder:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: folders.map((f) {
                      return ChoiceChip(
                        label: Text(f),
                        selected: selectedFolder == f,
                        onSelected: (selected) {
                          setDialogState(() {
                            selectedFolder = selected ? f : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: controller,
                  onChanged: (val) {
                    if (val.isNotEmpty && selectedFolder != null) {
                      setDialogState(() => selectedFolder = null);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Folder Name (or create new)',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final folder =
                      selectedFolder ??
                      (controller.text.isEmpty ? 'General' : controller.text);
                  await SupabaseService().saveBookmark(folder, surahId, ayahId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bookmark Saved')),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _removeBasmala(String text) {
    const List<String> variations = [
      'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
      'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
      'بِسْمِ اللهِ الرَّحٰنِ الرَّحِيْمِ',
      'بسم الله الرحمن الرحيم',
      'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
    ];
    for (final v in variations) {
      if (text.startsWith(v)) return text.substring(v.length).trim();
    }
    if (text.length > 20 && text.startsWith('بِسْمِ')) {
      final rahimIndex = text.indexOf('الرَّحِيمِ');
      if (rahimIndex != -1 && rahimIndex < 60) {
        return text.substring(rahimIndex + 'الرَّحِيمِ'.length).trim();
      }
    }
    return text;
  }

  String _decodeLatin(String text) {
    if (text.isEmpty) return text;
    // Decoding symbols for Indopak Latin script based on common mapping
    var decoded = text;
    decoded = decoded.replaceAll('\$', 'ā');
    decoded = decoded.replaceAll('%', 'ī');
    decoded = decoded.replaceAll('^', 'ū');
    decoded = decoded.replaceAll('#', 'ṣ');
    decoded = decoded.replaceAll('@', 'dh');
    decoded = decoded.replaceAll('*', 'ḥ');
    decoded = decoded.replaceAll('!', 'ḍ');
    decoded = decoded.replaceAll('~', 'ẓ');
    decoded = decoded.replaceAll('&', 'ṯ');
    decoded = decoded.replaceAll('[', 'ā'); // Add bracket mapping
    decoded = decoded.replaceAll(
      ']',
      '',
    ); // Remove closing bracket if it exists/is silent
    return decoded;
  }

  String _stripHtml(String htmlString) {
    final regExp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(regExp, '').replaceAll('&nbsp;', ' ').trim();
  }

  void _showJumpToVerseDialog() {

    var size = MediaQuery.of(context).size;
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Jump to Verse', style: GoogleFonts.poppins(
          fontSize: size.width * .041, fontWeight: FontWeight.w700
        ),),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            border: InputBorder.none,
            labelText: 'Verse 1-${widget.surah['numberOfAyahs']}',
            labelStyle: GoogleFonts.poppins(fontSize: size.width * .031, color: const Color(0xff34da15), fontWeight: FontWeight.w700),
            hintText: 'Enter verse number',
            hintStyle: GoogleFonts.poppins(fontSize: size.width * .035, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.27))
          ),
          onSubmitted: (_) => _handleJump(context, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(fontSize: size.width * .031, fontWeight: FontWeight.w700),),
          ),
          TextButton(
            onPressed: () => _handleJump(context, controller.text),
            child: Text('Go', style: GoogleFonts.poppins(fontSize: size.width * .031, fontWeight: FontWeight.w700),),
          ),
        ],
      ),
    );
  }

  void _handleJump(BuildContext dialogContext, String text) {
    final verseNum = int.tryParse(text);
    if (verseNum != null &&
        verseNum > 0 &&
        verseNum <= widget.surah['numberOfAyahs']) {
      Navigator.pop(dialogContext); // Close dialog
      // Small delay to ensure dialog is gone before scrolling (optional but good)
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToAyah(verseNum);
      });
    } else {
      // Show invalid input feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a valid verse number (1-${widget.surah['numberOfAyahs']})',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        bool showBasmalaHeader =
            widget.surah['number'] != 1 && widget.surah['number'] != 9;
        final arabicFont = settings.arabicScript == 'utsmani'
            ? 'hafs'
            : 'qalammajeed3';

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: AppBar().preferredSize.height * 1.5,
            titleSpacing: 12,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.surah['englishName'] ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 0,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xff34da15),
                    // border: Border.all(
                    //   color: Theme.of(context)
                    //       .colorScheme
                    //       .primary
                    //       .withValues(alpha: 0.5),
                    // ),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '${widget.surah['revelationType'] ?? ''} · ${widget.surah['numberOfAyahs']} Verses',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                // Text(
                //   '${widget.surah['englishNameTranslation'] ?? ''} · ${widget.surah['numberOfAyahs']} Ayahs',
                //   style: GoogleFonts.poppins(
                //     fontSize: 10,
                //     fontWeight: FontWeight.w500,
                //     color: Theme.of(context).brightness == Brightness.dark
                //         ? Colors.white54
                //         : Colors.black45,
                //     height: 1.3,
                //   ),
                // ),
              ],
            ),
            actions: [
              GestureDetector(
                onTap: () => settings.setIsReadingMode(!settings.isReadingMode),
                child: Icon(
                  settings.isReadingMode
                      ? CupertinoIcons.book_fill
                      : CupertinoIcons.book,
                  color: settings.isReadingMode
                      ? const Color(0xff34da15)
                      : null,
                  size: size.width * .049,
                ),
              ),
              const SizedBox(width: 9),
              GestureDetector(
                onTap: _showJumpToVerseDialog,
                child: Icon(
                  CupertinoIcons.list_bullet_below_rectangle,
                  size: size.width * .049,
                ),
              ),
              const SizedBox(width: 9),
              if (_isDownloadingAudio)
                Padding(
                  padding: const EdgeInsets.all(0.0),
                  child: SizedBox(
                    width: size.width * .039,
                    height: size.width * .039,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Theme.of(context).colorScheme.onSurface,
                      value: _downloadProgress,
                    ),
                  ),
                )
              else if (!_isAudioDownloaded)
                GestureDetector(
                  onTap: _downloadAudio,
                  child: Icon(
                    CupertinoIcons.cloud_download,
                    size: size.width * .049,
                  ),
                )
              else
                GestureDetector(
                  onTap: _toggleSequentialPlay,
                  child: Icon(
                    _isAutoPlaying ? CupertinoIcons.stop : CupertinoIcons.play,
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.black
                        : Colors.white,
                    size: size.width * .049,
                  ),
                ),
              const SizedBox(width: 9),
              if (_chapterInfo != null) ...[
                GestureDetector(
                  onTap: _showChapterInfo,
                  child: Icon(
                    CupertinoIcons.info_circle,
                    size: size.width * .049,
                  ),
                ),
                const SizedBox(width: 9),
              ],
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
                child: Icon(CupertinoIcons.gear, size: size.width * .049),
              ),
            ],
            actionsPadding: EdgeInsets.only(right: size.width * .035),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _ayahs.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'Verse data not found. The database might be incomplete.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              : AutoHideScrollbar(
                  itemPositionsListener: _itemPositionsListener,
                  itemScrollController: _itemScrollController,
                  totalItems: _ayahs.length + 2,
                  child: ScrollablePositionedList.builder(
                    physics: const BouncingScrollPhysics(),
                    itemScrollController: _itemScrollController,
                    itemPositionsListener: _itemPositionsListener,
                    padding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 7,
                    ),
                    itemCount: _ayahs.length + 2,
                    // Header + Ayahs + Bottom Space
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // Surah Header
                        return Column(
                          children: [
                            // Padding(
                            //   padding: const EdgeInsets.only(top: 0, bottom: 8),
                            //   child: Column(
                            //     children: [
                            //       // Large surahname calligraphy centered
                            //       Text(
                            //         'surah${widget.surah['number'].toString().length == 3
                            //             ? widget.surah['number'].toString()
                            //             : widget.surah['number'].toString().length == 2
                            //             ? "0${widget.surah['number']}"
                            //             : "00${widget.surah['number']}"}',
                            //         style: TextStyle(
                            //           fontFamily: 'surahname',
                            //           fontSize: size.width * .13,
                            //           color: Theme.of(
                            //             context,
                            //           ).colorScheme.onSurface,
                            //         ),
                            //         textAlign: TextAlign.center,
                            //       ),
                            //       // const SizedBox(height: 6),
                            //       // Container(
                            //       //   padding: const EdgeInsets.symmetric(
                            //       //     horizontal: 14,
                            //       //     vertical: 5,
                            //       //   ),
                            //       //   decoration: BoxDecoration(
                            //       //     color: Theme.of(context)
                            //       //         .colorScheme
                            //       //         .primary
                            //       //         .withValues(alpha: 0.1),
                            //       //     borderRadius: BorderRadius.circular(1000),
                            //       //     border: Border.all(
                            //       //       color: Theme.of(context)
                            //       //           .colorScheme
                            //       //           .primary
                            //       //           .withValues(alpha: 0.3),
                            //       //     ),
                            //       //   ),
                            //       //   child: Text(
                            //       //     '${widget.surah['revelationType'] ?? ''} · ${widget.surah['numberOfAyahs']} Verses',
                            //       //     style: GoogleFonts.poppins(
                            //       //       fontSize: 11,
                            //       //       fontWeight: FontWeight.w600,
                            //       //       color: Theme.of(context).colorScheme.primary,
                            //       //       letterSpacing: 0.3,
                            //       //       height: 0,
                            //       //     ),
                            //       //   ),
                            //       // ),
                            //       const SizedBox(height: 20),
                            //     ],
                            //   ),
                            // ),
                            if (showBasmalaHeader)
                              Padding(
                                padding: const EdgeInsets.only(top: 17),
                                child: Text(
                                  'g',
                                  style: TextStyle(
                                    fontFamily: 'besmallah',
                                    fontSize: settings.arabicFontSize + 27,
                                    height: 0,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: .35),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            else
                              SizedBox(height: 11),
                          ],
                        );
                      }

                      if (index == _ayahs.length + 1) {
                        return const SizedBox(height: 120);
                      }

                      final ayahIndex = index - 1;
                      final ayah = _ayahs[ayahIndex];
                      final isPlaying =
                          _playingAyahId != null &&
                          ayah['number'] == widget.surah['number'] &&
                          ayah['numberInSurah'] == _playingAyahId;

                      // Handle Basmala stripping
                      String rawText = ayah['text'] ?? '';
                      String displayText =
                          (ayahIndex == 0 && widget.surah['number'] != 1)
                          ? _removeBasmala(rawText)
                          : rawText;

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: AppBar().preferredSize.height * .21,
                        ),
                        child: InkWell(
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          onLongPress: () {
                            _addToBookmark(
                              widget.surah['number'],
                              ayah['numberInSurah'],
                            );
                          },
                          onTap: () => _playAyah(ayah['numberInSurah']),
                          child: Transform.scale(
                            scale: 0.9,
                            alignment: Alignment.center,
                            child: Card(
                              semanticContainer: false,
                              surfaceTintColor: Colors.transparent,
                              color: Colors.transparent,
                              // Removes M3 elevation tint
                              // color: isPlaying
                              //     ? Theme.of(
                              //         context,
                              //       ).colorScheme.primary.withValues(alpha: 0.13)
                              //     : Theme.of(context).brightness ==
                              //           Brightness.light
                              //     ? const Color(0xFFF7F7F7)
                              //     : const Color(0xFF111111),
                              elevation: 0,
                              // shape: RoundedRectangleBorder(
                              //   borderRadius: BorderRadius.circular(20),
                              //   side: isPlaying
                              //       ? BorderSide(
                              //           color: Theme.of(context)
                              //               .colorScheme
                              //               .primary
                              //               .withValues(alpha: 0.6),
                              //           width: 1.5,
                              //         )
                              //       : BorderSide(
                              //           color:
                              //               Theme.of(context).brightness ==
                              //                   Brightness.light
                              //               ? const Color(0xFFEEEEEE)
                              //               : const Color(0xFF222222),
                              //         ),
                              // ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    spacing: 19,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Verse number badge
                                      Wrap(
                                        direction: Axis.vertical,
                                        spacing: 7,
                                        children: [
                                          Container(
                                            width: 29,
                                            height: 29,
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
                                                fontSize: 11,
                                                height: 0,
                                                fontWeight: FontWeight.w900,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.surface,
                                              ),
                                            ),
                                          ),
                                          if (!settings.isReadingMode &&
                                              _isAudioDownloaded)
                                            GestureDetector(
                                              onTap: () => _playAyah(
                                                ayah['numberInSurah'],
                                              ),
                                              child: Container(
                                                width: 29,
                                                height: 29,
                                                decoration: BoxDecoration(
                                                  color: isPlaying
                                                      ? Theme.of(
                                                          context,
                                                        ).colorScheme.primary
                                                      : Theme.of(
                                                              context,
                                                            ).brightness ==
                                                            Brightness.light
                                                      ? Colors.black.withValues(
                                                          alpha: 0.05,
                                                        )
                                                      : Colors.white.withValues(
                                                          alpha: 0.07,
                                                        ),
                                                  border: Border.all(
                                                    width: .35,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(
                                                          alpha: 0.25,
                                                        ),
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        1000,
                                                      ),
                                                ),
                                                child: Center(
                                                  child: Icon(
                                                    isPlaying
                                                        ? CupertinoIcons
                                                              .stop_fill
                                                        : CupertinoIcons
                                                              .play_fill,
                                                    size: 15,
                                                    color: isPlaying
                                                        ? Theme.of(context)
                                                              .colorScheme
                                                              .onSurface
                                                        : const Color(
                                                            0xff34da15,
                                                          ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          if (DatabaseService.isSajdaVerse(
                                            widget.surah['number'] as int,
                                            ayah['numberInSurah'] as int,
                                          ))
                                            SizedBox(
                                              width: 29,
                                              height: 29,
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            settings.enableTajweed
                                                ? RichText(
                                                    textAlign: TextAlign.right,
                                                    textDirection:
                                                        TextDirection.rtl,
                                                    text: TextSpan(
                                                      children: TajweedRenderer.getTajweedSpans(
                                                        displayText.replaceAllMapped(
                                                          RegExp(
                                                            r'([\u06D6-\u06DC])',
                                                          ),
                                                          (match) =>
                                                              '   ${match.group(0)} ',
                                                        ),
                                                        TextStyle(
                                                          fontFamily:
                                                              arabicFont,
                                                          fontSize: settings
                                                              .arabicFontSize,
                                                          height: 1.8,
                                                          wordSpacing: 0,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                        ),
                                                        isIndopak:
                                                            arabicFont ==
                                                            'qalammajeed3',
                                                      ),
                                                    ),
                                                  )
                                                : Text(
                                                    displayText.replaceAllMapped(
                                                      RegExp(
                                                        r'([\u06D6-\u06DC])',
                                                      ),
                                                      (match) =>
                                                          '      ${match.group(0)} ',
                                                    ),
                                                    textAlign: TextAlign.right,
                                                    textDirection:
                                                        TextDirection.rtl,
                                                    style: TextStyle(
                                                      fontFamily: arabicFont,
                                                      fontSize: settings
                                                          .arabicFontSize,
                                                      height: 1.8,
                                                      wordSpacing: 0,
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.onSurface,
                                                    ),
                                                  ),
                                            if (settings.pronunciation !=
                                                    'none' &&
                                                ayah['pronunciation'] !=
                                                    null) ...[
                                              const SizedBox(height: 3),
                                              if (settings.pronunciation ==
                                                  'latin_english')
                                                HtmlWidget(
                                                  '<div style="text-align: end;">${ayah['pronunciation']}</div>',
                                                  textStyle: GoogleFonts.poppins(
                                                    fontSize:
                                                        settings
                                                            .translationFontSize *
                                                        0.75,
                                                    height: 0,
                                                    color: Colors.green,
                                                    fontWeight: FontWeight.w600,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                )
                                              else
                                                Text(
                                                  _decodeLatin(
                                                    ayah['pronunciation'],
                                                  ),
                                                  textAlign: TextAlign.end,
                                                  style: GoogleFonts.poppins(
                                                    fontSize:
                                                        settings
                                                            .translationFontSize *
                                                        0.75,
                                                    height: 0,
                                                    color: Colors.green,
                                                    fontWeight: FontWeight.w600,
                                                    fontStyle: FontStyle.italic,
                                                    letterSpacing: 0.2,
                                                  ),
                                                ),
                                            ],
                                            const SizedBox(height: 0),
                                            if (!settings.isReadingMode &&
                                                settings.showWordByWord &&
                                                ayah['words'] != null) ...[
                                              const SizedBox(height: 16),
                                              Wrap(
                                                alignment: WrapAlignment.start,
                                                direction: Axis.horizontal,
                                                textDirection:
                                                    TextDirection.rtl,
                                                runAlignment:
                                                    WrapAlignment.start,
                                                runSpacing: 7,
                                                spacing: 7,
                                                children: (ayah['words'] as List).map((
                                                  word,
                                                ) {
                                                  return Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 31,
                                                          vertical: 8,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Theme.of(
                                                                context,
                                                              ).brightness ==
                                                              Brightness.light
                                                          ? Colors.black
                                                                .withValues(
                                                                  alpha: 0.03,
                                                                )
                                                          : Colors.white
                                                                .withValues(
                                                                  alpha: 0.05,
                                                                ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            1000,
                                                          ),
                                                      border: Border.all(
                                                        color:
                                                            Theme.of(
                                                                  context,
                                                                ).brightness ==
                                                                Brightness.light
                                                            ? Colors.black
                                                                  .withValues(
                                                                    alpha: 0.07,
                                                                  )
                                                            : Colors.white
                                                                  .withValues(
                                                                    alpha: 0.1,
                                                                  ),
                                                        width: 0,
                                                      ),
                                                    ),
                                                    child: Column(
                                                      children: [
                                                        Text(
                                                          word['arabic'] ?? '',
                                                          style: TextStyle(
                                                            fontFamily:
                                                                arabicFont,
                                                            fontSize:
                                                                size.width *
                                                                .047,
                                                            height: 0,
                                                            fontWeight:
                                                                FontWeight.w900,
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurface,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        if (settings
                                                                .showWbwTransliteration &&
                                                            word['transliteration'] !=
                                                                null &&
                                                            word['transliteration']
                                                                .toString()
                                                                .isNotEmpty) ...[
                                                          const SizedBox(
                                                            height: 0,
                                                          ),
                                                          Text(
                                                            word['transliteration'],
                                                            style: GoogleFonts.poppins(
                                                              fontSize:
                                                                  settings
                                                                      .translationFontSize *
                                                                  0.55,
                                                              fontStyle:
                                                                  FontStyle
                                                                      .italic,
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .tertiary,
                                                            ),
                                                          ),
                                                        ],
                                                        Text(
                                                          word['translation'] ??
                                                              '',
                                                          style: GoogleFonts.poppins(
                                                            fontSize:
                                                                settings
                                                                    .translationFontSize *
                                                                0.6,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .secondary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ],
                                            if (!settings.isReadingMode)
                                              const SizedBox(height: 0),
                                            if (!settings.isReadingMode &&
                                                ayah['translation'] !=
                                                    null) ...[
                                              const SizedBox(height: 17),
                                              Text(
                                                ayah['translation'],
                                                textAlign: TextAlign.left,
                                                style: GoogleFonts.poppins(
                                                  height: 0,
                                                  fontSize: settings
                                                      .translationFontSize,
                                                  color: Theme.of(
                                                    context,
                                                  ).textTheme.bodyLarge?.color,
                                                  fontWeight: FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                            if (!settings.isReadingMode &&
                                                settings.showTafseer &&
                                                ayah['tafseer'] != null) ...[
                                              const SizedBox(height: 17),
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    ayah['isTafseerExpanded'] =
                                                        !(ayah['isTafseerExpanded'] ??
                                                            false);
                                                  });
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    21,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        Theme.of(
                                                              context,
                                                            ).brightness ==
                                                            Brightness.light
                                                        ? Colors.black
                                                              .withValues(
                                                                alpha: 0.03,
                                                              )
                                                        : Colors.white
                                                              .withValues(
                                                                alpha: 0.05,
                                                              ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          31,
                                                        ),
                                                    border: Border.all(
                                                      color:
                                                          Theme.of(
                                                                context,
                                                              ).brightness ==
                                                              Brightness.light
                                                          ? Colors.black
                                                                .withValues(
                                                                  alpha: 0.07,
                                                                )
                                                          : Colors.white
                                                                .withValues(
                                                                  alpha: 0.1,
                                                                ),
                                                      width: 0,
                                                    ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            CupertinoIcons
                                                                .book_fill,
                                                            size: 11,
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .primary,
                                                          ),
                                                          const SizedBox(
                                                            width: 5,
                                                          ),
                                                          Text(
                                                            'Tafseer',
                                                            style: GoogleFonts.poppins(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .primary,
                                                              letterSpacing:
                                                                  0.5,
                                                            ),
                                                          ),
                                                          const Spacer(),
                                                          Icon(
                                                            ayah['isTafseerExpanded'] ==
                                                                    true
                                                                ? CupertinoIcons
                                                                      .chevron_up
                                                                : CupertinoIcons
                                                                      .chevron_down,
                                                            size: 12,
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    ).brightness ==
                                                                    Brightness
                                                                        .light
                                                                ? Colors.black38
                                                                : Colors
                                                                      .white38,
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      (ayah['isTafseerExpanded'] ==
                                                              true)
                                                          ? HtmlWidget(
                                                              ayah['tafseer'],
                                                              textStyle:
                                                                  GoogleFonts.poppins(
                                                                    fontSize:
                                                                        settings
                                                                            .translationFontSize *
                                                                        0.67,
                                                                    height: 0,
                                                                  ),
                                                            )
                                                          : Text(
                                                              ayah['tafseerSnippet'] ??
                                                                  '',
                                                              maxLines: 2,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: GoogleFonts.poppins(
                                                                fontSize:
                                                                    settings
                                                                        .translationFontSize *
                                                                    0.75,
                                                                fontStyle:
                                                                    FontStyle
                                                                        .italic,
                                                                color:
                                                                    Theme.of(
                                                                          context,
                                                                        ).brightness ==
                                                                        Brightness
                                                                            .light
                                                                    ? Colors
                                                                          .black54
                                                                    : Colors
                                                                          .white54,
                                                                height: 1.5,
                                                              ),
                                                            ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      //
                                    ],
                                  ),
                                  const SizedBox(height: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}
