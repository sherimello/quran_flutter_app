import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0.0;
  String _status = 'Initializing';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() {
        _status = 'Loading Quran data';
        _progress = 0.3;
      });

      // Initialize databases (will copy from assets if needed)
      final dbService = DatabaseService();

      setState(() {
        _status = 'Preparing Quran';
        _progress = 0.6;
      });

      await dbService.quranDatabase;

      setState(() {
        _status = 'Loading Tafseer';
        _progress = 0.9;
      });

      await dbService.tafseerDatabase;

      setState(() {
        _status = 'Done!';
        _progress = 1.0;
      });

      // Small delay to show completion
      await Future.delayed(const Duration(milliseconds: 500));

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

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Icon
                Image.asset('assets/images/logo.png', width: 120, height: 120),
                // const SizedBox(height: 32),
                // // Logo or App Name
                // Text(
                //   "Qur'an",
                //   style: Theme.of(context).textTheme.displayLarge?.copyWith(
                //     color: Theme.of(context).colorScheme.primary,
                //     fontWeight: FontWeight.bold,
                //   ),
                // ),
                // const SizedBox(height: 16),
                // Text(
                //   'The Holy Quran',
                //   style: Theme.of(context).textTheme.headlineSmall,
                // ),
                // const SizedBox(height: 48),

                const SizedBox(height: 16),
                if (_isLoading) ...[
                  SizedBox(
                    width: size.width * .045,
                    height: size.width * .045,
                    child: CircularProgressIndicator(
                      value: _progress,
                      color: Theme.of(context).colorScheme.onSurface,),
                  ),
                  // LinearProgressIndicator(
                  //   value: _progress,
                  //   minHeight: 10,
                  //   borderRadius: BorderRadius.circular(5),
                  // ),
                  const SizedBox(height: 16),
                  // Text(
                  //   '${(_progress * 100).toInt()}%',
                  //   style: Theme.of(context).textTheme.titleMedium,
                  // ),
                  // const SizedBox(height: 8),
                  Text(
                    _status,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface),
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
                    onPressed: _initializeApp,
                    child: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
