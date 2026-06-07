import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../data/juz_data.dart';
import '../widgets/blurred_sheet.dart';
import '../providers/settings_provider.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';
import '../services/widget_service.dart';
import '../widgets/update_dialog.dart';
import 'auth_screen.dart';
import 'bookmarks_screen.dart';
import 'contextual_search_screen.dart';
import 'juz_detail_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'surah_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _allSurahs = [];
  List<Map<String, dynamic>> _filteredSurahs = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, dynamic>> _matchingVerses = [];
  bool _isSearchingVerses = false;
  Timer? _searchDebounce;

  bool _showJuz = false;

  final ScrollController _surahScrollController = ScrollController();
  final ScrollController _juzScrollController = ScrollController();

  // Haptic tick tracking — fires selectionClick each time scroll crosses an item boundary
  int _surahHapticTick = 0;
  int _juzHapticTick = 0;
  static const _kItemExtent = 64.0; // approx layout height of each list tile (42px avatar + 11*2 padding)

  @override
  void initState() {
    super.initState();
    WidgetService.updateWidget();
    _fetchSurahs();
    _searchController.addListener(_onSearchChanged);
    _surahScrollController.addListener(_onSurahScroll);
    _juzScrollController.addListener(_onJuzScroll);
    _syncBookmarks();
    _checkForUpdates();
  }

  void _onSurahScroll() {
    final tick = (_surahScrollController.offset / _kItemExtent).round();
    if (tick != _surahHapticTick) {
      _surahHapticTick = tick;
      HapticFeedback.selectionClick();
    }
  }

  void _onJuzScroll() {
    final tick = (_juzScrollController.offset / _kItemExtent).round();
    if (tick != _juzHapticTick) {
      _juzHapticTick = tick;
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _checkForUpdates() async {
    final updateInfo = await SupabaseService().checkForUpdates();
    if (updateInfo != null && mounted) {
      final remoteVersion = updateInfo['version_code'] as String?;
      final downloadLink = updateInfo['download_link'] as String?;
      if (remoteVersion == null || downloadLink == null) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_isNewerVersion(currentVersion, remoteVersion) && mounted) {
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
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    _surahScrollController.removeListener(_onSurahScroll);
    _juzScrollController.removeListener(_onJuzScroll);
    _surahScrollController.dispose();
    _juzScrollController.dispose();
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
                  'text':
                      '${surah['revelationType']} ::: ${surah['numberOfAyahs']} Ayahs',
                  'isDirect': true,
                },
              ];
            });
          }
          return;
        }
      }

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

  Future<void> _navigateToLastRead(
    SettingsProvider settings,
    bool showJuz,
  ) async {
    if (showJuz) {
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
  }

  void _showMenuSheet() {
    var size = MediaQuery.of(context).size;

    showModalBottomSheet(
      sheetAnimationStyle: AnimationStyle(
        curve: Curves.easeOut,
        reverseCurve: Curves.easeOut,
        duration: const Duration(milliseconds: 455),
        reverseDuration: const Duration(milliseconds: 455),
      ),
      elevation: 11,
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(size.width * .11),
        ),
      ),
      builder: (ctx) => BlurredSheet(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
              const SizedBox(height: 20),
              _menuTile(
                CupertinoIcons.sparkles,
                'Smart Search',
                'Semantic verse search',
                () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ContextualSearchScreen(),
                    ),
                  );
                },
              ),
              _menuTile(
                CupertinoIcons.bookmark_fill,
                'Bookmarks',
                'Your saved verses',
                () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BookmarksScreen()),
                  );
                },
              ),
              _menuTile(
                CupertinoIcons.gear_solid,
                'Settings',
                'Theme, font & display',
                () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              _menuTile(
                SupabaseService().currentUser != null
                    ? CupertinoIcons.person_fill
                    : CupertinoIcons.person,
                SupabaseService().currentUser != null ? 'Profile' : 'Sign In',
                SupabaseService().currentUser != null
                    ? 'View your account'
                    : 'Sign in to sync bookmarks',
                () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SupabaseService().currentUser != null
                          ? const ProfileScreen()
                          : const AuthScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _menuTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    var size = MediaQuery.of(context).size;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 44,
        height: 44,

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
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.outline,
          size: size.width * .047,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          height: 0,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          height: 0,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white54
              : Colors.black45,
        ),
      ),
      trailing: Icon(
        CupertinoIcons.chevron_forward,
        size: 19,
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xff34da15)
            : Colors.black,
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    var size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: AppBar().preferredSize.height * 1.5,
        automaticallyImplyLeading: false,
        leading: _isSearching
            ? null
            : IconButton(
                icon: const Icon(CupertinoIcons.square_grid_4x3_fill, size: 22),
                onPressed: _showMenuSheet,
              ),
        title: _isSearching
            ? Container(
                height: AppBar().preferredSize.height * .85,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(1000),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: GoogleFonts.poppins(
                    height: 0,
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: size.width * .033,
                  ),
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search Surah or verse...',
                    hintStyle: GoogleFonts.poppins(
                      height: 0,
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: size.width * .033,
                    ),
                    prefixIcon: Icon(
                      CupertinoIcons.search,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              )
            : Text(
                'QURAN',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 2.5,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
        centerTitle: true,
        actions: [
          if (_isSearching)
            TextButton(
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _matchingVerses = [];
                });
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: const Color(0xff34da15),
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else ...[
            GestureDetector(
              onTap: () => setState(() => _showJuz = !_showJuz),
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xff34da15),
                  borderRadius: BorderRadius.circular(1000),
                ),
                child: Text(
                  _showJuz ? 'Surah' : 'Juz',
                  style: GoogleFonts.poppins(
                    fontSize: size.width * .025,
                    letterSpacing: 1.5,
                    height: 0,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(CupertinoIcons.search, size: 22),
              onPressed: () {
                setState(() => _isSearching = true);
                _searchFocusNode.requestFocus();
              },
            ),
          ],
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_isSearching)
            Consumer<SettingsProvider>(
              builder: (context, settings, child) {
                final hasLastRead = _showJuz
                    ? (settings.lastReadJuz != null &&
                          settings.lastReadJuzAyah != null)
                    : (settings.lastReadSurah != null &&
                          settings.lastReadAyah != null);

                if (!hasLastRead || _allSurahs.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
                  child: Transform.scale(
                    scale: 0.9,
                    child: _LastReadCard(
                      showJuz: _showJuz,
                      settings: settings,
                      allSurahs: _allSurahs,
                      onTap: () => _navigateToLastRead(settings, _showJuz),
                    ),
                  ),
                );
              },
            ),

          Expanded(
            child: _showJuz
                ? Padding(
                    padding: const EdgeInsets.only(top: 11.0),
                    child: _buildJuzList(),
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: 11.0),
                    child: _buildSurahList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurahList() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
          strokeWidth: 2,
        ),
      );
    }

    if (_filteredSurahs.isEmpty &&
        _matchingVerses.isEmpty &&
        !_isSearchingVerses) {
      if (_searchController.text.isNotEmpty) {
        return const Center(child: Text('No results found.'));
      }
    }

    return ListView(
      key: const PageStorageKey('surah_list'),
      controller: _surahScrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (_isSearching &&
            _filteredSurahs.isNotEmpty &&
            _searchController.text.trim().isNotEmpty)
          _buildSectionLabel('Surah Result(s)'),

        if (_filteredSurahs.isNotEmpty)
          ..._filteredSurahs.asMap().entries.map((entry) {
            final isLast = entry.key == _filteredSurahs.length - 1;
            return _AnimatedListItem(
              index: entry.key,
              child: Transform.scale(
                scale: 0.85,
                child: _buildSurahTile(entry.value, isLast: isLast),
              ),
            );
          }),

        if (_isSearchingVerses)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CupertinoActivityIndicator()),
          ),

        if (_matchingVerses.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildSectionLabel('Verse Result(s)'),
          ..._matchingVerses.map((verse) => _buildVerseTile(verse)),
        ],
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _buildSurahTile(Map<String, dynamic> surah, {bool isLast = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    var size = MediaQuery.of(context).size;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SurahDetailScreen(surah: surah),
          ),
        );
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
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
                  alignment: Alignment.center,
                  child: Text(
                    surah['number'].toString().length == 1
                        ? '00${surah['number']}'
                        : surah['number'].toString().length == 2
                        ? '0${surah['number']}'
                        : surah['number'].toString(),
                    style: GoogleFonts.poppins(
                      fontSize: size.width * .033,
                      height: 0,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        surah['englishName'] ?? '',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          // Icon(
                          //   surah['revelationType'] == 'Meccan'
                          //       ? CupertinoIcons.building_2_fill
                          //       : CupertinoIcons.location_fill,
                          //   size: 11,
                          //   color: isDark ? Colors.white38 : Colors.black38,
                          // ),
                          // const SizedBox(width: 4),
                          Text(
                            surah['revelationType'] == 'Meccan'
                                ? 'Meccan ::: ${surah['numberOfAyahs']} Ayahs'
                                : 'Medinan ::: ${surah['numberOfAyahs']} Ayahs',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  'surah${surah['number'].toString().length == 3
                      ? surah['number'].toString()
                      : surah['number'].toString().length == 2
                      ? "0${surah['number']}"
                      : "00${surah['number']}"}',
                  style: TextStyle(
                    fontFamily: 'surahname',
                    fontSize: 30,
                    color: isDark
                        // ? Colors.white.withValues(alpha: 0.85)
                        ? const Color(0xff34da15)
                        : Colors.black.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          // if (!isLast)
          //   Divider(
          //     height: 1,
          //     indent: 76,
          //     endIndent: 20,
          //     color: isDark
          //         ? Colors.white.withValues(alpha: 0.06)
          //         : Colors.black.withValues(alpha: 0.06),
          //   ),
        ],
      ),
    );
  }

  Widget _buildVerseTile(Map<String, dynamic> verse) {
    final surahNum = verse['surah'];
    final ayahNum = verse['ayah'];
    final isDirect = verse['isDirect'] ?? false;
    final isInvalid = verse['invalid'] ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    var size = MediaQuery.of(context).size;

    return InkWell(
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isInvalid
                    ? Colors.red.withValues(alpha: 0.1)
                    : isDirect
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.6),
                border: Border.all(
                  width: 0.25,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .5),
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(size.width * .65),
                  bottomLeft: Radius.circular(size.width * .5),
                  topRight: Radius.circular(size.width * .75),
                  bottomRight: Radius.circular(size.width * .75),
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                isInvalid
                    ? CupertinoIcons.exclamationmark_circle
                    : isDirect
                    ? CupertinoIcons.arrow_right_circle_fill
                    : CupertinoIcons.text_quote,
                size: 18,
                color: isInvalid
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isInvalid
                        ? 'Reference not found'
                        : isDirect
                        ? 'Open Surah ${_allSurahs[surahNum]['name']}, verse $ayahNum'
                        : '$surahNum:$ayahNum',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isInvalid
                          ? Colors.red
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isInvalid
                        ? 'Verse $surahNum:$ayahNum does not exist'
                        : (verse['text'] ?? ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isInvalid
                          ? Colors.red.withValues(alpha: 0.7)
                          : isDark
                          ? Colors.white54
                          : Colors.black45,
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

  Widget _buildJuzList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return ListView.builder(
      key: const PageStorageKey('juz_list'),
      controller: _juzScrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: juzData.length,
      padding: const EdgeInsets.only(bottom: 24),
      itemBuilder: (context, index) {
        final juz = juzData[index];
        final juzNumber = juz['juz'] as int;
        final startSurah = juz['start']['surah'];
        final startVerse = juz['start']['verse'];
        final endSurah = juz['end']['surah'];
        final endVerse = juz['end']['verse'];

        return _AnimatedListItem(
          index: index,
          child: Transform.scale(
            scale: 0.85,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => JuzDetailScreen(juzNumber: juzNumber),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
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
                        juzNumber < 10 ? '0$juzNumber' : '$juzNumber',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Juz $juzNumber',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.capslock,
                                size: 13,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$startSurah:$startVerse ... $endSurah:$endVerse',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      CupertinoIcons.chevron_forward,
                      size: 21,
                      color: isDark ? const Color(0xff34da15) : Colors.black,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Last Read Card with morph animation ────────────────────────────────────

class _LastReadCard extends StatefulWidget {
  final bool showJuz;
  final SettingsProvider settings;
  final List<Map<String, dynamic>> allSurahs;
  final VoidCallback onTap;

  const _LastReadCard({
    required this.showJuz,
    required this.settings,
    required this.allSurahs,
    required this.onTap,
  });

  @override
  State<_LastReadCard> createState() => _LastReadCardState();
}

class _LastReadCardState extends State<_LastReadCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _widthFactor;
  late final Animation<double> _contentOpacity;
  late final Animation<double> _blurSigma;

  bool _displayingJuz = false;
  bool _midpointFired = false;

  static const _pill = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(1000)),
  );

  static const List<OutlinedBorder> _shapes = [
    // StarBorder(points: 5, innerRadiusRatio: 0.46, pointRounding: 0.2, valleyRounding: 0.1),
    StarBorder(
      points: 4,
      innerRadiusRatio: 0.67,
      pointRounding: 0.55,
      rotation: 45,
    ),
    StarBorder(points: 6, innerRadiusRatio: 0.72, pointRounding: 0.45),
    CircleBorder(eccentricity: 1.0),
    StarBorder(
      points: 3,
      innerRadiusRatio: 0.5,
      pointRounding: 0.67,
      valleyRounding: 0.3,
    ),
  ];

  OutlinedBorder _morphTarget = _pill;

  @override
  void initState() {
    super.initState();
    _displayingJuz = widget.showJuz;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 955),
    );

    _widthFactor = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 21,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 21,
      ),
    ]).animate(_ctrl);

    _contentOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 21,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 21),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 21,
      ),
    ]).animate(_ctrl);

    _blurSigma = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 21.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 21,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 21.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 21,
      ),
    ]).animate(_ctrl);

    _ctrl.addListener(_tick);
  }

  void _tick() {
    if (!_midpointFired && _ctrl.value >= 0.36) {
      _midpointFired = true;
      setState(() => _displayingJuz = widget.showJuz);
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void didUpdateWidget(_LastReadCard old) {
    super.didUpdateWidget(old);
    if (old.showJuz != widget.showJuz) {
      _morphTarget = _shapes[Random().nextInt(_shapes.length)];
      _midpointFired = false;
      HapticFeedback.heavyImpact();
      _ctrl.forward(from: 0.0);
    }
  }

  ShapeBorder _shape() {
    final t = _ctrl.value;
    if (t == 0.0) return _pill;
    if (t < 0.32) {
      return ShapeBorder.lerp(_pill, _morphTarget, (t / 0.32).clamp(0.0, 1.0))!;
    } else if (t < 0.44) {
      return _morphTarget;
    } else {
      return ShapeBorder.lerp(
        _morphTarget,
        _pill,
        ((t - 0.44) / 0.56).clamp(0.0, 1.0),
      )!;
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_tick);
    _ctrl.dispose();
    super.dispose();
  }

  String _title() {
    if (_displayingJuz) return 'Juz ${widget.settings.lastReadJuz}';
    if (widget.settings.lastReadSurah == null) return '';
    final s = widget.allSurahs.firstWhere(
      (s) => s['number'] == widget.settings.lastReadSurah,
      orElse: () => {},
    );
    return s['englishName'] ?? 'Surah ${widget.settings.lastReadSurah}';
  }

  String _subtitle() {
    if (_displayingJuz) {
      return 'Verse ${(widget.settings.lastReadJuzAyah ?? 0) + 1}';
    }
    return 'Ayah ${widget.settings.lastReadAyah ?? 1}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sw = MediaQuery.of(context).size.width;
    const h = 120.0;
    final fullW = sw - 22; // account for parent padding

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final shape = _shape();
        final w = (h + (fullW - h) * _widthFactor.value).clamp(h, fullW);
        final opacity = _contentOpacity.value.clamp(0.0, 1.0);
        final blur = _blurSigma.value;
        final blurProg = (blur / 20.0).clamp(0.0, 1.0);

        // Contents only (logo + text) — blur these, not the card background
        Widget innerContents = Stack(
          children: [
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Image.asset(
                "assets/images/logo_new.png",
                width: 90,
                height: 90,
                color: Colors.white.withValues(
                  alpha: isDark ? 0.31 : 0.27,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 100, 0),
              child: Align(
                alignment: AlignmentGeometry.centerLeft,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue reading from...',
                        style: GoogleFonts.poppins(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.black.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.4,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        '${_title()}, ${_subtitle()}',
                        style: GoogleFonts.poppins(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: sw * 0.037,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );

        if (blur > 0.3) {
          final edgeH = 0.05 + 0.15 * blurProg;
          final edgeV = 0.03 + 0.08 * blurProg;
          innerContents = ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: blur,
              sigmaY: blur,
              tileMode: TileMode.decal,
            ),
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: [0.0, edgeH, 1.0 - edgeH, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: [0.0, edgeV, 1.0 - edgeV, 1.0],
                ).createShader(bounds),
                blendMode: BlendMode.dstIn,
                child: innerContents,
              ),
            ),
          );
        }

        Widget card = SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: ShapeDecoration(
                    shape: shape,
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xff34da15), const Color(0xFF000000)]
                          : [
                              const Color(0xff34da15),
                              const Color.fromARGB(255, 40, 190, 14),
                              const Color(0xFF0B4300),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: ClipPath(
                    clipper: ShapeBorderClipper(shape: shape),
                    child: Opacity(
                      opacity: 1,
                      child: innerContents,
                    ),
                  ),
                ),
              ),
              if (isDark)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ShapeBorderStrokePainter(
                      shape: shape,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                ),
            ],
          ),
        );

        return Center(
          child: GestureDetector(onTap: widget.onTap, child: card),
        );
      },
    );
  }
}

class _ShapeBorderStrokePainter extends CustomPainter {
  final ShapeBorder shape;
  final Color color;

  _ShapeBorderStrokePainter({required this.shape, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(shape.getOuterPath(Offset.zero & size), paint);
  }

  @override
  bool shouldRepaint(_ShapeBorderStrokePainter old) =>
      old.shape != shape || old.color != color;
}

// ─── Animated list item ──────────────────────────────────────────────────────

class _AnimatedListItem extends StatefulWidget {
  final Widget child;
  final int index;

  const _AnimatedListItem({required this.child, required this.index});

  @override
  State<_AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<_AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.linearToEaseOut,
    );
    _scale = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linearToEaseOut),
    );

    Future.delayed(Duration(milliseconds: min(widget.index * 25, 130)), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
