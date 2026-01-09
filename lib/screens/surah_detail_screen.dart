import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/audio_service.dart';
import '../services/supabase_service.dart';
import '../providers/settings_provider.dart';
import 'auth_screen.dart';

class SurahDetailScreen extends StatefulWidget {
  final Map<String, dynamic> surah;

  const SurahDetailScreen({super.key, required this.surah});

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

  @override
  void initState() {
    super.initState();
    _fetchAyahs();

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        if (_isAutoPlaying && _playingAyahId != null) {
          _playNextAyah();
        } else {
          setState(() {
            _playingAyahId = null;
          });
        }
      }
    });
  }

  Future<void> _fetchAyahs() async {
    final ayahs = await DatabaseService().getAyahsForSurah(
      widget.surah['number'],
    );
    if (mounted) {
      setState(() {
        _ayahs = ayahs;
        _isLoading = false;
      });
      _checkAudioStatus();
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
      if (_playingAyahId == ayahNumber) {
        await _audioPlayer.stop();
        setState(() {
          _playingAyahId = null;
          _isAutoPlaying = false;
        });
      } else {
        await _audioPlayer.stop();
        final path = await AudioService().getAudioFilePath(
          widget.surah['number'],
          ayahNumber,
        );
        await _audioPlayer.play(DeviceFileSource(path));
        setState(() {
          _playingAyahId = ayahNumber;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playback failed: Audio not downloaded?')),
      );
    }
  }

  Future<void> _playNextAyah() async {
    if (_playingAyahId == null) return;

    int nextAyah = _playingAyahId! + 1;
    if (nextAyah <= widget.surah['numberOfAyahs']) {
      await _playAyah(nextAyah);
    } else {
      setState(() {
        _playingAyahId = null;
        _isAutoPlaying = false;
      });
    }
  }

  Future<void> _toggleSequentialPlay() async {
    if (_isAutoPlaying) {
      await _audioPlayer.stop();
      setState(() {
        _isAutoPlaying = false;
        _playingAyahId = null;
      });
    } else {
      setState(() {
        _isAutoPlaying = true;
      });
      // Start from the first ayah if nothing is playing or if we were playing something else
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  const Text('Or Create New:'),
                ],
                TextField(
                  controller: controller,
                  onChanged: (val) {
                    if (val.isNotEmpty && selectedFolder != null) {
                      setDialogState(() => selectedFolder = null);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Folder Name (e.g. Favorites)',
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
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.surah['englishName']),
            actions: [
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
                  ),
                  tooltip: _isAutoPlaying ? 'Stop All' : 'Play All',
                  onPressed: _toggleSequentialPlay,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Bismillah Heading (Except Surah 1 and Surah 9 which doesn't have it)
                    if (widget.surah['number'] != 1 &&
                        _ayahs.isNotEmpty &&
                        _ayahs[0]['text'].toString().contains(
                          'بِسْمِ اللَّهِ الرَّحْشَنِ الرَّحِيمِ',
                        ))
                      Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 16),
                        child: Text(
                          'بِسْمِ اللَّهِ الرَّحْشَنِ الرَّحِيمِ',
                          style: TextStyle(
                            fontFamily: 'qalammajeed3',
                            fontSize: settings.fontSize + 8,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 21,
                        ),
                        itemCount: _ayahs.length,
                        itemBuilder: (context, index) {
                          final ayah = Map<String, dynamic>.from(_ayahs[index]);
                          final isPlaying =
                              _playingAyahId == ayah['numberInSurah'];

                          // Strip Bismillah from verse 1 for display (Except Surah 1)
                          if (widget.surah['number'] != 1 &&
                              index == 0 &&
                              ayah['text'].startsWith(
                                'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
                              )) {
                            ayah['text'] = ayah['text']
                                .replaceFirst(
                                  'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
                                  '',
                                )
                                .trim();
                            // If only Bismillah was there (e.g. Surah 9? No, Surah 9 has nothing,
                            // but some APIs might have it separately. In Uthmani, it's prefix).
                            if (ayah['text'].isEmpty)
                              return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5.5),
                            child: InkWell(
                              onTap: () => _playAyah(ayah['numberInSurah']),
                              onLongPress: () {
                                if (SupabaseService().currentUser == null) {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Login Required'),
                                      content: const Text(
                                        'Please login to save bookmarks.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const AuthScreen(),
                                              ),
                                            );
                                          },
                                          child: const Text('Login'),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  _addToBookmark(
                                    widget.surah['number'],
                                    ayah['numberInSurah'],
                                  );
                                }
                              },
                              child: Row(
                                spacing: 11,
                                children: [
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      if (_isAudioDownloaded && isPlaying)
                                        IconButton(
                                          icon: Icon(
                                            isPlaying
                                                ? Icons.pause_circle
                                                : Icons.play_circle,
                                          ),
                                          onPressed: () =>
                                              _playAyah(ayah['numberInSurah']),
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer,
                                        )
                                      else
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer,
                                          child: Text(
                                            '${ayah['numberInSurah']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer,
                                              fontWeight: FontWeight.w900,
                                              height: 0,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          ayah['text'],
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontFamily: 'qalammajeed3',
                                            fontSize: settings.fontSize + 6,
                                            height: 2.2,
                                          ),
                                        ),
                                        if (ayah['translation'] != null) ...[
                                          const SizedBox(height: 12),
                                          Text(
                                            ayah['translation'],
                                            textAlign: TextAlign.left,
                                            style: TextStyle(
                                              fontSize: settings.fontSize * 0.8,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
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
