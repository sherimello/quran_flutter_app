import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://viljtvwbloyxrxklpbdj.supabase.co',
    anonKey: 'sb_publishable_eMvOL9NuzHoyYb0KiseQyw_QEAQZqyb',
  );

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => SettingsProvider())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return MaterialApp(
          title: 'Quran App',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF10B981),
              brightness: Brightness.light,
              primary: const Color(0xFF10B981),
              surface: Colors.white,
            ),
            textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
            // Pass the font size to the text theme globally or handle locally
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF020617),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF10B981),
              brightness: Brightness.dark,
              primary: const Color(0xFF10B981),
              surface: const Color(0xFF0F172A),
            ),
            textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
