import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/database_service.dart';
import '../services/supabase_service.dart';
import '../data/juz_data.dart';
import 'auth_screen.dart';
import 'bookmarks_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'surah_detail_screen.dart';
import 'juz_detail_screen.dart';

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

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchSurahs();
    _searchController.addListener(_onSearchChanged);
    _syncBookmarks();
  }

  Future<void> _syncBookmarks() async {
    await SupabaseService().syncBookmarks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
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
    final query = _searchController.text.toLowerCase();
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
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Qur\'an Premium',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: size.width * .045,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search Surah...',
                    hintStyle: TextStyle(color: Colors.black),
                    prefixIcon: const Icon(Icons.search, color: Colors.black),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              // Tab bar
              TabBar(
                controller: _tabController,
                indicatorColor: Theme.of(context).colorScheme.primary,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: 'Surahs'),
                  Tab(text: 'Juz'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          if (SupabaseService().currentUser != null)
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
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                );
              },
              child: const Text('Login'),
            ),
        ],
        actionsPadding: const EdgeInsets.only(right: 11),
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
    );
  }

  Widget _buildSurahList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredSurahs.isEmpty) {
      return const Center(child: Text('No Surahs found.'));
    }

    return ListView.builder(
      itemCount: _filteredSurahs.length,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        final surah = _filteredSurahs[index];
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
      },
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
