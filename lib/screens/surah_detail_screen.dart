// import 'package:flutter/material.dart';
// import 'package:audioplayers/audioplayers.dart';
// import 'package:provider/provider.dart';
// import '../services/database_service.dart';
// import '../services/audio_service.dart';
// import '../services/supabase_service.dart';
// import '../providers/settings_provider.dart';
// import 'auth_screen.dart';
//
// class SurahDetailScreen extends StatefulWidget {
//   final Map<String, dynamic> surah;
//
//   const SurahDetailScreen({super.key, required this.surah});
//
//   @override
//   State<SurahDetailScreen> createState() => _SurahDetailScreenState();
// }
//
// class _SurahDetailScreenState extends State<SurahDetailScreen> {
//   final AudioPlayer _audioPlayer = AudioPlayer();
//   List<Map<String, dynamic>> _ayahs = [];
//   bool _isLoading = true;
//   bool _isAudioDownloaded = false;
//   bool _isDownloadingAudio = false;
//   double _downloadProgress = 0.0;
//   int? _playingAyahId;
//   bool _isAutoPlaying = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _fetchAyahs();
//
//     _audioPlayer.onPlayerComplete.listen((event) {
//       if (mounted) {
//         if (_isAutoPlaying && _playingAyahId != null) {
//           _playNextAyah();
//         } else {
//           setState(() {
//             _playingAyahId = null;
//           });
//         }
//       }
//     });
//   }
//
//   Future<void> _fetchAyahs() async {
//     final ayahs = await DatabaseService().getAyahsForSurah(
//       widget.surah['number'],
//     );
//     if (mounted) {
//       setState(() {
//         _ayahs = ayahs;
//         _isLoading = false;
//       });
//       _checkAudioStatus();
//     }
//   }
//
//   Future<void> _checkAudioStatus() async {
//     final exists = await AudioService().isSurahDownloaded(
//       widget.surah['number'],
//       widget.surah['numberOfAyahs'],
//     );
//     if (mounted) {
//       setState(() {
//         _isAudioDownloaded = exists;
//       });
//     }
//   }
//
//   Future<void> _downloadAudio() async {
//     setState(() {
//       _isDownloadingAudio = true;
//     });
//     try {
//       await AudioService().downloadSurahAudio(
//         widget.surah['number'],
//         widget.surah['numberOfAyahs'],
//         (progress) {
//           if (mounted) setState(() => _downloadProgress = progress);
//         },
//       );
//       if (mounted) {
//         setState(() {
//           _isAudioDownloaded = true;
//           _isDownloadingAudio = false;
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() => _isDownloadingAudio = false);
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
//       }
//     }
//   }
//
//   Future<void> _playAyah(int ayahNumber) async {
//     try {
//       if (_playingAyahId == ayahNumber) {
//         await _audioPlayer.stop();
//          setState(() {
//            _playingAyahId = null;
//            _isAutoPlaying = false;
//          });
//        } else {
//          await _audioPlayer.stop();
//          final path = await AudioService().getAudioFilePath(
//            widget.surah['number'],
//            ayahNumber,
//          );
//          await _audioPlayer.play(DeviceFileSource(path));
//          setState(() {
//            _playingAyahId = ayahNumber;
//          });
//        }
//      } catch (e) {
//        ScaffoldMessenger.of(context).showSnackBar(
//          const SnackBar(content: Text('Playback failed: Audio not downloaded?')),
//        );
//      }
//    }
//
//    Future<void> _playNextAyah() async {
//      if (_playingAyahId == null) return;
//
//      int nextAyah = _playingAyahId! + 1;
//      if (nextAyah <= widget.surah['numberOfAyahs']) {
//        await _playAyah(nextAyah);
//      } else {
//        setState(() {
//          _playingAyahId = null;
//          _isAutoPlaying = false;
//        });
//      }
//    }
//
//    Future<void> _toggleSequentialPlay() async {
//      if (_isAutoPlaying) {
//        await _audioPlayer.stop();
//        setState(() {
//          _isAutoPlaying = false;
//          _playingAyahId = null;
//        });
//      } else {
//        setState(() {
//          _isAutoPlaying = true;
//        });
//        // Start from the first ayah if nothing is playing or if we were playing something else
//        await _playAyah(1);
//      }
//    }
//
//    Future<void> _addToBookmark(int surahId, int ayahId) async {
//      final folders = await SupabaseService().getFolders();
//      final controller = TextEditingController();
//      String? selectedFolder;
//
//      if (!mounted) return;
//
//      showDialog(
// 164:       context: context,
// 165:       builder: (context) => StatefulBuilder(
// 166:         builder: (context, setDialogState) {
// 167:           return AlertDialog(
// 168:             title: const Text('Add Bookmark'),
// 169:             content: Column(
// 170:               mainAxisSize: MainAxisSize.min,
// 171:               crossAxisAlignment: CrossAxisAlignment.start,
// 172:               children: [
// 173:                 if (folders.isNotEmpty) ...[
// 174:                   const Text('Select Existing Folder:'),
// 175:                   const SizedBox(height: 8),
// 176:                   Wrap(
// 177:                     spacing: 8,
// 178:                     children: folders.map((f) {
// 179:                       return ChoiceChip(
// 180:                         label: Text(f),
// 181:                         selected: selectedFolder == f,
// 182:                         onSelected: (selected) {
// 183:                           setDialogState(() {
// 184:                             selectedFolder = selected ? f : null;
// 185:                           });
// 186:                         },
// 187:                       );
// 188:                     }).toList(),
// 189:                   ),
// 190:                   const SizedBox(height: 16),
// 191:                   const Text('Or Create New:'),
// 192:                 ],
// 193:                 TextField(
// 194:                   controller: controller,
// 195:                   onChanged: (val) {
// 196:                     if (val.isNotEmpty && selectedFolder != null) {
// 197:                       setDialogState(() => selectedFolder = null);
// 198:                     }
// 199:                   },
// 200:                   decoration: const InputDecoration(
// 201:                     labelText: 'Folder Name (e.g. Favorites)',
// 202:                   ),
// 203:                 ),
// 204:               ],
// 205:             ),
// 206:             actions: [
// 207:               TextButton(
// 208:                 onPressed: () => Navigator.pop(context),
// 209:                 child: const Text('Cancel'),
// 210:               ),
// 211:               TextButton(
// 212:                 onPressed: () async {
// 213:                   Navigator.pop(context);
// 214:                   final folder =
// 215:                       selectedFolder ??
// 216:                       (controller.text.isEmpty ? 'General' : controller.text);
// 217:                   await SupabaseService().saveBookmark(folder, surahId, ayahId);
// 218:                   if (mounted) {
// 219:                     ScaffoldMessenger.of(context).showSnackBar(
// 220:                       const SnackBar(content: Text('Bookmark Saved')),
// 221:                     );
// 222:                   }
// 223:                 },
// 224:                 child: const Text('Save'),
// 225:               ),
// 226:             ],
// 227:           );
// 228:         },
// 229:       ),
// 230:     );
// 231:   }
// 232:
// 233:   @override
// 234:   void dispose() {
// 235:     _audioPlayer.dispose();
// 236:     super.dispose();
// 237:   }
// 238:
// 239:   @override
// 240:   Widget build(BuildContext context) {
// 241:     var size = MediaQuery.of(context).size;
// 242:
// 243:     return Consumer<SettingsProvider>(
// 244:       builder: (context, settings, child) {
// 245:         return Scaffold(
// 246:           appBar: AppBar(
// 247:             title: Text(widget.surah['englishName']),
// 248:             actions: [
// 249:               if (_isDownloadingAudio)
// 250:                 Padding(
// 251:                   padding: const EdgeInsets.all(12.0),
// 252:                   child: CircularProgressIndicator(value: _downloadProgress),
// 253:                 )
// 254:               else if (!_isAudioDownloaded)
// 255:                 IconButton(
// 256:                   icon: const Icon(Icons.download),
// 257:                   onPressed: _downloadAudio,
// 258:                 )
// 259:               else
// 260:                 IconButton(
// 261:                   icon: Icon(
// 262:                     _isAutoPlaying ? Icons.pause_circle : Icons.play_circle,
// 263:                   ),
// 264:                   tooltip: _isAutoPlaying ? 'Stop All' : 'Play All',
// 265:                   onPressed: _toggleSequentialPlay,
// 266:                   color: Theme.of(context).colorScheme.primary,
// 267:                 ),
// 268:             ],
// 269:           ),
// 270:           body: _isLoading
// 271:               ? const Center(child: CircularProgressIndicator())
// 272:               : Column(
// 274:                   children: [
// 275:                     // Bismillah Heading (Except Surah 1 and Surah 9 which doesn't have it)
// 276:                     if (widget.surah['number'] != 1 &&
// 277:                         _ayahs.isNotEmpty &&
// 278:                         _ayahs[0]['text'].toString().contains(
// 279:                           'بِسْمِ اللَّهِ الرَّحْشَنِ الرَّحِيمِ',
// 280:                         ))
// 281:                       Padding(
// 282:                         padding: const EdgeInsets.only(top: 24, bottom: 16),
// 283:                         child: Text(
// 284:                           'بِسْمِ اللَّهِ الرَّحْشَنِ الرَّحِيمِ',
// 285:                           style: TextStyle(
// 286:                             fontFamily: 'qalammajeed3',
// 287:                             fontSize: settings.fontSize + 8,
// 288:                             color: Theme.of(context).colorScheme.primary,
// 289:                           ),
// 290:                           textAlign: TextAlign.center,
// 291:                         ),
// 292:                       ),
// 292:                     Expanded(
// 293:                       child: ListView.builder(
// 294:                         padding: const EdgeInsets.symmetric(
// 295:                           vertical: 16,
// 296:                           horizontal: 21,
// 297:                         ),
// 298:                         itemCount: _ayahs.length,
// 299:                         itemBuilder: (context, index) {
// 300:                           final ayah = Map<String, dynamic>.from(_ayahs[index]);
// 301:                           final isPlaying =
// 302:                               _playingAyahId == ayah['numberInSurah'];
// 303:
// 304:                           // Strip Bismillah from verse 1 for display (Except Surah 1)
// 305:                           if (widget.surah['number'] != 1 &&
// 306:                               index == 0 &&
// 307:                               ayah['text'].startsWith(
// 308:                                 'بِسْمِ اللَّهِ الرَّحْشَنِ الرَّحِيمِ',
// 309:                               )) {
// 310:                             ayah['text'] = ayah['text']
// 311:                                 .replaceFirst(
// 312:                                   'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
// 313:                                   '',
// 314:                                 )
// 315:                                 .trim();
// 316:                             // If only Bismillah was there (e.g. Surah 9? No, Surah 9 has nothing,
// 317:                             // but some APIs might have it separately. In Uthmani, it's prefix).
// 318:                             if (ayah['text'].isEmpty)
// 319:                               return const SizedBox.shrink();
// 320:                           }
// 321:
// 322:                           return Padding(
// 323:                             padding: const EdgeInsets.symmetric(vertical: 5.5),
// 324:                             child: InkWell(
// 325:                               onTap: () => _playAyah(ayah['numberInSurah']),
// 326:                               onLongPress: () {
// 327:                                 if (SupabaseService().currentUser == null) {
// 328:                                   showDialog(
// 329:                                     context: context,
// 330:                                     builder: (context) => AlertDialog(
// 331:                                       title: const Text('Login Required'),
// 332:                                       content: const Text(
// 333:                                         'Please login to save bookmarks.',
// 334:                                       ),
// 335:                                       actions: [
// 336:                                         TextButton(
// 337:                                           onPressed: () =>
// 338:                                               Navigator.pop(context),
// 339:                                           child: const Text('Cancel'),
// 340:                                         ),
// 341:                                         TextButton(
// 342:                                           onPressed: () {
// 343:                                             Navigator.pop(context);
// 344:                                             Navigator.push(
// 345:                                               context,
// 346:                                               MaterialPageRoute(
// 347:                                                 builder: (_) =>
// 348:                                                     const AuthScreen(),
// 349:                                               ),
// 350:                                             );
// 351:                                           },
// 352:                                           child: const Text('Login'),
// 353:                                         ),
// 354:                                       ],
// 355:                                     ),
// 356:                                   );
// 357:                                 } else {
// 358:                                   _addToBookmark(
// 359:                                     widget.surah['number'],
// 360:                                     ayah['numberInSurah'],
// 361:                                   );
// 362:                                 }
// 363:                               },
// 364:                               child: Row(
// 365:                                 spacing: 11,
// 366:                                 children: [
// 367:                                   Column(
// 368:                                     mainAxisSize: MainAxisSize.min,
// 369:                                     mainAxisAlignment:
// 370:                                         MainAxisAlignment.spaceBetween,
// 371:                                     children: [
// 372:                                       if (_isAudioDownloaded && isPlaying)
// 373:                                         IconButton(
// 374:                                           icon: Icon(
// 375:                                             isPlaying
// 376:                                                 ? Icons.pause_circle
// 377:                                                 : Icons.play_circle,
// 378:                                           ),
// 379:                                           onPressed: () =>
// 380:                                               _playAyah(ayah['numberInSurah']),
// 381:                                           color: Theme.of(
// 382:                                             context,
// 383:                                           ).colorScheme.primaryContainer,
// 384:                                         )
// 385:                                       else
// 386:                                         CircleAvatar(
// 387:                                           radius: 14,
// 388:                                           backgroundColor: Theme.of(
// 389:                                             context,
// 390:                                           ).colorScheme.primaryContainer,
// 391:                                           child: Text(
// 392:                                             '${ayah['numberInSurah']}',
// 393:                                             style: TextStyle(
// 394:                                               fontSize: 12,
// 395:                                               color: Theme.of(
// 396:                                                 context,
// 397:                                               ).colorScheme.onPrimaryContainer,
// 398:                                               fontWeight: FontWeight.w900,
// 399:                                               height: 0,
// 400:                                             ),
// 401:                                           ),
// 402:                                         ),
// 403:                                     ],
// 404:                                   ),
// 405:                                   const SizedBox(height: 8),
// 406:                                   Expanded(
// 407:                                     child: Column(
// 408:                                       mainAxisSize: MainAxisSize.min,
// 409:                                       crossAxisAlignment:
// 410:                                           CrossAxisAlignment.end,
// 411:                                       children: [
// 412:                                         Text(
// 413:                                           ayah['text'],
// 414:                                           textAlign: TextAlign.right,
// 415:                                           style: TextStyle(
// 416:                                             fontFamily: 'qalammajeed3',
// 417:                                             fontSize: settings.fontSize + 6,
// 418:                                             height: 2.2,
// 419:                                           ),
// 420:                                         ),
// 421:                                         if (ayah['translation'] != null) ...[
// 422:                                           const SizedBox(height: 12),
// 423:                                           Text(
// 424:                                             ayah['translation'],
// 425:                                             textAlign: TextAlign.left,
// 426:                                             style: TextStyle(
// 427:                                               fontSize: settings.fontSize * 0.8,
// 428:                                               color: Colors.grey[700],
// 429:                                             ),
// 430:                                           ),
// 431:                                         ],
// 432:                                       ],
// 433:                                     ),
// 434:                                   ),
// 435:                                 ],
// 436:                               ),
// 437:                             ),
// 438:                           );
// 439:                         },
// 440:                       ),
// 441:                     ),
// 442:                   ],
// 443:                 ),
// 444:         );
// 445:       },
// 446:     );
// 447:   }
// 448: }

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../services/database_service.dart';
import '../services/audio_service.dart';
import '../services/supabase_service.dart';
import '../providers/settings_provider.dart';
import 'auth_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchAyahs();

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
  }

  Future<void> _fetchAyahs() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final dbAyahs = await DatabaseService().getAyahsForSurah(
      widget.surah['number'],
    );
    // Convert to modifiable list to avoid "read-only" error
    final List<Map<String, dynamic>> ayahs = List<Map<String, dynamic>>.from(
      dbAyahs,
    );

    // Pre-fetch Tafseer if enabled (using optimized bulk fetch)
    if (settings.showTafseer) {
      final tafseers = await DatabaseService().getTafseersForSurah(
        widget.surah['number'],
      );
      for (var i = 0; i < ayahs.length; i++) {
        final ayahNum = ayahs[i]['numberInSurah'];
        if (tafseers.containsKey(ayahNum)) {
          final tafseer = tafseers[ayahNum]!;
          ayahs[i] = {
            ...ayahs[i],
            'tafseer': tafseer,
            'tafseerSnippet': _stripHtml(tafseer),
            'isTafseerExpanded': false,
          };
        }
      }
    }

    if (!mounted) return;

    setState(() {
      _ayahs = ayahs;
      _isLoading = false;
    });

    _checkAudioStatus();

    // Scroll to initial ayah if provided
    if (widget.initialAyah != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToAyah(widget.initialAyah!);
      });
    }
  }

  Future<void> _checkAudioStatus() async {
    final exists = await AudioService().isSurahDownloaded(
      widget.surah['number'],
      widget.surah['numberOfAyahs'],
    );
    if (!mounted) return;

    setState(() {
      _isAudioDownloaded = exists;
    });
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

      if (!mounted) return;

      setState(() {
        _isAudioDownloaded = true;
        _isDownloadingAudio = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isDownloadingAudio = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  Future<void> _playAyah(int ayahNumber) async {
    try {
      if (_playingAyahId == ayahNumber) {
        await _audioPlayer.stop();
        if (!mounted) return;
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
        if (!mounted) return;
        setState(() {
          _playingAyahId = ayahNumber;
        });

        // Auto-scroll to playing ayah
        _scrollToAyah(ayahNumber);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playback failed: Audio not downloaded?')),
      );
    }
  }

  void _scrollToAyah(int ayahNumber) {
    if (_ayahs.isNotEmpty) {
      // Find index of ayah with numberInSurah == ayahNumber
      final index = _ayahs.indexWhere((a) => a['numberInSurah'] == ayahNumber);
      if (index != -1) {
        _itemScrollController.scrollTo(
          index: index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  Future<void> _playNextAyah() async {
    if (_playingAyahId == null) return;

    int nextAyah = _playingAyahId! + 1;
    if (nextAyah <= widget.surah['numberOfAyahs']) {
      await _playAyah(nextAyah);
    } else {
      if (!mounted) return;
      setState(() {
        _playingAyahId = null;
        _isAutoPlaying = false;
      });
    }
  }

  Future<void> _toggleSequentialPlay() async {
    if (_isAutoPlaying) {
      await _audioPlayer.stop();
      if (!mounted) return;
      setState(() {
        _isAutoPlaying = false;
        _playingAyahId = null;
      });
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

  // --- CLEANUP FUNCTION (ROBUST BASMALA REMOVER) ---
  String _removeBasmala(String text) {
    // List of common Basmala variations found in databases
    const List<String> variations = [
      'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ', // Uthmani standard
      'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ', // Simple enhanced
      'بِسْمِ اللهِ الرَّحٰنِ الرَّحِيْمِ', // IndoPak
      'بسم الله الرحمن الرحيم', // Plain text
      'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
      'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
    ];

    // 1. Try exact matches first
    for (final v in variations) {
      if (text.startsWith(v)) {
        return text.substring(v.length).trim();
      }
    }

    // 2. Fallback matching
    if (text.length > 20 && text.startsWith('بِسْمِ')) {
      final rahimIndex = text.indexOf('الرَّحِيمِ');
      if (rahimIndex != -1 && rahimIndex < 60) {
        return text.substring(rahimIndex + 'الرَّحِيمِ'.length).trim();
      }
    }

    return text;
  }

  String _stripHtml(String htmlString) {
    // Basic regex to remove HTML tags
    final regExp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    // Also replace &nbsp; and other common entities if they appear
    return htmlString.replaceAll(regExp, '').replaceAll('&nbsp;', ' ').trim();
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
        // Header logic: show basmala header for all surahs except 1 and 9
        bool showBasmalaHeader =
            widget.surah['number'] != 1 && widget.surah['number'] != 9;

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
                    // --- BASMALA HEADER ---
                    if (showBasmalaHeader)
                      Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 8),
                        child: Text(
                          _basmalaHeader,
                          style: TextStyle(
                            fontFamily: 'qalammajeed3',
                            fontSize: settings.fontSize + 8,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // --- AYAH LIST ---
                    Expanded(
                      child: ScrollablePositionedList.builder(
                        itemScrollController: _itemScrollController,
                        itemPositionsListener: _itemPositionsListener,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 21,
                        ),
                        itemCount: _ayahs.length,
                        itemBuilder: (context, index) {
                          final ayah = Map<String, dynamic>.from(_ayahs[index]);
                          final isPlaying =
                              _playingAyahId == ayah['numberInSurah'];

                          final rawText = (ayah['text'] ?? '').toString();

                          if (index == 0) {
                            print(rawText);
                          }

                          // ✅ Remove Basmala only from the first ayah
                          // ✅ EXCEPT Surah 1 only
                          final displayText =
                              (index == 0 && widget.surah['number'] != 1)
                              ? _removeBasmala(rawText)
                              : rawText;

                          if (index == 0) {
                            print(displayText);
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
                                          displayText.contains(
                                                'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                                              )
                                              ? displayText.replaceAll(
                                                  'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                                                  '',
                                                )
                                              : displayText,
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
                                        // --- TAFSEER UI ---
                                        if (settings.showTafseer &&
                                            ayah['tafseer'] != null) ...[
                                          const SizedBox(height: 12),
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceVariant
                                                  .withOpacity(0.3),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.outlineVariant,
                                              ),
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
                                                GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      final current =
                                                          ayah['isTafseerExpanded'] ??
                                                          false;
                                                      _ayahs[index]['isTafseerExpanded'] =
                                                          !current;
                                                    });
                                                  },
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      (ayah['isTafseerExpanded'] ??
                                                              false)
                                                          ? HtmlWidget(
                                                              ayah['tafseer'],
                                                              textStyle: TextStyle(
                                                                fontSize:
                                                                    settings
                                                                        .fontSize *
                                                                    0.75,
                                                                color:
                                                                    Theme.of(
                                                                          context,
                                                                        )
                                                                        .textTheme
                                                                        .bodySmall
                                                                        ?.color,
                                                              ),
                                                            )
                                                          : Text(
                                                              ayah['tafseerSnippet'] ??
                                                                  ayah['tafseer'],
                                                              textAlign:
                                                                  TextAlign
                                                                      .justify,
                                                              maxLines: 3,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                fontSize:
                                                                    settings
                                                                        .fontSize *
                                                                    0.75,
                                                                color:
                                                                    Theme.of(
                                                                          context,
                                                                        )
                                                                        .textTheme
                                                                        .bodySmall
                                                                        ?.color,
                                                                fontStyle:
                                                                    FontStyle
                                                                        .italic,
                                                              ),
                                                            ),
                                                      if (!(ayah['isTafseerExpanded'] ??
                                                          false))
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                top: 4.0,
                                                              ),
                                                          child: Text(
                                                            'Show More',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .primary,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
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
