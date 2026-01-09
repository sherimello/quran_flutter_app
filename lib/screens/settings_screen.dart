import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Appearance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Theme'),
                trailing: DropdownButton<ThemeMode>(
                  value: settings.themeMode,
                  onChanged: (ThemeMode? newMode) {
                    if (newMode != null) {
                      settings.setThemeMode(newMode);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('System'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark'),
                    ),
                  ],
                ),
              ),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Reading',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('Font Size'),
              Slider(
                value: settings.fontSize,
                min: 14.0,
                max: 40.0,
                divisions: 13,
                label: settings.fontSize.round().toString(),
                onChanged: (double value) {
                  settings.setFontSize(value);
                },
              ),
              Center(
                child: Text(
                  'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيم',
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: settings.fontSize,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
