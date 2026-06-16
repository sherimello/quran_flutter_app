import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/tafseer_embedding.dart';
import '../providers/settings_provider.dart';
import '../services/ai_search_service.dart';
import '../services/database_service.dart';
import '../services/semantic_search_service.dart';
import '../widgets/blurred_sheet.dart';
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
  String? _aiAnswer;
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

  bool get _isAiMode {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    return settings.aiProvider != 'none';
  }

  void _onSearchChanged(String query) {
    // For AI providers, only search on explicit submit — no per-keystroke API calls
    if (_isAiMode) {
      setState(() {});
      return;
    }

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
      _aiAnswer = null;
    });

    try {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final isGroq = settings.aiProvider == 'groq';
      final isCohere = settings.aiProvider == 'cohere';
      final apiKey = isGroq ? settings.groqApiKey : settings.cohereApiKey;
      final useAi = (isGroq || isCohere) && apiKey.isNotEmpty;

      if (useAi) {
        final response = await AiSearchService().search(
          query: query,
          provider: settings.aiProvider,
          model: isGroq ? settings.groqModel : settings.cohereModel,
          apiKey: apiKey,
        );
        if (mounted) {
          setState(() {
            _aiAnswer = response.answer.isNotEmpty ? response.answer : null;
            _results = response.results;
            _isSearching = false;
          });
        }
      } else {
        final semantic = await _searchService.search(query, maxResults: 50);
        final refs = semantic
            .map((r) => {'surah': r.surah, 'ayah': r.ayah})
            .toList();
        final translations = await DatabaseService().getBulkTranslations(refs);
        final results = semantic.map((r) {
          final t = translations['${r.surah}_${r.ayah}'] ?? '';
          return t.isNotEmpty ? r.copyWith(translation: t) : r;
        }).toList();
        if (mounted) {
          setState(() {
            _aiAnswer = null;
            _results = results;
            _isSearching = false;
          });
        }
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

  static const _groqModels = <String, String>{
    'llama-3.3-70b-versatile': 'LLaMA 3.3 70B',
    'llama-3.1-8b-instant': 'LLaMA 3.1 8B (Fast)',
    'gemma2-9b-it': 'Gemma 2 9B',
    'mixtral-8x7b-32768': 'Mixtral 8x7B',
    'deepseek-r1-distill-llama-70b': 'DeepSeek R1 70B',
    'qwen-qwq-32b': 'Qwen QwQ 32B',
  };

  static const _cohereModels = <String, String>{
    'command-a-03-2025': 'Command A (2025)',
    'command-r-plus': 'Command R+',
    'command-r': 'Command R',
    'command-light': 'Command Light',
  };

  void _showSearchSettings() {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Consumer<SettingsProvider>(
              builder: (context, settings, _) {
                final models = settings.aiProvider == 'groq'
                    ? _groqModels
                    : _cohereModels;
                final selectedModel = settings.aiProvider == 'groq'
                    ? settings.groqModel
                    : settings.cohereModel;
                final effectiveModel = models.containsKey(selectedModel)
                    ? selectedModel
                    : models.keys.first;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Search Engine',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final entry in [
                          ('none', 'Local'),
                          ('groq', 'Groq'),
                          ('cohere', 'Cohere'),
                        ])
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: entry.$1 != 'cohere' ? 8 : 0,
                              ),
                              child: _ModeChip(
                                label: entry.$2,
                                isSelected: settings.aiProvider == entry.$1,
                                primary: primary,
                                isDark: isDark,
                                onTap: () {
                                  settings.setAiProvider(entry.$1);
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (settings.aiProvider != 'none') ...[
                      const SizedBox(height: 20),
                      Text(
                        'Model',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      DropdownButton<String>(
                        value: effectiveModel,
                        isExpanded: true,
                        underline: const SizedBox(),
                        dropdownColor: isDark
                            ? const Color(0xFF1A1A1A)
                            : Colors.white,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        items: models.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          if (settings.aiProvider == 'groq') {
                            settings.setGroqModel(val);
                          } else {
                            settings.setCohereModel(val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            _activeKeyIsSet(settings)
                                ? CupertinoIcons.checkmark_circle_fill
                                : CupertinoIcons.xmark_circle_fill,
                            size: 16,
                            color: _activeKeyIsSet(settings)
                                ? const Color(0xff34da15)
                                : Colors.red,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _activeKeyIsSet(settings)
                                ? 'API key configured'
                                : 'No API key — set one in Settings',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  bool _activeKeyIsSet(SettingsProvider settings) {
    if (settings.aiProvider == 'groq') return settings.groqApiKey.isNotEmpty;
    if (settings.aiProvider == 'cohere')
      return settings.cohereApiKey.isNotEmpty;
    return false;
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
        actions: [
          Consumer<SettingsProvider>(
            builder: (context, settings, _) {
              final isAi = settings.aiProvider != 'none';
              return IconButton(
                icon: Icon(
                  CupertinoIcons.slider_horizontal_3,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                tooltip: 'Search settings',
                onPressed: _showSearchSettings,
              );
            },
          ),
        ],
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
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final activeKey = settings.aiProvider == 'groq'
        ? settings.groqApiKey
        : settings.cohereApiKey;
    final hasAiProvider = settings.aiProvider != 'none' && activeKey.isNotEmpty;

    if (_isLoading && !hasAiProvider) {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasAnswer = _aiAnswer != null && _aiAnswer!.isNotEmpty;
    final extraItems = hasAnswer ? 1 : 0;

    return ListView.builder(
      padding: const EdgeInsets.all(21),
      itemCount: _results.length + extraItems,
      itemBuilder: (context, index) {
        // AI answer card occupies slot 0 when present
        if (hasAnswer && index == 0) {
          return _AiAnswerCard(
            answer: _aiAnswer!,
            isDark: isDark,
            onVerseTap: _navigateToVerse,
          );
        }

        final resultIndex = index - extraItems;
        final result = _results[resultIndex];

        return resultIndex == 0
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
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 1),
                            ),
                          ),
                        ),
                        SizedBox(width: size.width * .035),
                        Text(
                          "${_results.length} verse(s) referenced",
                          style: GoogleFonts.poppins(
                            fontSize: size.width * .035,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: size.width * .035),
                        SizedBox(
                          width: size.width * .12,
                          height: 14,
                          child: CustomPaint(
                            painter: _WavyLinePainter(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 1),
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
                result.displayText,
                textStyle: GoogleFonts.poppins(
                  height: 0,
                  fontSize: 9,
                  color: isDark ? Colors.black : Colors.white,
                ),
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
                      color: const Color(0xff34da15),
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

class _ModeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color primary;
  final bool isDark;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.isSelected,
    required this.primary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff34da15) : Colors.transparent,
          borderRadius: BorderRadius.circular(1000),
          border: Border.all(
            color: isSelected
                ? primary
                : isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.12),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.black
                : isDark
                ? Colors.white70
                : Colors.black54,
          ),
        ),
      ),
    );
  }
}

class _AiAnswerCard extends StatefulWidget {
  final String answer;
  final bool isDark;
  final void Function(int surah, int ayah) onVerseTap;

  const _AiAnswerCard({
    required this.answer,
    required this.isDark,
    required this.onVerseTap,
  });

  @override
  State<_AiAnswerCard> createState() => _AiAnswerCardState();
}

class _AiAnswerCardState extends State<_AiAnswerCard> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(_AiAnswerCard old) {
    super.didUpdateWidget(old);
    if (old.answer != widget.answer) {
      // Dispose old recognizers when the answer text changes
      for (final r in _recognizers) {
        r.dispose();
      }
      _recognizers.clear();
    }
  }

  List<InlineSpan> _buildSpans() {
    final pattern = RegExp(r'\[(\d+):(\d+)\]');
    final spans = <InlineSpan>[];
    final text = widget.answer;
    int lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }

      final surah = int.parse(match.group(1)!);
      final ayah = int.parse(match.group(2)!);
      final recognizer = TapGestureRecognizer()
        ..onTap = () => widget.onVerseTap(surah, ayah);
      _recognizers.add(recognizer);

      spans.add(
        TextSpan(
          text: match.group(0),
          style: const TextStyle(
            color: Color(0xff34da15),
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: Color(0xff34da15),
          ),
          recognizer: recognizer,
        ),
      );

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : const Color(0xFFF6FFF4),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xff34da15).withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.sparkles,
                size: 13,
                color: Color(0xff34da15),
              ),
              const SizedBox(width: 6),
              Text(
                'AI Answer',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff34da15),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                height: 1.65,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.87)
                    : Colors.black87,
              ),
              children: _buildSpans(),
            ),
          ),
        ],
      ),
    );
  }
}
