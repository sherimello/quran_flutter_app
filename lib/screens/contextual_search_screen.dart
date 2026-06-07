import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/tafseer_embedding.dart';
import '../services/database_service.dart';
import '../services/semantic_search_service.dart';
import 'surah_detail_screen.dart';

class ContextualSearchScreen extends StatefulWidget {
  const ContextualSearchScreen({super.key});

  @override
  State<ContextualSearchScreen> createState() => _ContextualSearchScreenState();
}

class _ContextualSearchScreenState extends State<ContextualSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SemanticSearchService _searchService = SemanticSearchService();

  Timer? _debounce;
  List<SearchResult> _results = [];
  bool _isSearching = false;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadEmbeddings();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (query.trim().isNotEmpty) {
        _performSearch();
      } else {
        setState(() {
          _results = [];
        });
      }
    });

    setState(() {});
  }

  Future<void> _loadEmbeddings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _searchService.loadEmbeddings();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load search data. Please try again.';
        });
      }
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
      });
      return;
    }

    if (_isSearching) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      // Use smart search (semantic if available, else keyword)
      final results = await _searchService.search(query, maxResults: 50);

      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'Search failed. Please try again.';
        });
      }
    }
  }

  Future<void> _navigateToVerse(int surah, int ayah) async {
    // Fetch surah info
    final surahInfo = await DatabaseService().getSurahByNumber(surah);
    if (surahInfo == null) return;

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SurahDetailScreen(surah: surahInfo, initialAyah: ayah),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    var size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: AppBar().preferredSize.height * 1.5,
        title: Text(
          'Contextual Search',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: size.width * .041,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 21.0),
            child: Transform.scale(
              scale: 0.9,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xff34da15).withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Center(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(fontSize: 14),
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      hintText: "i'm depressed...",
                      hintStyle: GoogleFonts.poppins(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: .55),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 0,
                      ),
                      prefixIcon: Icon(
                        CupertinoIcons.search,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() {
                                  _results = [];
                                });
                              },
                              child: const Icon(
                                CupertinoIcons.clear_circled_solid,
                                size: 18,
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 21),
                    ),
                    // onChanged: (value) {
                    //   setState(() {});
                    // },
                    onSubmitted: (value) => _performSearch(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
      // floatingActionButton: _searchController.text.isNotEmpty
      //     ? FloatingActionButton(
      //         onPressed: _performSearch,
      //         child: const Icon(CupertinoIcons.search),
      //       )
      //     : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading search data...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadEmbeddings,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching...'),
          ],
        ),
      );
    }

    if (_results.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.search, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No results found for "${_searchController.text}"',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords or concepts',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      var size = MediaQuery.of(context).size;

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.lightbulb_fill,
              size: size.width * .11,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(height: 24),
            Text(
              'Search by Topic or Concept',
              style: GoogleFonts.poppins(
                fontSize: size.width * .045,
                height: 0,
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Try searching for concepts like: "patience",\n"charity", "prayer", "forgiveness"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 0,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    var size = MediaQuery.of(context).size;

    return ListView.builder(
      padding: const EdgeInsets.all(21),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        return index == 0
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 11,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: size.width * .12,
                          height: 14,
                          child: CustomPaint(
                            painter: _WavyLinePainter(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 1),
                            ),
                          ),
                        ),
                        SizedBox(width: size.width * .035),
                        Text(
                          "${_results.length} result(s) found",
                          style: GoogleFonts.poppins(fontSize: size.width * .035, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(width: size.width * .035),
                        SizedBox(
                          width: size.width * .12,
                          height: 14,
                          child: CustomPaint(
                            painter: _WavyLinePainter(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildResultCard(result),
                ],
              )
            : _buildResultCard(result);
      },
    );
  }

  Widget _buildResultCard(SearchResult result) {

    var size = MediaQuery.of(context).size;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Theme.of(context).colorScheme.onSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(41)),
      child: InkWell(
        borderRadius: BorderRadius.circular(41),
        onTap: () => _navigateToVerse(result.surah, result.ayah),
        child: Padding(
          padding: EdgeInsets.all(size.width * .055),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black : Colors.white,
                      borderRadius: BorderRadius.circular(1000),
                    ),
                    child: Text(
                      result.verseKey,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        height: 0,
                      ),
                    ),
                  ),
                  // Container(
                  //   padding: const EdgeInsets.symmetric(
                  //     horizontal: 8,
                  //     vertical: 4,
                  //   ),
                  //   decoration: BoxDecoration(
                  //     color: Theme.of(context).brightness == Brightness.light
                  //         ? Colors.black.withOpacity(0.05)
                  //         : Colors.white.withOpacity(0.1),
                  //     borderRadius: BorderRadius.circular(12),
                  //   ),
                  //   child: Text(
                  //     '${(result.similarity * 100).toStringAsFixed(0)}% match',
                  //     style: TextStyle(
                  //       fontSize: 11,
                  //       color: Theme.of(context).colorScheme.primary,
                  //       fontWeight: FontWeight.w600,
                  //     ),
                  //   ),
                  // ),
                ],
              ),
              const SizedBox(height: 12),
              HtmlWidget(
                result.snippet,
                textStyle: GoogleFonts.poppins(
                  height: 0,
                  fontSize: 9,
                  color: isDark ? Colors.black : Colors.white,
                ),
                // maxLines: 4,
                // overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Icon(
                    CupertinoIcons.arrow_turn_up_right,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Tap to view full verse',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      height: 0,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WavyLinePainter extends CustomPainter {
  final Color color;

  _WavyLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    const waveHeight = 4.5;
    const waveLength = 17.0; // 70px SizedBox = exactly 5 complete waves
    double x = 0;
    path.moveTo(0, size.height / 2);
    while (x < size.width) {
      path.quadraticBezierTo(
        x + waveLength / 4,
        size.height / 2 - waveHeight,
        x + waveLength / 2,
        size.height / 2,
      );
      path.quadraticBezierTo(
        x + waveLength * 3 / 4,
        size.height / 2 + waveHeight,
        x + waveLength,
        size.height / 2,
      );
      x += waveLength;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavyLinePainter old) => old.color != color;
}
