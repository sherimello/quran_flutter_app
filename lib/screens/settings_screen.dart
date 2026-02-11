import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/tajweed_service.dart';
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
              if (settings.showWordByWord)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('WBW Language'),
                        trailing: DropdownButton<String>(
                          value: settings.wordByWordLanguage,
                          onChanged: (String? value) {
                            if (value != null) {
                              settings.setWordByWordLanguage(value);
                            }
                          },
                          items: const [
                            DropdownMenuItem(
                              value: 'en',
                              child: Text('English'),
                            ),
                            DropdownMenuItem(
                              value: 'bn',
                              child: Text('Bengali'),
                            ),
                            DropdownMenuItem(
                              value: 'in',
                              child: Text('Indonesian'),
                            ),
                            DropdownMenuItem(value: 'ur', child: Text('Urdu')),
                            DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                            DropdownMenuItem(
                              value: 'tr',
                              child: Text('Turkish'),
                            ),
                            DropdownMenuItem(
                              value: 'ru',
                              child: Text('Russian'),
                            ),
                            DropdownMenuItem(
                              value: 'fr',
                              child: Text('French'),
                            ),
                            DropdownMenuItem(
                              value: 'de',
                              child: Text('German'),
                            ),
                            DropdownMenuItem(
                              value: 'zh',
                              child: Text('Chinese'),
                            ),
                            DropdownMenuItem(value: 'ta', child: Text('Tamil')),
                            DropdownMenuItem(
                              value: 'ml',
                              child: Text('Malayalam'),
                            ),
                            DropdownMenuItem(
                              value: 'fa',
                              child: Text('Persian'),
                            ),
                          ],
                        ),
                      ),
                      if (settings.wordByWordLanguage == 'en') ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('WBW Transliteration'),
                          trailing: DropdownButton<String>(
                            value: settings.wordByWordTransliteration,
                            onChanged: (String? value) {
                              if (value != null) {
                                settings.setWordByWordTransliteration(value);
                              }
                            },
                            items: const [
                              DropdownMenuItem(
                                value: 'en_trans',
                                child: Text('English'),
                              ),
                              // Add more if db has them
                            ],
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Show WBW Transliteration'),
                          subtitle: const Text(
                            'Display English transliteration in Word-by-Word',
                          ),
                          value: settings.showWbwTransliteration,
                          activeColor: Colors.orange,
                          onChanged: (bool value) {
                            settings.setShowWbwTransliteration(value);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              SwitchListTile(
                title: const Text('Tajweed Coloring'),
                subtitle: const Text('Highlight rules (Ikhfaa, Idghaam, etc.)'),
                value: settings.enableTajweed,
                activeColor: Colors.orange,
                onChanged: (bool value) {
                  settings.setEnableTajweed(value);
                },
              ),
              if (settings.enableTajweed)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Color Legend:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _buildLegendItem(
                            'Ghunna (2 Harakat)',
                            TajweedRenderer.ghunnaColor,
                          ),
                          _buildLegendItem(
                            'Idghaam (w/ Ghunna)',
                            TajweedRenderer.idghaamGhunnaColor,
                          ),
                          _buildLegendItem(
                            'Idghaam (No Ghunna)',
                            TajweedRenderer.idghaamNoGhunnaColor,
                          ),
                          _buildLegendItem(
                            'Idghaam Meem',
                            TajweedRenderer.idghaamMeemColor,
                          ),
                          _buildLegendItem(
                            'Iqlaab',
                            TajweedRenderer.iqlaabColor,
                          ),
                          _buildLegendItem(
                            'Ikhfaa',
                            TajweedRenderer.ikhfaaColor,
                          ),
                          _buildLegendItem(
                            'Qalqala',
                            TajweedRenderer.qalqalaColor,
                          ),
                        ],
                      ),
                    ],
                  ),
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

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
