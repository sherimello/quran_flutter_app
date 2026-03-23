import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../services/widget_service.dart';

import 'package:google_fonts/google_fonts.dart';

import '../services/database_service.dart';

import '../services/supabase_service.dart';
import '../providers/settings_provider.dart';
import '../data/juz_data.dart';
import 'auth_screen.dart';
import 'bookmarks_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'surah_detail_screen.dart';
import 'juz_detail_screen.dart';
import 'contextual_search_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../widgets/update_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _allSurahs = [];
  List<Map<String, dynamic>> _filteredSurahs = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, dynamic>> _matchingVerses = [];
  bool _isSearchingVerses = false;
  Timer? _searchDebounce;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    WidgetService.updateWidget();
    _tabController = TabController(length: 2, vsync: this);
    _fetchSurahs();
    _searchController.addListener(_onSearchChanged);
    _syncBookmarks();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    final updateInfo = await SupabaseService().checkForUpdates();
    if (updateInfo != null && mounted) {
      final remoteVersion = updateInfo['version_code'] as String?;
      final downloadLink = updateInfo['download_link'] as String?;
      if (remoteVersion == null || downloadLink == null) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_isNewerVersion(currentVersion, remoteVersion)) {
        showDialog(
          context: context,
          builder: (context) => UpdateDialog(
            version: remoteVersion,
            changelog: updateInfo['changelog'] ?? 'No changelog provided.',
            downloadUrl: downloadLink,
          ),
        );
      }
    }
  }

  bool _isNewerVersion(String current, String remote) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final remoteParts = remote.split('.').map(int.parse).toList();
      for (int i = 0; i < 3; i++) {
        final c = i < currentParts.length ? currentParts[i] : 0;
        final r = i < remoteParts.length ? remoteParts[i] : 0;
        if (r > c) return true;
        if (r < c) return false;
      }
      return false;
    } catch (_) {
      return remote != current;
    }
  }

  Future<void> _syncBookmarks() async {
    await SupabaseService().syncBookmarks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchSurahs() async {
    final surahs = await DatabaseService().getAllSurahs();
    if (mounted) {
      setState(() {
        _allSurahs = surahs;
        _filteredSurahs = surahs;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredSurahs = _allSurahs.where((surah) {
        final name = surah['name']?.toLowerCase() ?? '';
        final englishName = surah['englishName']?.toLowerCase() ?? '';
        final translation =
            surah['englishNameTranslation']?.toLowerCase() ?? '';
        final number = surah['number'].toString();

        return name.contains(query) ||
            englishName.contains(query) ||
            translation.contains(query) ||
            number.contains(query);
      }).toList();
    });

    _searchDebounce?.cancel();
    if (query.length >= 2) {
      _searchDebounce = Timer(const Duration(milliseconds: 600), () {
        _performVerseSearch(query);
      });
    } else {
      setState(() {
        _matchingVerses = [];
      });
    }
  }

  Future<void> _performVerseSearch(String query) async {
    final regExp = RegExp(r'^(\d+):(\d+)$');
    if (regExp.hasMatch(query)) {
      final match = regExp.firstMatch(query);
      final surahNum = int.parse(match!.group(1)!);
      final ayahNum = int.parse(match.group(2)!);

      // Validate against actual ranges
      final surah = _allSurahs.firstWhere(
        (s) => s['number'] == surahNum,
        orElse: () => {},
      );

      if (surah.isNotEmpty) {
        final maxAyahs = surah['numberOfAyahs'] as int;
        if (ayahNum > 0 && ayahNum <= maxAyahs) {
          if (mounted) {
            setState(() {
              _matchingVerses = [
                {
                  'surah': surahNum,
                  'ayah': ayahNum,
                  'text': 'Go to Verse $surahNum:$ayahNum',
                  'isDirect': true,
                },
              ];
            });
          }
          return;
        }
      }

      // If invalid range or surah not found
      if (mounted) {
        setState(() {
          _matchingVerses = [
            {
              'surah': surahNum,
              'ayah': ayahNum,
              'text': 'Reference not found in Quran',
              'isDirect': false,
              'invalid': true,
            },
          ];
        });
      }
      return;
    }

    if (query.length < 3) return;

    if (mounted) setState(() => _isSearchingVerses = true);
    final results = await DatabaseService().searchVersesByLatin(query);
    if (mounted) {
      setState(() {
        _matchingVerses = results;
        _isSearchingVerses = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 70,
        title: _isSearching
            ? Container(
                height: 45,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.black.withOpacity(0.05)
                      : Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: const TextStyle(fontSize: 14),
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search Surah...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.black54
                          : Colors.white60,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      CupertinoIcons.search,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    suffixIcon: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isSearching = false;
                          _searchController.clear();
                        });
                      },
                      child: const Icon(
                        CupertinoIcons.clear_circled_solid,
                        size: 18,
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              )
            : Text(
                'Qur\'an Premium',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: size.width * .045,
                ),
              ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Column(
            children: [
              // Tab bar
              TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicatorColor: Theme.of(context).colorScheme.primary,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor:
                    Theme.of(context).brightness == Brightness.light
                    ? Colors.black54
                    : Colors.white70,
                labelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                unselectedLabelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
                tabs: const [
                  Tab(text: 'Surahs'),
                  Tab(text: 'Juz'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          if (!_isSearching) ...[
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ContextualSearchScreen(),
                  ),
                );
              },
              child: const Icon(CupertinoIcons.sparkles),
            ),
            const SizedBox(width: 9),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isSearching = true;
                });
                _searchFocusNode.requestFocus();
              },
              child: const Icon(CupertinoIcons.search),
            ),
            const SizedBox(width: 9),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BookmarksScreen()),
                );
              },
              child: const Icon(CupertinoIcons.bookmark),
            ),
            const SizedBox(width: 9),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              child: const Icon(CupertinoIcons.gear),
            ),
            const SizedBox(width: 9),
            if (SupabaseService().currentUser != null)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
                child: const Icon(CupertinoIcons.person),
              )
            else
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  );
                },
                child: const Icon(CupertinoIcons.person_circle),
              ),
            // IconButton(
            //   onPressed: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(builder: (_) => const AuthScreen()),
            //     );
            //   },
            //   icon: const Icon(CupertinoIcons.person_crop_circle),
            //   padding: EdgeInsets.zero,
            // ),
          ],
        ],
        actionsPadding: const EdgeInsets.only(right: 16),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Surah tab
          _buildSurahList(),
          // Juz tab
          _buildJuzList(),
        ],
      ),
      floatingActionButton: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          final hasLastRead = settings.wasLastReadJuz
              ? (settings.lastReadJuz != null &&
                    settings.lastReadJuzAyah != null)
              : (settings.lastReadSurah != null &&
                    settings.lastReadAyah != null);

          if (!hasLastRead || _isSearching) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: () async {
              if (settings.wasLastReadJuz) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => JuzDetailScreen(
                      juzNumber: settings.lastReadJuz!,
                      initialAyahIndex: settings.lastReadJuzAyah!,
                    ),
                  ),
                );
              } else {
                final surahInfo = await DatabaseService().getSurahByNumber(
                  settings.lastReadSurah!,
                );
                if (surahInfo != null && mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SurahDetailScreen(
                        surah: surahInfo,
                        initialAyah: settings.lastReadAyah!,
                      ),
                    ),
                  );
                }
              }
            },
            icon: const Icon(CupertinoIcons.hourglass_tophalf_fill),
            label: Text(
              settings.wasLastReadJuz ? 'Last Read' : 'Last Read',
              // ? 'Last Read: Juz ${settings.lastReadJuz}'
              // : 'Last Read: Surah ${settings.lastReadSurah}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          );
        },
      ),
    );
  }

  Widget _buildSurahList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredSurahs.isEmpty &&
        _matchingVerses.isEmpty &&
        !_isSearchingVerses) {
      if (_searchController.text.isNotEmpty) {
        return const Center(child: Text('No results found.'));
      }
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_filteredSurahs.isNotEmpty &&
            _searchController.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Text(
              'SURAH RESULTS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                letterSpacing: 1.2,
              ),
            ),
          ),
        if (_filteredSurahs.isNotEmpty)
          ..._filteredSurahs.map((surah) => _buildSurahTile(surah)),
        if (_isSearchingVerses)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CupertinoActivityIndicator(),
            ),
          ),
        if (_matchingVerses.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Text(
              'VERSE RESULTS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                letterSpacing: 1.2,
              ),
            ),
          ),
          ..._matchingVerses.map((verse) => _buildVerseTile(verse)),
        ],
      ],
    );
  }

  Widget _buildSurahTile(Map<String, dynamic> surah) {
    return Card(
      elevation: 0,
      color: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 11),
        leading: Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            '${surah['number']}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(
          surah['englishName'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          '${surah['englishNameTranslation']} • ${surah['numberOfAyahs']} Verses',
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: Text(
          '${surah['number']}',
          style: const TextStyle(fontFamily: 'surahname', fontSize: 32),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SurahDetailScreen(surah: surah),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVerseTile(Map<String, dynamic> verse) {
    final surahNum = verse['surah'];
    final ayahNum = verse['ayah'];
    final isDirect = verse['isDirect'] ?? false;
    final isInvalid = verse['invalid'] ?? false;

    return Card(
      elevation: 0,
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 11),
        leading: Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            color: isInvalid
                ? Colors.red.withOpacity(0.1)
                : isDirect
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(
            isInvalid
                ? CupertinoIcons.exclamationmark_circle
                : isDirect
                ? CupertinoIcons.arrow_right_circle
                : CupertinoIcons.text_quote,
            size: 18,
            color: isInvalid
                ? Colors.red
                : isDirect
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onTertiaryContainer,
          ),
        ),
        title: Text(
          isInvalid
              ? 'Reference not found'
              : isDirect
              ? 'Jump to Verse $surahNum:$ayahNum'
              : '$surahNum:$ayahNum',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isInvalid ? Colors.red : null,
          ),
        ),
        subtitle: Text(
          isInvalid
              ? 'Verse $surahNum:$ayahNum does not exist'
              : (verse['text'] ?? ''),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isInvalid ? Colors.red.withOpacity(0.7) : Colors.grey[600],
          ),
        ),
        onTap: isInvalid
            ? null
            : () async {
                final surahInfo = await DatabaseService().getSurahByNumber(
                  surahNum,
                );
                if (surahInfo != null && mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SurahDetailScreen(
                        surah: surahInfo,
                        initialAyah: ayahNum,
                      ),
                    ),
                  );
                }
              },
      ),
    );
  }

  Widget _buildJuzList() {
    return ListView.builder(
      itemCount: juzData.length,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        final juz = juzData[index];
        final juzNumber = juz['juz'];
        final startSurah = juz['start']['surah'];
        final startVerse = juz['start']['verse'];
        final endSurah = juz['end']['surah'];
        final endVerse = juz['end']['verse'];

        return Card(
          elevation: 0,
          color: Colors.transparent,
          margin: const EdgeInsets.symmetric(vertical: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 11),
            leading: Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                '$juzNumber',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            title: Text(
              'Juz $juzNumber',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              'From $startSurah:$startVerse to $endSurah:$endVerse',
              style: TextStyle(color: Colors.grey[600]),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => JuzDetailScreen(juzNumber: juzNumber),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
