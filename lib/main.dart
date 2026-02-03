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
          title: "Qur'an",
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          // --- LIGHT THEME UPDATE ---
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: Colors.white,
            // LIGHT THEME COLOR SCHEME
            colorScheme: const ColorScheme(
              brightness: Brightness.light,
              primary: Color(0xFF10B981),
              onPrimary: Colors.white,
              primaryContainer: Color(0xFFD1FAE5), // Light green, NOT purple
              onPrimaryContainer: Color(0xFF065F46),
              secondary: Color(0xFF059669),
              onSecondary: Colors.white,
              secondaryContainer: Color(0xFFECFDF5),
              onSecondaryContainer: Color(0xFF064E3B),
              tertiary: Color(0xFF10B981), // Overriding tertiary prevents random purple accents
              onTertiary: Colors.white,
              error: Colors.red,
              onError: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
              surfaceVariant: Colors.white, // Older versions of M3 use this
              outline: Color(0xFFE5E7EB),
              surfaceTint: Colors.transparent, // Crucial
            ),
            // This removes the tint from all NavigationBars/BottomSheets specifically
            canvasColor: Colors.white,
            cardColor: Colors.white,

            // Update your AppBarTheme to also ensure tint is gone
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.black),
            ),
            // ... rest of your code
          ),

// --- DARK THEME UPDATE ---
          darkTheme: ThemeData(
            useMaterial3: false,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Colors.black,
            // DARK THEME COLOR SCHEME
            colorScheme: const ColorScheme(
              brightness: Brightness.dark,
              primary: Color(0xFF10B981),
              onPrimary: Colors.white,
              primaryContainer: Color(0xFF065F46),
              onPrimaryContainer: Color(0xFFD1FAE5),
              secondary: Color(0xFF34D399),
              onSecondary: Colors.black,
              secondaryContainer: Color(0xFF064E3B),
              onSecondaryContainer: Color(0xFFECFDF5),
              tertiary: Color(0xFF34D399),
              onTertiary: Colors.black,
              error: Colors.red,
              onError: Colors.white,
              surface: Colors.black,
              onSurface: Colors.white,
              surfaceVariant: Colors.black,
              outline: Color(0xFF374151),
              surfaceTint: Colors.transparent, // Crucial
            ),
            canvasColor: Colors.black,
            cardColor: Colors.black,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
            ),
            // ... rest of your code
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
