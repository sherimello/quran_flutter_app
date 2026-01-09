import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shimmer/shimmer.dart';
import '../models/surah.dart';
import '../models/ayah.dart';
import '../services/api_service.dart';

class SurahDetailScreen extends StatefulWidget {
  final int surahNumber;

  const SurahDetailScreen({super.key, required this.surahNumber});

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  final ApiService _apiService = ApiService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Surah? _surahInfo;
  List<Ayah> _ayahs = [];
  bool _isLoading = true;
  int? _playingAyahNumber; // numberInSurah
  bool _isPlayingAll = false;

  @override
  void initState() {
    super.initState();
    _fetchSurahDetails();

    _audioPlayer.onPlayerComplete.listen((event) {
      if (_isPlayingAll && _playingAyahNumber != null) {
        // Find next ayah
        final currentIndex = _ayahs.indexWhere(
          (a) => a.numberInSurah == _playingAyahNumber,
        );
        if (currentIndex != -1 && currentIndex < _ayahs.length - 1) {
          _playAyah(_ayahs[currentIndex + 1].numberInSurah);
        } else {
          setState(() {
            _playingAyahNumber = null;
            _isPlayingAll = false;
          });
        }
      } else {
        setState(() {
          _playingAyahNumber = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchSurahDetails() async {
    try {
      final data = await _apiService.getSurahDetails(widget.surahNumber);
      setState(() {
        _surahInfo = data['surah'];
        _ayahs = data['ayahs'];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading surah details: $e')),
        );
      }
    }
  }

  Future<void> _playAyah(int numberInSurah) async {
    try {
      final ayah = _ayahs.firstWhere((a) => a.numberInSurah == numberInSurah);

      if (_playingAyahNumber == numberInSurah) {
        // Toggle pause/resume or stop
        await _audioPlayer.stop();
        setState(() {
          _playingAyahNumber = null;
          _isPlayingAll = false;
        });
        return;
      }

      await _audioPlayer.stop(); // Stop previous
      await _audioPlayer.play(UrlSource(ayah.audio));

      setState(() {
        _playingAyahNumber = numberInSurah;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error playing audio: $e')));
    }
  }

  void _playAll() {
    if (_ayahs.isNotEmpty) {
      setState(() {
        _isPlayingAll = true;
      });
      _playAyah(_ayahs[0].numberInSurah);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isLoading
            ? const Text('Loading...')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _surahInfo?.englishName ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    _surahInfo?.name ?? '',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
        centerTitle:
            true, // Android style usually center is nice for title/subtitle
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.play_circle_outline),
              tooltip: 'Play All',
              onPressed: _playAll,
            ),
        ],
      ),
      body: _isLoading
          ? _buildShimmer()
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _ayahs.length,
                    itemBuilder: (context, index) {
                      final ayah = _ayahs[index];
                      final isPlaying =
                          _playingAyahNumber == ayah.numberInSurah;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    child: Text(
                                      '${ayah.numberInSurah}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      ayah.text,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontFamily:
                                            'Amiri', // System or fallback
                                        fontSize: 24,
                                        height: 1.8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  IconButton(
                                    onPressed: () =>
                                        _playAyah(ayah.numberInSurah),
                                    icon: Icon(
                                      isPlaying
                                          ? Icons.pause_circle_filled
                                          : Icons.play_circle_filled,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        ayah.translation,
                                        style: TextStyle(
                                          fontSize: 16,
                                          height: 1.5,
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
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
  }

  Widget _buildHeader() {
    if (_surahInfo == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            _surahInfo!.name,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(_surahInfo!.englishName, style: const TextStyle(fontSize: 18)),
          Text(
            _surahInfo!.englishNameTranslation,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge(
                label: _surahInfo!.revelationType,
                color: _surahInfo!.revelationType == 'Meccan'
                    ? Colors.green
                    : Colors.orange,
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.format_list_numbered,
                size: 16,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              const SizedBox(width: 4),
              Text('${_surahInfo!.numberOfAyahs} verses'),
            ],
          ),
          if (widget.surahNumber != 1 && widget.surahNumber != 9) ...[
            const SizedBox(height: 24),
            const Text(
              'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيم',
              style: TextStyle(fontSize: 24, fontFamily: 'Amiri'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.withOpacity(0.1),
        highlightColor: Colors.grey.withOpacity(0.3),
        child: Column(
          children: [
            Container(height: 200, width: double.infinity, color: Colors.white),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: 5,
                itemBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Badge extends StatelessWidget {
  final String label;
  final Color color;
  const Badge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
