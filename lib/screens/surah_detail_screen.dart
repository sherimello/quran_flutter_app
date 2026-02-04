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

  // The Header Text (Always shown as standard Uthmani)
  static const String _basmalaHeader = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

  // Track settings to detect changes
  String? _currentScript;
  String? _currentTranslation;
  String? _currentPronunciation;
  bool? _currentShowWordByWord;

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
        _currentShowWordByWord != settings.showWordByWord) {
      _currentScript = settings.arabicScript;
      _currentTranslation = settings.translation;
      _currentPronunciation = settings.pronunciation;
      _currentShowWordByWord = settings.showWordByWord;

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
        );
      }

      // 3. Fetch Tafseer if enabled
      Future<Map<int, String>>? tafseerFuture;
      if (settings.showTafseer) {
        tafseerFuture = DatabaseService().getTafseersForSurah(
          widget.surah['number'],
        );
      }

      final results = await Future.wait([
        ayahsFuture,
        if (wbwFuture != null) wbwFuture,
        if (tafseerFuture != null) tafseerFuture,
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

        // Add Word-by-Word
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
      print("Error fetching ayahs: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playback failed: Audio not downloaded?')),
      );
    }
  }

  void _scrollToAyah(int ayahNumber) {
    if (_ayahs.isNotEmpty) {
      final index = _ayahs.indexWhere((a) => a['numberInSurah'] == ayahNumber);
      if (index != -1) {
        try {
          _itemScrollController.scrollTo(
            index: index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
          );
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
            labelText: 'Verse 1-${widget.surah['numberOfAyahs']}',
            hintText: 'Enter verse number',
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        bool showBasmalaHeader =
            widget.surah['number'] != 1 && widget.surah['number'] != 9;
        final arabicFont = settings.arabicScript == 'utsmani'
            ? 'hafs'
            : 'qalammajeed3';

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.surah['englishName']),
            actions: [
              IconButton(
                icon: const Icon(Icons.format_list_numbered),
                tooltip: 'Jump to Verse',
                onPressed: _showJumpToVerseDialog,
              ),
              if (_isDownloadingAudio)
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(value: _downloadProgress),
                )
              else if (!_isAudioDownloaded)
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: _downloadAudio,
                )
              else
                IconButton(
                  icon: Icon(
                    _isAutoPlaying ? Icons.pause_circle : Icons.play_circle,
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.black
                        : Colors.white,
                  ),
                  onPressed: _toggleSequentialPlay,
                ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Basmala Header
                    if (showBasmalaHeader)
                      Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 8),
                        child: Text(
                          _basmalaHeader,
                          style: TextStyle(
                            fontFamily: arabicFont,
                            fontSize: settings.fontSize + 8,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Ayah List
                    Expanded(
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
                              _playingAyahId == ayah['numberInSurah'];

                          // Handle Basmala stripping
                          String rawText = ayah['text'] ?? '';
                          String displayText =
                              (index == 0 && widget.surah['number'] != 1)
                              ? _removeBasmala(rawText)
                              : rawText;

                          var size = MediaQuery.of(context).size;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: InkWell(
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              borderRadius: BorderRadius.circular(45),
                              onLongPress: () {
                                if (SupabaseService().currentUser == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Login to bookmark'),
                                    ),
                                  );
                                } else {
                                  _addToBookmark(
                                    widget.surah['number'],
                                    ayah['numberInSurah'],
                                  );
                                }
                              },
                              onTap: () => _playAyah(ayah['numberInSurah']),
                              child: Card(
                                semanticContainer: false,
                                surfaceTintColor: Colors
                                    .transparent, // Removes M3 elevation tint
                                color: isPlaying
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.12)
                                    : Theme.of(context).brightness ==
                                          Brightness.light
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.07)
                                    : Colors.white.withAlpha(15),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(45),
                                ),

                                child: Padding(
                                  padding: const EdgeInsets.all(21.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            width: size.width * 0.079,
                                            height: size.width * 0.071,
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(7),
                                              color:
                                                  Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.light
                                                  ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                        .withOpacity(0.07)
                                                  : Colors.white.withAlpha(15),
                                              border: Border.all(
                                                width: 1,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${ayah['numberInSurah']}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  height: 0,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onPrimaryContainer,
                                                ),
                                              ),
                                            ),
                                          ),

                                          // CircleAvatar(
                                          //   radius: 14,
                                          //   backgroundColor: Theme.of(
                                          //     context,
                                          //   ).colorScheme.primaryContainer,
                                          //   child: Text(
                                          //     '${ayah['numberInSurah']}',
                                          //     style: TextStyle(
                                          //       fontSize: 12,
                                          //       color: Theme.of(context)
                                          //           .colorScheme
                                          //           .onPrimaryContainer,
                                          //     ),
                                          //   ),
                                          // ),
                                          if (_isAudioDownloaded)
                                            TextButton.icon(
                                              onPressed: () {
                                                _playAyah(
                                                  ayah['numberInSurah'],
                                                );
                                              },
                                              icon: Icon(
                                                isPlaying
                                                    ? CupertinoIcons.pause
                                                    : CupertinoIcons.play_arrow,
                                                size: 15,
                                                color:
                                                    Theme.of(
                                                          context,
                                                        ).brightness ==
                                                        Brightness.light
                                                    ? Colors.black
                                                    : Colors.white,
                                              ),
                                              label: Text(
                                                isPlaying ? "Stop" : "Play",
                                                style: TextStyle(
                                                  height: 1.0,
                                                  fontSize: 13,
                                                  color:
                                                      Theme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.light
                                                      ? Colors.black
                                                      : Colors.white,
                                                ),
                                              ),
                                              style: TextButton.styleFrom(
                                                backgroundColor:
                                                    Theme.of(
                                                          context,
                                                        ).brightness ==
                                                        Brightness.light
                                                    ? Colors.black.withOpacity(
                                                        0.04,
                                                      )
                                                    : Colors.white.withOpacity(
                                                        0.08,
                                                      ),
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 4,
                                                    ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        100,
                                                      ),
                                                  side: BorderSide(
                                                    width: .5,
                                                    color:
                                                        Theme.of(
                                                              context,
                                                            ).brightness ==
                                                            Brightness.light
                                                        ? Colors.black
                                                              .withOpacity(0.15)
                                                        : Colors.white
                                                              .withOpacity(
                                                                0.15,
                                                              ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 11),
                                      // Row: number and actions
                                      Text(
                                        displayText.replaceAllMapped(
                                          RegExp(r'([\u06D6-\u06ED])'),
                                          (match) =>
                                              '${match.group(0)} \u200C ',
                                        ),
                                        // .replaceAll(
                                        //   RegExp(r'\s+'),
                                        //   '   \u200C   ',
                                        // ),
                                        textAlign: TextAlign.right,
                                        textDirection: TextDirection.rtl,
                                        style: TextStyle(
                                          fontFamily: arabicFont,
                                          fontSize: settings.fontSize + 6,
                                          height: 1.8,
                                          wordSpacing:
                                              0.0, // Ensure words don't visually merge
                                        ),
                                      ),


                                      // TRANSLITERATION
                                      if (settings.pronunciation != 'none' &&
                                          ayah['pronunciation'] != null) ...[
                                        const SizedBox(height: 8),
                                        if (settings.pronunciation ==
                                            'latin_english')
                                          HtmlWidget(
                                            '<div style="text-align: end;">${ayah['pronunciation']}</div>',
                                            textStyle: TextStyle(
                                              fontSize:
                                              settings.fontSize * 0.75,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          )
                                        else
                                          Text(
                                            _decodeLatin(ayah['pronunciation']),
                                            textAlign: TextAlign.end,
                                            style: TextStyle(
                                              fontSize:
                                              settings.fontSize * 0.75,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              fontStyle: FontStyle.italic,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                      ],
                                      // WORD BY WORD UI
                                      if (settings.showWordByWord &&
                                          ayah['words'] != null) ...[
                                        const SizedBox(height: 16),
                                        Wrap(
                                          alignment: WrapAlignment.start,
                                          direction: Axis.horizontal,
                                          textDirection: TextDirection.rtl,
                                          runAlignment: WrapAlignment.start,
                                          runSpacing: 7,
                                          spacing: 7,
                                          children: (ayah['words'] as List).map((
                                            word,
                                          ) {
                                            return Container(
                                              // margin:
                                              //     const EdgeInsets.symmetric(
                                              //       horizontal: 4,
                                              //     ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 11,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    Theme.of(
                                                          context,
                                                        ).brightness ==
                                                        Brightness.light
                                                    ? Colors.black.withOpacity(
                                                        0.04,
                                                      )
                                                    : Colors.white.withOpacity(
                                                        0.07,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(19),
                                                border: Border.all(
                                                  color:
                                                      Theme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.light
                                                      ? Colors.black
                                                            .withOpacity(0.08)
                                                      : Colors.white
                                                            .withOpacity(0.12),
                                                ),
                                              ),
                                              child: Column(
                                                children: [
                                                  Text(
                                                    word['arabic'] ?? '',
                                                    style: TextStyle(
                                                      fontFamily: arabicFont,
                                                      fontSize:
                                                          settings.fontSize + 2,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.onSurface,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    word['translation'] ?? '',
                                                    style: TextStyle(
                                                      fontSize:
                                                          settings.fontSize *
                                                          0.6,
                                                      fontWeight:
                                                          FontWeight.w900,
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

                                      // TRANSLATION
                                      if (ayah['translation'] != null) ...[
                                        const SizedBox(height: 11),
                                        Text(
                                          ayah['translation'],
                                          textAlign: TextAlign.left,
                                          style: TextStyle(
                                            fontSize: settings.fontSize * 0.85,
                                            color: Theme.of(
                                              context,
                                            ).textTheme.bodyLarge?.color,
                                          ),
                                        ),
                                      ],

                                      // TAFSEER
                                      if (settings.showTafseer &&
                                          ayah['tafseer'] != null) ...[
                                        const SizedBox(height: 12),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              ayah['isTafseerExpanded'] =
                                                  !(ayah['isTafseerExpanded'] ??
                                                      false);
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(17),
                                            decoration: BoxDecoration(
                                              color:
                                                  Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.light
                                                  ? Colors.black.withOpacity(
                                                      0.04,
                                                    )
                                                  : Colors.white.withOpacity(
                                                      0.07,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(17),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Tafseer:',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                (ayah['isTafseerExpanded'] ==
                                                        true)
                                                    ? HtmlWidget(
                                                        ayah['tafseer'],
                                                        textStyle: TextStyle(
                                                          fontSize:
                                                              settings
                                                                  .fontSize *
                                                              0.75,
                                                        ),
                                                      )
                                                    : Text(
                                                        ayah['tafseerSnippet'] ??
                                                            '',
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize:
                                                              settings
                                                                  .fontSize *
                                                              0.75,
                                                          fontStyle:
                                                              FontStyle.italic,
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
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
