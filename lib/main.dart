import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:home_widget/home_widget.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://viljtvwbloyxrxklpbdj.supabase.co',
    anonKey: 'sb_publishable_eMvOL9NuzHoyYb0KiseQyw_QEAQZqyb',
  );

  await HomeWidget.setAppGroupId('group.com.example.quran_flutter_app');

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

          // LIGHT THEME — neon green on pure white
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: Colors.white,
            colorScheme: const ColorScheme(
              brightness: Brightness.light,
              primary: Color(0xFF39FF14),
              onPrimary: Colors.black,
              primaryContainer: Color(0xFFE6FFDF),
              onPrimaryContainer: Color(0xFF003A00),
              secondary: Color(0xFF2CC00F),
              onSecondary: Colors.black,
              secondaryContainer: Color(0xFFF0FFE8),
              onSecondaryContainer: Color(0xFF002200),
              tertiary: Color(0xFF39FF14),
              onTertiary: Colors.black,
              error: Color(0xFFD32F2F),
              onError: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
              outline: Color(0xFFE0E0E0),
              outlineVariant: Color(0xFFF0F0F0),
              surfaceTint: Colors.transparent,
            ),
            canvasColor: Colors.white,
            cardColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.black),
            ),
            sliderTheme: const SliderThemeData(
              activeTrackColor: Color(0xFF39FF14),
              thumbColor: Color(0xFF39FF14),
              inactiveTrackColor: Color(0xFFE0E0E0),
              overlayColor: Color(0x1A39FF14),
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.black;
                }
                return Colors.white;
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF39FF14);
                }
                return const Color(0xFFE0E0E0);
              }),
            ),
          ),

          // DARK THEME — neon green on pure black
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Colors.black,
            colorScheme: const ColorScheme(
              brightness: Brightness.dark,
              primary: Color(0xFF39FF14),
              onPrimary: Colors.black,
              primaryContainer: Color(0xFF001A00),
              onPrimaryContainer: Color(0xFF39FF14),
              secondary: Color(0xFF57FF3A),
              onSecondary: Colors.black,
              secondaryContainer: Color(0xFF002800),
              onSecondaryContainer: Color(0xFFAAFF99),
              tertiary: Color(0xFF39FF14),
              onTertiary: Colors.black,
              error: Color(0xFFFF6B6B),
              onError: Colors.black,
              surface: Color(0xFF0D0D0D),
              onSurface: Colors.white,
              outline: Color(0xFF2A2A2A),
              outlineVariant: Color(0xFF1A1A1A),
              surfaceTint: Colors.transparent,
            ),
            canvasColor: Colors.black,
            cardColor: const Color(0xFF111111),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
            ),
            sliderTheme: const SliderThemeData(
              activeTrackColor: Color(0xFF39FF14),
              thumbColor: Color(0xFF39FF14),
              inactiveTrackColor: Color(0xFF2A2A2A),
              overlayColor: Color(0x1A39FF14),
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.black;
                }
                return const Color(0xFF888888);
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF39FF14);
                }
                return const Color(0xFF2A2A2A);
              }),
            ),
          ),

          home: const SplashScreen(),
        );
      },
    );
  }
}
