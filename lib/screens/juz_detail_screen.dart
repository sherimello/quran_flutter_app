import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../services/database_service.dart';
import '../services/audio_service.dart';
import '../services/supabase_service.dart';
import '../providers/settings_provider.dart';
import '../data/juz_data.dart';
import 'settings_screen.dart';

class JuzDetailScreen extends StatefulWidget {
  final int juzNumber;

  const JuzDetailScreen({super.key, required this.juzNumber});

  @override
  State<JuzDetailScreen> createState() => _JuzDetailScreenState();
}

class _JuzDetailScreenState extends State<JuzDetailScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<Map<String, dynamic>> _ayahs = [];
  bool _isLoading = true;
  String? _playingAyahId; // Unique ID: "surah:ayah"
  bool _isReadingMode = false;

  bool _isAudioDownloaded = false;
  bool _isDownloadingAudio = false;
  double _downloadProgress = 0.0;
  bool _isAutoPlaying = false;

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  String? _currentScript;
  String? _currentTranslation;
  String? _currentPronunciation;
  bool? _currentShowWordByWord;
  String? _currentWbwLanguage;
  String? _currentWbwTransliteration;
  bool? _currentShowWbwTransliteration;
  bool? _currentShowTafseer;
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
        _currentShowTafseer != settings.showTafseer) {
      _currentScript = settings.arabicScript;
      _currentTranslation = settings.translation;
      _currentPronunciation = settings.pronunciation;
      _currentShowWordByWord = settings.showWordByWord;
      _currentWbwLanguage = settings.wordByWordLanguage;
      _currentWbwTransliteration = settings.wordByWordTransliteration;
      _currentShowWbwTransliteration = settings.showWbwTransliteration;
      _currentShowTafseer = settings.showTafseer;

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

        for (var ayah in surahAyahs) {
          final ayahNum = ayah['numberInSurah'];

          // Check if this verse is within the Juz range
          if (surahNum == startSurah && ayahNum < startVerse) continue;
          if (surahNum == endSurah && ayahNum > endVerse) break;

          ayahs.add(ayah);
        }
      }

      // Fetch Word-by-Word if enabled
      if (settings.showWordByWord) {
        for (var ayah in ayahs) {
          final words = await DatabaseService().getWordByWordForAyah(
            ayah['number'],
            ayah['numberInSurah'],
            language: settings.wordByWordLanguage,
            transliteration: settings.wordByWordTransliteration,
          );
          ayah['words'] = words;
        }
      }

      // Fetch Tafseer if enabled
      if (settings.showTafseer) {
        for (var ayah in ayahs) {
          final tafseer = await DatabaseService().getTafseer(
            ayah['number'],
            ayah['numberInSurah'],
          );
          if (tafseer != null) {
            ayah['tafseer'] = tafseer;
            ayah['tafseerSnippet'] = _stripHtml(tafseer);
            ayah['isTafseerExpanded'] = false;
          }
        }
      }

      if (mounted) {
        setState(() {
          _ayahs = ayahs;
          _juzInfo = juzInfoResult;
          _isLoading = false;
        });
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
      _itemScrollController.scrollTo(
        index: currentIndex + 1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Juz Information',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_juzInfo!['juz_info'] != null &&
                          _juzInfo!['juz_info'].toString().isNotEmpty) ...[
                        const Text(
                          'Background',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _juzInfo!['juz_info'],
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (_juzInfo!['juz_learning'] != null &&
                          _juzInfo!['juz_learning'].toString().isNotEmpty) ...[
                        const Text(
                          'Learning Points',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _juzInfo!['juz_learning'],
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
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
            titleSpacing: 0,
            title: Text(
              'Juz ${widget.juzNumber}',
              style: TextStyle(
                fontSize: size.width * .041,
                fontWeight: FontWeight.w900,
              ),
            ),
            actions: [
              GestureDetector(
                onTap: () => setState(() => _isReadingMode = !_isReadingMode),
                child: Icon(
                  _isReadingMode
                      ? CupertinoIcons.book_fill
                      : CupertinoIcons.book,
                  color: _isReadingMode
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
              const SizedBox(width: 9),
              GestureDetector(
                onTap: _showJumpToVerseDialog,
                child: const Icon(CupertinoIcons.list_bullet_below_rectangle),
              ),
              const SizedBox(width: 9),
              GestureDetector(
                onTap: _showJuzInfo,
                child: const Icon(CupertinoIcons.info_circle),
              ),
              const SizedBox(width: 9),
              if (_isDownloadingAudio)
                Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: SizedBox(
                    width: size.width * .035,
                    height: size.width * .035,
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
                  child: const Icon(CupertinoIcons.cloud_download),
                )
              else
                GestureDetector(
                  onTap: _toggleSequentialPlay,
                  child: Icon(
                    _isAutoPlaying ? CupertinoIcons.stop : CupertinoIcons.play,
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.black
                        : Colors.white,
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
                child: const Icon(CupertinoIcons.gear),
              ),
              const SizedBox(width: 9),
            ],
            actionsPadding: EdgeInsets.only(right: size.width * .035),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ScrollablePositionedList.builder(
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
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'surah${ayah['number'].toString().length == 3
                                          ? ayah['number'].toString()
                                          : ayah['number'].toString().length == 2
                                          ? "0${ayah['number']}"
                                          : "00${ayah['number']}"}',
                                      style: TextStyle(
                                        fontFamily: 'surahname',
                                        fontSize: size.width * .1,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          ayah['surahName'] ??
                                              'Surah ${ayah['number']}',
                                          style: TextStyle(
                                            fontSize: size.width * .045,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                            height: 0,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        Text(
                                          '${ayah['totalVerses'] ?? 0} Verses',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withAlpha(95),
                                            fontWeight: FontWeight.w900,
                                            height: 0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                // const SizedBox(height: 4),
                                // Text(
                                //   '${ayah['totalVerses'] ?? 0} Verses',
                                //   style: TextStyle(
                                //     fontSize: 12,
                                //     color: Theme.of(context).disabledColor,
                                //     fontWeight: FontWeight.w500,
                                //   ),
                                // ),
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
                                fontSize: settings.fontSize + 27,
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
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      borderRadius: BorderRadius.circular(45),
      onLongPress: () {
        if (SupabaseService().currentUser == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Login to bookmark')));
        } else {
          _addToBookmark(ayah['number'], ayah['numberInSurah']);
        }
      },
      onTap: () => _playAyah(ayah['number'], ayah['numberInSurah']),
      child: Card(
        semanticContainer: false,
        surfaceTintColor: Colors.transparent,
        color: isPlaying
            ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
            : Theme.of(context).brightness == Brightness.light
            ? Theme.of(context).colorScheme.primary.withOpacity(0.07)
            : Colors.white.withAlpha(15),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(45)),
        child: Padding(
          padding: const EdgeInsets.all(21.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_isReadingMode)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: size.width * 0.079,
                      height: size.width * 0.071,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        color: Theme.of(context).brightness == Brightness.light
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.1)
                            : Colors.white.withAlpha(15),
                        border: Border.all(
                          width: 1,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.1),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${ayah['numberInSurah']}',
                          style: TextStyle(
                            fontSize: 12,
                            height: 0,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        if (isPlaying) {
                          _audioPlayer.stop();
                          setState(() {
                            _playingAyahId = null;
                            _isAutoPlaying = false;
                          });
                        } else {
                          _playAyah(ayah['surahNumber'], ayah['numberInSurah']);
                        }
                      },
                      icon: Icon(
                        isPlaying
                            ? CupertinoIcons.pause
                            : CupertinoIcons.play_arrow,
                        size: 15,
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.black
                            : Colors.white,
                      ),
                      label: Text(
                        isPlaying ? "Stop" : "Play",
                        style: TextStyle(
                          height: 1.0,
                          fontSize: 13,
                          color:
                              Theme.of(context).brightness == Brightness.light
                              ? Colors.black
                              : Colors.white,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.light
                            ? Colors.black.withOpacity(0.04)
                            : Colors.white.withOpacity(0.08),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                          side: BorderSide(
                            width: .5,
                            color:
                                Theme.of(context).brightness == Brightness.light
                                ? Colors.black.withOpacity(0.15)
                                : Colors.white.withOpacity(0.15),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 11),

              // Arabic text
              Text(
                displayText.replaceAllMapped(
                  RegExp(r'([\u06D6-\u06ED])'),
                  (match) => '${match.group(0)}   \u200C   ',
                ),
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: arabicFont,
                  fontSize: settings.fontSize + 6,
                  height: 1.8,
                  wordSpacing: 0.0,
                ),
              ),

              // Pronunciation
              if (settings.pronunciation != 'none' &&
                  ayah['pronunciation'] != null) ...[
                const SizedBox(height: 8),
                if (settings.pronunciation == 'latin_english')
                  HtmlWidget(
                    '<div style="text-align: end;">${ayah['pronunciation']}</div>',
                    textStyle: TextStyle(
                      fontSize: settings.fontSize * 0.75,
                      color: Theme.of(context).colorScheme.primary,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  Text(
                    _decodeLatin(ayah['pronunciation']),
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: settings.fontSize * 0.75,
                      color: Theme.of(context).colorScheme.primary,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 0.2,
                    ),
                  ),
              ],
              const SizedBox(height: 11),
              // WORD BY WORD UI
              if (!_isReadingMode &&
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
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.black.withOpacity(0.04)
                            : Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(
                          color:
                              Theme.of(context).brightness == Brightness.light
                              ? Colors.black.withOpacity(0.08)
                              : Colors.white.withOpacity(0.12),
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
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (settings.showWbwTransliteration &&
                              word['transliteration'] != null &&
                              word['transliteration']
                                  .toString()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              word['transliteration'],
                              style: TextStyle(
                                fontSize: settings.fontSize * 0.55,
                                fontStyle: FontStyle.italic,
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                            ),
                          ],
                          Text(
                            word['translation'] ?? '',
                            style: TextStyle(
                              fontSize: settings.fontSize * 0.6,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
              if (!_isReadingMode) const SizedBox(height: 11),

              // TRANSLATION
              if (!_isReadingMode && ayah['translation'] != null) ...[
                const SizedBox(height: 11),
                Text(
                  ayah['translation'],
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: settings.fontSize - 4,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],

              // TAFSEER
              if (!_isReadingMode &&
                  settings.showTafseer &&
                  ayah['tafseer'] != null) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      ayah['isTafseerExpanded'] =
                          !(ayah['isTafseerExpanded'] ?? false);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.black.withOpacity(0.04)
                          : Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tafseer:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        (ayah['isTafseerExpanded'] == true)
                            ? HtmlWidget(
                                ayah['tafseer'],
                                textStyle: TextStyle(
                                  fontSize: settings.fontSize * 0.75,
                                ),
                              )
                            : Text(
                                ayah['tafseerSnippet'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: settings.fontSize * 0.75,
                                  fontStyle: FontStyle.italic,
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
      ),
    );
  }
}
