import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'widget_settings_screen.dart';

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
                  'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
                  style: TextStyle(
                    fontFamily: settings.arabicScript == 'utsmani'
                        ? 'hafs'
                        : 'qalammajeed3',
                    fontSize: settings.fontSize + 6,
                  ),
                ),
              ),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Quran Display',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Arabic Script'),
                subtitle: const Text('Choose Arabic text style'),
                trailing: DropdownButton<String>(
                  value: settings.arabicScript,
                  onChanged: (String? value) {
                    if (value != null) {
                      settings.setArabicScript(value);
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 'indopak', child: Text('Indopak')),
                    DropdownMenuItem(value: 'utsmani', child: Text('Uthmani')),
                  ],
                ),
              ),
              ListTile(
                title: const Text('Translation'),
                subtitle: const Text('Choose translation language'),
                trailing: DropdownButton<String>(
                  value: settings.translation,
                  onChanged: (String? value) {
                    if (value != null) {
                      settings.setTranslation(value);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: 'sahih',
                      child: Text('Sahih International'),
                    ),
                    DropdownMenuItem(
                      value: 'jalalayn',
                      child: Text('Jalalayn'),
                    ),
                  ],
                ),
              ),
              ListTile(
                title: const Text('Pronunciation'),
                subtitle: const Text('Show transliteration'),
                trailing: DropdownButton<String>(
                  value: settings.pronunciation,
                  onChanged: (String? value) {
                    if (value != null) {
                      settings.setPronunciation(value);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: 'latin_english',
                      child: Text('Latin English'),
                    ),
                    DropdownMenuItem(value: 'latin', child: Text('Latin')),
                    DropdownMenuItem(value: 'none', child: Text('None')),
                  ],
                ),
              ),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Advanced Features',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Show Tafseer'),
                subtitle: const Text('Display explanation below each verse'),
                value: settings.showTafseer,
                onChanged: (bool value) {
                  settings.setShowTafseer(value);
                },
              ),
              SwitchListTile(
                title: const Text('Word-by-Word Translation'),
                subtitle: const Text('Show individual word meanings'),
                value: settings.showWordByWord,
                onChanged: (bool value) {
                  settings.setShowWordByWord(value);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.widgets),
                title: const Text('Home Screen Widget'),
                subtitle: const Text('Manage verses & behavior'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WidgetSettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
