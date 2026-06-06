import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../services/database_service.dart';
import '../services/audio_service.dart';
import '../services/supabase_service.dart';
import '../providers/settings_provider.dart';
import '../data/juz_data.dart';
import '../services/tajweed_service.dart';
import '../widgets/auto_hide_scrollbar.dart';
import 'settings_screen.dart';

class JuzDetailScreen extends StatefulWidget {
  final int juzNumber;
  final int? initialAyahIndex;

  const JuzDetailScreen({
    super.key,
    required this.juzNumber,
    this.initialAyahIndex,
  });

  @override
  State<JuzDetailScreen> createState() => _JuzDetailScreenState();
}

class _JuzDetailScreenState extends State<JuzDetailScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<Map<String, dynamic>> _ayahs = [];
  bool _isLoading = true;
  String? _playingAyahId; // Unique ID: "surah:ayah"

  bool _isAudioDownloaded = false;
  bool _isDownloadingAudio = false;
  double _downloadProgress = 0.0;
  bool _isAutoPlaying = false;

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  Timer? _scrollDebounce;

  String? _currentScript;
  String? _currentTranslation;
  String? _currentPronunciation;
  bool? _currentShowWordByWord;
  String? _currentWbwLanguage;
  String? _currentWbwTransliteration;
  bool? _currentShowWbwTransliteration;
  bool? _currentShowTafseer;
  bool? _currentEnableTajweed;
  Map<String, dynamic>? _juzInfo;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((event) {
      if (!mounted) return;
      if (_isAutoPlaying) {
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
          final topItem = positions
              .where((ItemPosition position) => position.itemTrailingEdge > 0)
              .reduce(
                (min, position) =>
                    position.itemLeadingEdge < min.itemLeadingEdge
                    ? position
                    : min,
              );

          final index = topItem.index;
          if (index >= 0 && index < _ayahs.length) {
            final settings = Provider.of<SettingsProvider>(
              context,
              listen: false,
            );
            settings.saveLastReadJuz(widget.juzNumber, index);
          }
        }
      });
    });

    _checkAudioStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

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

      _fetchJuzVerses();
    }
  }

  Future<void> _fetchJuzVerses() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final juzInfo = juzData[widget.juzNumber - 1];
    final startSurah = juzInfo['start']['surah'];
    final startVerse = juzInfo['start']['verse'];
    final endSurah = juzInfo['end']['surah'];
    final endVerse = juzInfo['end']['verse'];

    try {
      // Fetch Juz Info
      final juzInfoResult = await DatabaseService().getJuzInfo(
        widget.juzNumber,
      );

      List<Map<String, dynamic>> ayahs = [];

      // Fetch verses from start surah to end surah
      for (int surahNum = startSurah; surahNum <= endSurah; surahNum++) {
        final surahAyahs = await DatabaseService().getAyahsForSurah(
          surahNum,
          arabicScript: settings.arabicScript,
          translation: settings.translation,
          pronunciation: settings.pronunciation,
        );

        Map<int, List<Map<String, dynamic>>>? surahWbwData;
        if (settings.showWordByWord) {
          surahWbwData = await DatabaseService().getWordByWordForSurah(
            surahNum,
            language: settings.wordByWordLanguage,
            transliteration: settings.wordByWordTransliteration,
          );
        }

        Map<int, String>? surahTafseerData;
        if (settings.showTafseer) {
          surahTafseerData = await DatabaseService().getTafseersForSurah(
            surahNum,
          );
        }

        for (var ayah in surahAyahs) {
          final ayahNum = ayah['numberInSurah'];

          // Check if this verse is within the Juz range
          if (surahNum == startSurah && ayahNum < startVerse) continue;
          if (surahNum == endSurah && ayahNum > endVerse) break;

          if (settings.showWordByWord && surahWbwData != null) {
            ayah['words'] = surahWbwData[ayahNum];
          }

          if (settings.showTafseer && surahTafseerData != null) {
            final tafseer = surahTafseerData[ayahNum];
            if (tafseer != null) {
              ayah['tafseer'] = tafseer;
              ayah['tafseerSnippet'] = _stripHtml(tafseer);
              ayah['isTafseerExpanded'] = false;
            }
          }

          ayahs.add(ayah);
        }
      }

      if (mounted) {
        setState(() {
          _ayahs = ayahs;
          _juzInfo = juzInfoResult;
          _isLoading = false;
        });

        if (widget.initialAyahIndex != null &&
            widget.initialAyahIndex! < _ayahs.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_itemScrollController.isAttached) {
              _itemScrollController.jumpTo(index: widget.initialAyahIndex!);
            }
          });
        }

        _checkAudioStatus();
      }
    } catch (e) {
      print("Error fetching juz verses: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkAudioStatus() async {
    if (_ayahs.isEmpty) return;

    // For Juz, we consider it "downloaded" only if all Surahs in it are downloaded
    final surahNumbers = _ayahs
        .map((e) => e['surahNumber'] as int)
        .toSet()
        .toList();

    bool allDownloaded = true;
    for (var sn in surahNumbers) {
      final surahInfo = await DatabaseService().getSurahByNumber(sn);
      if (surahInfo == null) continue;
      final downloaded = await AudioService().isSurahDownloaded(
        sn,
        surahInfo['numberOfAyahs'],
      );
      if (!downloaded) {
        allDownloaded = false;
        break;
      }
    }

    if (mounted) {
      setState(() {
        _isAudioDownloaded = allDownloaded;
      });
    }
  }

  Future<void> _downloadAudio() async {
    if (_isDownloadingAudio) return;

    setState(() {
      _isDownloadingAudio = true;
      _downloadProgress = 0.0;
    });

    try {
      final surahNumbers = _ayahs
          .map((e) => e['surahNumber'] as int)
          .toSet()
          .toList();
      int totalSurahs = surahNumbers.length;
      int completedSurahs = 0;

      for (var sn in surahNumbers) {
        final surahInfo = await DatabaseService().getSurahByNumber(sn);
        if (surahInfo == null) continue;

        await AudioService().downloadSurahAudio(
          sn,
          surahInfo['numberOfAyahs'],
          (p) {
            if (mounted) {
              setState(() {
                _downloadProgress = (completedSurahs + p) / totalSurahs;
              });
            }
          },
        );
        completedSurahs++;
      }

      if (mounted) {
        setState(() {
          _isAudioDownloaded = true;
          _isDownloadingAudio = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Juz Audio Downloaded')));
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

  void _toggleSequentialPlay() {
    if (_isAutoPlaying) {
      _audioPlayer.stop();
      setState(() {
        _isAutoPlaying = false;
        _playingAyahId = null;
      });
    } else {
      setState(() => _isAutoPlaying = true);
      // Start from first visible or first ayah
      _playAyah(_ayahs[0]['surahNumber'], _ayahs[0]['numberInSurah']);
    }
  }

  void _playNextAyah() {
    if (_playingAyahId == null) return;

    final parts = _playingAyahId!.split(':');
    final sNum = int.parse(parts[0]);
    final aNum = int.parse(parts[1]);

    int currentIndex = _ayahs.indexWhere(
      (a) => a['surahNumber'] == sNum && a['numberInSurah'] == aNum,
    );

    if (currentIndex != -1 && currentIndex < _ayahs.length - 1) {
      final next = _ayahs[currentIndex + 1];
      _playAyah(next['surahNumber'], next['numberInSurah']);

      // Auto scroll
      _itemScrollController.jumpTo(index: currentIndex + 1);
    } else {
      setState(() => _isAutoPlaying = false);
    }
  }

  Future<void> _playAyah(int surahNumber, int ayahNumber) async {
    try {
      if (!_isAutoPlaying) {
        await _audioPlayer.stop();
      }

      final path = await AudioService().getAudioFilePath(
        surahNumber,
        ayahNumber,
      );
      await _audioPlayer.play(DeviceFileSource(path));
      if (mounted) {
        setState(() {
          _playingAyahId = "$surahNumber:$ayahNumber";
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Audio not available')));
        if (_isAutoPlaying) {
          _playNextAyah(); // Skip to next if failed
        }
      }
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
                  if (mounted) {
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

  void _showJumpToVerseDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Jump to Verse'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Verse 1-${_ayahs.length}',
            hintText: 'Enter sequence number in Juz',
          ),
          onSubmitted: (_) => _handleJump(context, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => _handleJump(context, controller.text),
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  void _handleJump(BuildContext dialogContext, String text) {
    final verseNum = int.tryParse(text);
    if (verseNum != null && verseNum > 0 && verseNum <= _ayahs.length) {
      Navigator.pop(dialogContext);
      _itemScrollController.jumpTo(index: verseNum - 1);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid verse number')));
    }
  }

  void _showJuzInfo() {
    if (_juzInfo == null) return;

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
                        const SizedBox(height: 16),
                        if (_juzInfo!['juz_info'] != null &&
                            _juzInfo!['juz_info'].toString().isNotEmpty) ...[
                          Text(
                            'Background',
                            style: GoogleFonts.poppins(
                              fontSize: size.width * .039,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _juzInfo!['juz_info'],
                            style: GoogleFonts.poppins(
                              fontSize: size.width * .035,
                              height: 0,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (_juzInfo!['juz_learning'] != null &&
                            _juzInfo!['juz_learning']
                                .toString()
                                .isNotEmpty) ...[
                          Text(
                            'Learning Points',
                            style: GoogleFonts.poppins(
                              fontSize: size.width * .039,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _juzInfo!['juz_learning'],
                            style: GoogleFonts.poppins(
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

  String _decodeLatin(String text) {
    if (text.isEmpty) return text;
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
    decoded = decoded.replaceAll('[', 'ā');
    decoded = decoded.replaceAll(']', '');
    return decoded;
  }

  String _stripHtml(String htmlString) {
    final regExp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(regExp, '').replaceAll('&nbsp;', ' ').trim();
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
                  'Juz ${widget.juzNumber}',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 0,
                  ),
                ),
                if (!_isLoading && _ayahs.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff34da15),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '${_ayahs.length} Verses',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
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
              GestureDetector(
                onTap: _showJuzInfo,
                child: Icon(
                  CupertinoIcons.info_circle,
                  size: size.width * .049,
                ),
              ),
              const SizedBox(width: 9),
              if (_isDownloadingAudio)
                Padding(
                  padding: const EdgeInsets.all(5.0),
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
              const SizedBox(width: 9),
            ],
            actionsPadding: EdgeInsets.only(right: size.width * .035),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : AutoHideScrollbar(
                  itemPositionsListener: _itemPositionsListener,
                  itemScrollController: _itemScrollController,
                  totalItems: _ayahs.length,
                  child: ScrollablePositionedList.builder(
                  physics: const BouncingScrollPhysics(),
                  itemScrollController: _itemScrollController,
                  itemPositionsListener: _itemPositionsListener,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  itemCount: _ayahs.length,
                  itemBuilder: (context, index) {
                    final ayah = _ayahs[index];
                    final isPlaying =
                        _playingAyahId ==
                        "${ayah['surahNumber']}:${ayah['numberInSurah']}";

                    String rawText = ayah['text'] ?? '';
                    String displayText = rawText;

                    // Show Basmala header when a new Surah starts (except Surah 1 and 9)
                    final isNewSurah =
                        index == 0 ||
                        (index > 0 &&
                            _ayahs[index - 1]['number'] != ayah['number']);
                    final showBasmala =
                        isNewSurah &&
                        ayah['number'] != 1 &&
                        ayah['number'] != 9 &&
                        ayah['numberInSurah'] == 1;

                    var size = MediaQuery.of(context).size;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Surah header when new surah starts
                        if (isNewSurah) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 16, bottom: 8),
                            child: Column(
                              children: [
                                Text(
                                  'surah${ayah['number'].toString().length == 3
                                      ? ayah['number'].toString()
                                      : ayah['number'].toString().length == 2
                                      ? "0${ayah['number']}"
                                      : "00${ayah['number']}"}',
                                  style: TextStyle(
                                    fontFamily: 'surahname',
                                    fontSize: size.width * .11,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 0),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      ayah['surahName'] ?? 'Surah ${ayah['number']}',
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
                                        '${DatabaseService.revelationType(ayah['number'] as int)} · ${ayah['totalVerses'] ?? 0} Verses',
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
                                // Container(
                                //   padding: const EdgeInsets.symmetric(
                                //     horizontal: 14,
                                //     vertical: 5,
                                //   ),
                                //   decoration: BoxDecoration(
                                //     color: Theme.of(context)
                                //         .colorScheme
                                //         .primary
                                //         .withValues(alpha: 0.1),
                                //     borderRadius: BorderRadius.circular(1000),
                                //     border: Border.all(
                                //       color: Theme.of(context)
                                //           .colorScheme
                                //           .primary
                                //           .withValues(alpha: 0.3),
                                //     ),
                                //   ),
                                //   child: Text(
                                //     '${DatabaseService.revelationType(ayah['number'] as int)} · ${ayah['totalVerses'] ?? 0} Verses',
                                //     style: GoogleFonts.poppins(
                                //       fontSize: 11,
                                //       fontWeight: FontWeight.w600,
                                //       color: Theme.of(context).colorScheme.primary,
                                //       letterSpacing: 0.3,
                                //       height: 0,
                                //     ),
                                //   ),
                                // ),
                                const SizedBox(height: 17),
                              ],
                            ),
                          ),
                        ],

                        // Basmala header
                        if (showBasmala)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 0),
                            child: Text(
                              'g',
                              style: TextStyle(
                                fontFamily: 'besmallah',
                                fontSize: settings.arabicFontSize + 27,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        // Verse card
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: buildVerseCard(
                            context,
                            ayah,
                            isPlaying,
                            displayText,
                            arabicFont,
                            settings,
                            size,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
        );
      },
    );
  }

  Widget buildVerseCard(
    BuildContext context,
    Map<String, dynamic> ayah,
    bool isPlaying,
    String displayText,
    String arabicFont,
    SettingsProvider settings,
    Size size,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: InkWell(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        onLongPress: () => _addToBookmark(ayah['number'], ayah['numberInSurah']),
        onTap: () {
          if (_isAudioDownloaded) {
            _playAyah(ayah['surahNumber'], ayah['numberInSurah']);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please download the audio for this Juz first'),
              ),
            );
          }
        },
        child: Transform.scale(
          scale: 0.9,
          child: Card(
            semanticContainer: false,
            surfaceTintColor: Colors.transparent,
            color: Colors.transparent,
            elevation: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  spacing: 19,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: verse number blob + audio button
                    Wrap(
                      direction: Axis.vertical,
                      spacing: 7,
                      children: [
                        Container(
                          width: 29,
                          height: 29,
                          margin: EdgeInsets.only(top: 14.5),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(size.width * .65),
                              bottomLeft: Radius.circular(size.width * .5),
                              topRight: Radius.circular(size.width * .75),
                              bottomRight: Radius.circular(size.width * .75),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${ayah['numberInSurah']}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              height: 0,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).colorScheme.surface,
                            ),
                          ),
                        ),
                        if (!settings.isReadingMode && _isAudioDownloaded)
                          GestureDetector(
                            onTap: () {
                              if (isPlaying) {
                                _audioPlayer.stop();
                                setState(() {
                                  _playingAyahId = null;
                                  _isAutoPlaying = false;
                                });
                              } else {
                                _playAyah(
                                  ayah['surahNumber'],
                                  ayah['numberInSurah'],
                                );
                              }
                            },
                            child: Container(
                              width: 29,
                              height: 29,
                              decoration: BoxDecoration(
                                color: isPlaying
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).brightness ==
                                            Brightness.light
                                    ? Colors.black.withValues(alpha: 0.05)
                                    : Colors.white.withValues(alpha: 0.07),
                                border: Border.all(
                                  width: .35,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.25),
                                ),
                                borderRadius: BorderRadius.circular(1000),
                              ),
                              child: Center(
                                child: Icon(
                                  isPlaying
                                      ? CupertinoIcons.stop_fill
                                      : CupertinoIcons.play_fill,
                                  size: 15,
                                  color: isPlaying
                                      ? Theme.of(context).colorScheme.onSurface
                                      : const Color(0xff34da15),
                                ),
                              ),
                            ),
                          ),
                        if (DatabaseService.isSajdaVerse(
                          ayah['surahNumber'] as int,
                          ayah['numberInSurah'] as int,
                        ))
                          SizedBox(
                            width: 29,
                            height: 29,
                            child: Image.asset(
                              'assets/images/sujood.png',
                              fit: BoxFit.contain,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                      ],
                    ),

                    // Right: arabic + everything else
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Arabic text
                          settings.enableTajweed
                              ? RichText(
                                  textAlign: TextAlign.right,
                                  textDirection: TextDirection.rtl,
                                  text: TextSpan(
                                    children: TajweedRenderer.getTajweedSpans(
                                      displayText.replaceAllMapped(
                                        RegExp(r'([\u06D6-\u06DC])'),
                                        (match) => '   ${match.group(0)} ',
                                      ),
                                      TextStyle(
                                        fontFamily: arabicFont,
                                        fontSize: settings.arabicFontSize,
                                        height: 1.8,
                                        wordSpacing: 0,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                      isIndopak: arabicFont == 'qalammajeed3',
                                    ),
                                  ),
                                )
                              : Text(
                                  displayText.replaceAllMapped(
                                    RegExp(r'([\u06D6-\u06DC])'),
                                    (match) => '      ${match.group(0)} ',
                                  ),
                                  textAlign: TextAlign.right,
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(
                                    fontFamily: arabicFont,
                                    fontSize: settings.arabicFontSize,
                                    height: 1.8,
                                    wordSpacing: 0,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),

                          // Pronunciation
                          if (settings.pronunciation != 'none' &&
                              ayah['pronunciation'] != null) ...[
                            const SizedBox(height: 3),
                            if (settings.pronunciation == 'latin_english')
                              HtmlWidget(
                                '<div style="text-align: end;">${ayah['pronunciation']}</div>',
                                textStyle: GoogleFonts.poppins(
                                  fontSize: settings.translationFontSize * 0.75,
                                  height: 0,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            else
                              Text(
                                _decodeLatin(ayah['pronunciation']),
                                textAlign: TextAlign.end,
                                style: GoogleFonts.poppins(
                                  fontSize: settings.translationFontSize * 0.75,
                                  height: 0,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: 0.2,
                                ),
                              ),
                          ],

                          // Word-by-word
                          if (!settings.isReadingMode &&
                              settings.showWordByWord &&
                              ayah['words'] != null) ...[
                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.start,
                              direction: Axis.horizontal,
                              textDirection: TextDirection.rtl,
                              runAlignment: WrapAlignment.start,
                              runSpacing: 7,
                              spacing: 7,
                              children: (ayah['words'] as List).map((word) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 31,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness ==
                                            Brightness.light
                                        ? Colors.black.withValues(alpha: 0.03)
                                        : Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(1000),
                                    border: Border.all(
                                      color: Theme.of(context).brightness ==
                                              Brightness.light
                                          ? Colors.black.withValues(alpha: 0.07)
                                          : Colors.white.withValues(alpha: 0.1),
                                      width: 0,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        word['arabic'] ?? '',
                                        style: TextStyle(
                                          fontFamily: arabicFont,
                                          fontSize: size.width * .047,
                                          height: 0,
                                          fontWeight: FontWeight.w900,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (settings.showWbwTransliteration &&
                                          word['transliteration'] != null &&
                                          word['transliteration']
                                              .toString()
                                              .isNotEmpty) ...[
                                        Text(
                                          word['transliteration'],
                                          style: GoogleFonts.poppins(
                                            fontSize:
                                                settings.translationFontSize *
                                                0.55,
                                            fontStyle: FontStyle.italic,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.tertiary,
                                          ),
                                        ),
                                      ],
                                      Text(
                                        word['translation'] ?? '',
                                        style: GoogleFonts.poppins(
                                          fontSize:
                                              settings.translationFontSize *
                                              0.6,
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],

                          // Translation
                          if (!settings.isReadingMode &&
                              ayah['translation'] != null) ...[
                            const SizedBox(height: 17),
                            Text(
                              ayah['translation'],
                              textAlign: TextAlign.left,
                              style: GoogleFonts.poppins(
                                height: 0,
                                fontSize: settings.translationFontSize,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],

                          // Tafseer
                          if (!settings.isReadingMode &&
                              settings.showTafseer &&
                              ayah['tafseer'] != null) ...[
                            const SizedBox(height: 17),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  ayah['isTafseerExpanded'] =
                                      !(ayah['isTafseerExpanded'] ?? false);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(21),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness ==
                                          Brightness.light
                                      ? Colors.black.withValues(alpha: 0.03)
                                      : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(31),
                                  border: Border.all(
                                    color: Theme.of(context).brightness ==
                                            Brightness.light
                                        ? Colors.black.withValues(alpha: 0.07)
                                        : Colors.white.withValues(alpha: 0.1),
                                    width: 0,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          CupertinoIcons.book_fill,
                                          size: 11,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Tafseer',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(
                                          ayah['isTafseerExpanded'] == true
                                              ? CupertinoIcons.chevron_up
                                              : CupertinoIcons.chevron_down,
                                          size: 12,
                                          color: Theme.of(context).brightness ==
                                                  Brightness.light
                                              ? Colors.black38
                                              : Colors.white38,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ayah['isTafseerExpanded'] == true
                                        ? HtmlWidget(
                                            ayah['tafseer'],
                                            textStyle: GoogleFonts.poppins(
                                              fontSize:
                                                  settings.translationFontSize *
                                                  0.67,
                                              height: 0,
                                            ),
                                          )
                                        : Text(
                                            ayah['tafseerSnippet'] ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.poppins(
                                              fontSize:
                                                  settings.translationFontSize *
                                                  0.75,
                                              fontStyle: FontStyle.italic,
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.light
                                                  ? Colors.black54
                                                  : Colors.white54,
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
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
