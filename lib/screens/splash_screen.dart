import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../services/data_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0.0;
  String _status = 'Initializing...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAndLoadData();
  }

  Future<void> _checkAndLoadData() async {
    final dbService = DatabaseService();
    final dataService = DataService();
    bool isPopulated = await dbService.isDatabasePopulated();

    if (isPopulated) {
      // Check if translation repair is needed
      final prefs = await SharedPreferences.getInstance();
      bool isFixed = prefs.getBool('pickthall_translation_fixed') ?? false;

      if (!isFixed) {
        setState(() {
          _status = 'Updating translations...';
        });

        try {
          await dataService.repairTranslations((progress) {
            if (mounted) {
              setState(() {
                _progress = progress;
              });
            }
          });
          await prefs.setBool('pickthall_translation_fixed', true);
        } catch (e) {
          // If repair fails, we can still proceed to home, but maybe show an error later
          debugPrint('Translation repair failed: $e');
        }
      }

      if (mounted) {
        _navigateToHome();
      }
    } else {
      setState(() {
        _status = 'Downloading Quran Data...';
      });

      try {
        await DataService().fetchAndStoreQuranData((progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
              if (progress < 0.2) {
                _status = 'Fetching Surah List...';
              } else if (progress < 0.8) {
                _status = 'Downloading Quran Content...';
              } else {
                _status = 'Saving to Database...';
              }
            });
          }
        });

        if (mounted) {
          _navigateToHome();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _status = 'Error: $e';
            _isLoading = false;
          });
        }
      }
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo or App Name
              Text(
                'Quran',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'The Holy Quran',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 48),

              if (_isLoading) ...[
                LinearProgressIndicator(
                  value: _progress,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
                const SizedBox(height: 16),
                Text(
                  '${(_progress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _status,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Text(
                  _status,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _checkAndLoadData,
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
