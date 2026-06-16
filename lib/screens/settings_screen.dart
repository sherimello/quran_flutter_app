import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/settings_provider.dart';
import '../services/tajweed_service.dart';
import 'widget_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primary = Theme.of(context).colorScheme.primary;
        final size = MediaQuery.of(context).size;

        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            toolbarHeight: AppBar().preferredSize.height * 1.5,
            title: Text(
              'Settings',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: size.width * .041,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
            children: [
              // _AppHeader(isDark: isDark, primary: primary, size: size),
              // const SizedBox(height: 28),
              _SectionLabel(label: 'Appearance', primary: primary),
              // const SizedBox(height: 10),
              _sectionCard(
                isDark,
                child: _SegmentRow(
                  label: 'Theme',
                  icon: CupertinoIcons.circle_lefthalf_fill,
                  options: const ['System', 'Light', 'Dark'],
                  selected: settings.themeMode == ThemeMode.system
                      ? 'System'
                      : settings.themeMode == ThemeMode.light
                      ? 'Light'
                      : 'Dark',
                  onSelect: (val) {
                    final mode = val == 'System'
                        ? ThemeMode.system
                        : val == 'Light'
                        ? ThemeMode.light
                        : ThemeMode.dark;
                    settings.setThemeMode(mode);
                  },
                  isDark: isDark,
                  primary: primary,
                ),
              ),

              const SizedBox(height: 28),

              _SectionLabel(label: 'Typography', primary: primary),
              const SizedBox(height: 10),
              _sectionCard(
                isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SliderRow(
                      label: 'Arabic Size',
                      icon: CupertinoIcons.textformat_size,
                      value: settings.arabicFontSize,
                      min: 20,
                      max: 50,
                      divisions: 30,
                      isDark: isDark,
                      primary: primary,
                      onChanged: settings.setArabicFontSize,
                    ),
                    // _divider(isDark),
                    _SliderRow(
                      label: 'Translation Size',
                      icon: CupertinoIcons.textformat,
                      value: settings.translationFontSize,
                      min: 12,
                      max: 30,
                      divisions: 18,
                      isDark: isDark,
                      primary: primary,
                      onChanged: settings.setTranslationFontSize,
                    ),
                    // _divider(isDark),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                        // decoration: BoxDecoration(
                        //   color: primary.withValues(alpha: 0.06),
                        //   borderRadius: BorderRadius.circular(16),
                        //   border: Border.all(
                        //     color: primary.withValues(alpha: 0.18),
                        //   ),
                        // ),
                        child: Column(
                          children: [
                            Text(
                              'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
                              style: TextStyle(
                                fontFamily: settings.arabicScript == 'utsmani'
                                    ? 'hafs'
                                    : 'qalammajeed3',
                                fontSize: settings.arabicFontSize * .9,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 11),
                            Text(
                              'In the name of Allah, the Entirely Merciful,the Especially Merciful.',
                              style: GoogleFonts.poppins(
                                fontSize: settings.translationFontSize * .9,
                                color: isDark ? Colors.white60 : Colors.black54,
                                height: 0,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              _SectionLabel(label: 'Quran Display', primary: primary),
              const SizedBox(height: 10),
              _sectionCard(
                isDark,
                child: Column(
                  children: [
                    _SegmentRow(
                      label: 'Arabic Script',
                      icon: CupertinoIcons.collections,
                      subtitle: 'Text rendering style',
                      options: const ['Indopak', 'Uthmani'],
                      selected: settings.arabicScript == 'utsmani'
                          ? 'Uthmani'
                          : 'Indopak',
                      onSelect: (val) => settings.setArabicScript(
                        val == 'Uthmani' ? 'utsmani' : 'indopak',
                      ),
                      isDark: isDark,
                      primary: primary,
                    ),
                    // _divider(isDark),
                    _SegmentRow(
                      label: 'Translation',
                      icon: CupertinoIcons.globe,
                      subtitle: 'English translation source',
                      options: const ['Sahih Int\'l', 'Jalalayn'],
                      selected: settings.translation == 'sahih'
                          ? 'Sahih Int\'l'
                          : 'Jalalayn',
                      onSelect: (val) => settings.setTranslation(
                        val == 'Sahih Int\'l' ? 'sahih' : 'jalalayn',
                      ),
                      isDark: isDark,
                      primary: primary,
                    ),
                    // _divider(isDark),
                    _SegmentRow(
                      label: 'Pronunciation',
                      icon: CupertinoIcons.speaker_2,
                      subtitle: 'Transliteration display',
                      options: const ['Latin+Eng', 'Latin', 'None'],
                      selected: settings.pronunciation == 'latin_english'
                          ? 'Latin+Eng'
                          : settings.pronunciation == 'latin'
                          ? 'Latin'
                          : 'None',
                      onSelect: (val) => settings.setPronunciation(
                        val == 'Latin+Eng'
                            ? 'latin_english'
                            : val == 'Latin'
                            ? 'latin'
                            : 'none',
                      ),
                      isDark: isDark,
                      primary: primary,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              _SectionLabel(label: 'Advanced', primary: primary),
              const SizedBox(height: 10),
              _sectionCard(
                isDark,
                child: Column(
                  children: [
                    _SwitchRow(
                      icon: CupertinoIcons.book,
                      label: 'Show Tafseer',
                      subtitle: 'Interpretation below each verse',
                      value: settings.showTafseer,
                      isDark: isDark,
                      primary: primary,
                      onChanged: settings.setShowTafseer,
                    ),
                    // _divider(isDark),
                    _SwitchRow(
                      icon: CupertinoIcons.textformat_size,
                      label: 'Word-by-Word',
                      subtitle: 'Individual word meanings',
                      value: settings.showWordByWord,
                      isDark: isDark,
                      primary: primary,
                      onChanged: settings.setShowWordByWord,
                    ),
                    if (settings.showWordByWord) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 20),
                        child: _SwitchRow(
                          icon: CupertinoIcons.textformat_abc,
                          label: 'WBW Transliteration',
                          subtitle: 'Latin transliteration per word',
                          value: settings.showWbwTransliteration,
                          isDark: isDark,
                          primary: primary,
                          isSubItem: true,
                          onChanged: settings.setShowWbwTransliteration,
                        ),
                      ),
                    ],
                    // _divider(isDark),
                    _SwitchRow(
                      icon: CupertinoIcons.paintbrush,
                      label: 'Tajweed Coloring',
                      subtitle: 'Highlight recitation rules',
                      value: settings.enableTajweed,
                      isDark: isDark,
                      primary: primary,
                      onChanged: settings.setEnableTajweed,
                    ),
                    if (settings.enableTajweed) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Row(
                            //   children: [
                            // Container(
                            //   width: 3,
                            //   height: 13,
                            //   decoration: BoxDecoration(
                            //     color: primary,
                            //     borderRadius: BorderRadius.circular(2),
                            //   ),
                            // ),
                            // const SizedBox(width: 8),
                            // Text(
                            //   'Color Legend',
                            //   style: GoogleFonts.poppins(
                            //     fontSize: 11,
                            //     fontWeight: FontWeight.w700,
                            //     color: isDark
                            //         ? Colors.white38
                            //         : Colors.black38,
                            //     letterSpacing: 0.8,
                            //   ),
                            // ),
                            //   ],
                            // ),
                            const SizedBox(height: 10),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _legendChip(
                                  'Ghunna',
                                  TajweedRenderer.ghunnaColor,
                                  isDark,
                                ),
                                _legendChip(
                                  'Idghaam+G',
                                  TajweedRenderer.idghaamGhunnaColor,
                                  isDark,
                                ),
                                _legendChip(
                                  'Idghaam',
                                  TajweedRenderer.idghaamNoGhunnaColor,
                                  isDark,
                                ),
                                _legendChip(
                                  'Idghaam M',
                                  TajweedRenderer.idghaamMeemColor,
                                  isDark,
                                ),
                                _legendChip(
                                  'Iqlaab',
                                  TajweedRenderer.iqlaabColor,
                                  isDark,
                                ),
                                _legendChip(
                                  'Ikhfaa',
                                  TajweedRenderer.ikhfaaColor,
                                  isDark,
                                ),
                                _legendChip(
                                  'Qalqala',
                                  TajweedRenderer.qalqalaColor,
                                  isDark,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 28),

              _SectionLabel(label: 'AI Search', primary: primary),
              const SizedBox(height: 10),
              _sectionCard(
                isDark,
                child: Column(
                  children: [
                    _SegmentRow(
                      label: 'AI Provider',
                      icon: CupertinoIcons.sparkles,
                      subtitle: 'For contextual verse search',
                      options: const ['None', 'Groq', 'Cohere'],
                      selected: settings.aiProvider == 'groq'
                          ? 'Groq'
                          : settings.aiProvider == 'cohere'
                          ? 'Cohere'
                          : 'None',
                      onSelect: (val) => settings.setAiProvider(
                        val == 'Groq'
                            ? 'groq'
                            : val == 'Cohere'
                            ? 'cohere'
                            : 'none',
                      ),
                      isDark: isDark,
                      primary: primary,
                    ),
                    if (settings.aiProvider != 'none') ...[
                      if (settings.aiProvider == 'groq') ...[
                        _ApiKeyRow(
                          key: const ValueKey('groq_key'),
                          label: 'Groq API Key',
                          isDark: isDark,
                          primary: primary,
                          currentKey: settings.groqApiKey,
                          onChanged: settings.setGroqApiKey,
                        ),
                        _ApiKeyGuide(
                          isDark: isDark,
                          url: 'https://console.groq.com/keys',
                          steps: const [
                            'Go to console.groq.com and sign up for free',
                            'Open the API Keys section from the left sidebar',
                            'Click "Create API Key", give it a name, and copy it here',
                          ],
                          note:
                              'Free tier — fast inference on LLaMA, Gemma & Mistral models with generous rate limits.',
                        ),
                      ],
                      if (settings.aiProvider == 'cohere') ...[
                        _ApiKeyRow(
                          key: const ValueKey('cohere_key'),
                          label: 'Cohere API Key',
                          isDark: isDark,
                          primary: primary,
                          currentKey: settings.cohereApiKey,
                          onChanged: settings.setCohereApiKey,
                        ),
                        _ApiKeyGuide(
                          isDark: isDark,
                          url: 'https://dashboard.cohere.com/api-keys',
                          steps: const [
                            'Go to dashboard.cohere.com and create a free account',
                            'Navigate to "API Keys" in the left menu',
                            'Click "New Trial Key", then copy the key here',
                          ],
                          note:
                              'Trial key is free — Command R+ and Command A are ideal for Quranic context search.',
                        ),
                      ],
                      _ModelDropdownRow(
                        isDark: isDark,
                        primary: primary,
                        provider: settings.aiProvider,
                        selectedModel: settings.aiProvider == 'groq'
                            ? settings.groqModel
                            : settings.cohereModel,
                        onChanged: settings.aiProvider == 'groq'
                            ? settings.setGroqModel
                            : settings.setCohereModel,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 28),

              _SectionLabel(label: 'More', primary: primary),
              const SizedBox(height: 10),
              _sectionCard(
                isDark,
                child: _NavRow(
                  icon: CupertinoIcons.square_grid_2x2,
                  label: 'Home Screen Widget',
                  subtitle: 'Configure widget verses & behavior',
                  isDark: isDark,
                  primary: primary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WidgetSettingsScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _sectionCard(bool isDark, {required Widget child}) {
    return Container(
      // decoration: BoxDecoration(
      // color: isDark ? const Color(0xFF111111) : Colors.white,
      // borderRadius: BorderRadius.circular(24),
      // border: Border.all(
      //   color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
      // ),
      //   boxShadow: isDark
      //       ? []
      //       : [
      //           BoxShadow(
      //             color: Colors.black.withValues(alpha: 0.05),
      //             blurRadius: 18,
      //             offset: const Offset(0, 5),
      //           ),
      //         ],
      // ),
      child: child,
    );
  }

  static Widget _divider(bool isDark) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
    );
  }

  static Widget _legendChip(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.17),
        borderRadius: BorderRadius.circular(20),
        // border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  final bool isDark;
  final Color primary;
  final Size size;

  const _AppHeader({
    required this.isDark,
    required this.primary,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size.width * .055,
        vertical: size.width * .048,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  primary.withValues(alpha: 0.14),
                  primary.withValues(alpha: 0.04),
                ]
              : [
                  primary.withValues(alpha: 0.11),
                  primary.withValues(alpha: 0.03),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(size.width * .13),
          bottomLeft: Radius.circular(size.width * .07),
          topRight: Radius.circular(size.width * .18),
          bottomRight: Radius.circular(size.width * .12),
        ),
        border: Border.all(
          color: primary.withValues(alpha: isDark ? 0.22 : 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: size.width * .13,
            height: size.width * .13,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(size.width * .05),
                bottomLeft: Radius.circular(size.width * .03),
                topRight: Radius.circular(size.width * .07),
                bottomRight: Radius.circular(size.width * .06),
              ),
            ),
            child: Icon(
              CupertinoIcons.book_fill,
              color: primary,
              size: size.width * .055,
            ),
          ),
          SizedBox(width: size.width * .04),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quran',
                  style: GoogleFonts.poppins(
                    fontSize: size.width * .047,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                    height: 1.1,
                  ),
                ),
                Text(
                  'Customize your reading experience',
                  style: GoogleFonts.poppins(
                    fontSize: size.width * .029,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color primary;

  const _SectionLabel({required this.label, required this.primary});

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return Row(
      children: [
        // Container(
        //   width: 3,
        //   height: 14,
        //   decoration: BoxDecoration(
        //     color: primary,
        //     borderRadius: BorderRadius.circular(2),
        //   ),
        // ),
        // const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: size.width * .035,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class _SegmentRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? subtitle;
  final List<String> options;
  final String selected;
  final void Function(String) onSelect;
  final bool isDark;
  final Color primary;

  const _SegmentRow({
    required this.label,
    required this.icon,
    this.subtitle,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.isDark,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  // color: primary.withValues(alpha: 0.12),
                  color: const Color(0xff34da15),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(size.width * .65),
                    bottomLeft: Radius.circular(size.width * .5),
                    topRight: Radius.circular(size.width * .75),
                    bottomRight: Radius.circular(size.width * .75),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 0,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    if (subtitle != null) ...[
                      // const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          height: 0,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: options.map((opt) {
              final isSelected = opt == selected;
              final isLast = opt == options.last;
              return Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 8),
                child: GestureDetector(
                  onTap: () => onSelect(opt),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xff34da15)
                          : Colors.transparent,
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 17.0),
                      child: Text(
                        opt,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.black
                              : isDark
                              ? Colors.white70
                              : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final bool isDark;
  final Color primary;
  final void Function(double) onChanged;

  const _SliderRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.isDark,
    required this.primary,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 16, 8),
      child: SizedBox(
        width: size.width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xff34da15),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(size.width * .65),
                      bottomLeft: Radius.circular(size.width * .5),
                      topRight: Radius.circular(size.width * .75),
                      bottomRight: Radius.circular(size.width * .75),
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          Align(
                            alignment: AlignmentGeometry.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.17),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${value.round()}px',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 11),
                      SliderTheme(
                        data: SliderThemeData(
                          padding: EdgeInsets.zero,
                          trackHeight: 5,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 18,
                          ),
                          activeTrackColor: primary,
                          thumbColor: primary,
                          inactiveTrackColor: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.1),
                          overlayColor: primary.withValues(alpha: 0.15),
                        ),
                        child: Slider(
                          value: value,
                          min: min,
                          max: max,
                          divisions: divisions,
                          onChanged: onChanged,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final bool isDark;
  final Color primary;
  final bool isSubItem;
  final void Function(bool) onChanged;

  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.isDark,
    required this.primary,
    required this.onChanged,
    this.isSubItem = false,
  });

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        isSubItem ? 10 : 14,
        16,
        isSubItem ? 10 : 14,
      ),
      child: Row(
        children: [
          Container(
            width: isSubItem ? 32 : 38,
            height: isSubItem ? 32 : 38,
            decoration: BoxDecoration(
              color: const Color(0xff34da15),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(size.width * .65),
                bottomLeft: Radius.circular(size.width * .5),
                topRight: Radius.circular(size.width * .75),
                bottomRight: Radius.circular(size.width * .75),
              ),
            ),
            child: Icon(
              icon,
              size: isSubItem ? 16 : 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: isSubItem ? 13 : 14,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isDark;
  final Color primary;
  final VoidCallback onTap;

  const _NavRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isDark,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xff34da15),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(size.width * .65),
                  bottomLeft: Radius.circular(size.width * .5),
                  topRight: Radius.circular(size.width * .75),
                  bottomRight: Radius.circular(size.width * .75),
                ),
              ),
              child: Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(1000),
              ),
              child: Icon(
                CupertinoIcons.chevron_forward,
                size: 12,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApiKeyRow extends StatefulWidget {
  final String label;
  final bool isDark;
  final Color primary;
  final String currentKey;
  final void Function(String) onChanged;

  const _ApiKeyRow({
    super.key,
    required this.label,
    required this.isDark,
    required this.primary,
    required this.currentKey,
    required this.onChanged,
  });

  @override
  State<_ApiKeyRow> createState() => _ApiKeyRowState();
}

class _ApiKeyRowState extends State<_ApiKeyRow> {
  late final TextEditingController _controller;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentKey);
  }

  @override
  void didUpdateWidget(_ApiKeyRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync controller when the persisted key loads in from SharedPreferences
    // but don't interrupt the user's active typing (controller already matches)
    if (widget.currentKey != oldWidget.currentKey &&
        _controller.text != widget.currentKey) {
      _controller.text = widget.currentKey;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 16, 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xff34da15),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(size.width * .65),
                bottomLeft: Radius.circular(size.width * .5),
                topRight: Radius.circular(size.width * .75),
                bottomRight: Radius.circular(size.width * .75),
              ),
            ),
            child: Icon(
              CupertinoIcons.lock,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              obscureText: _obscure,
              style: GoogleFonts.poppins(fontSize: 13),
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                labelText: widget.label,
                labelStyle: GoogleFonts.poppins(fontSize: 12),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelDropdownRow extends StatelessWidget {
  final bool isDark;
  final Color primary;
  final String provider;
  final String selectedModel;
  final void Function(String) onChanged;

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

  const _ModelDropdownRow({
    required this.isDark,
    required this.primary,
    required this.provider,
    required this.selectedModel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final models = provider == 'groq' ? _groqModels : _cohereModels;
    final effectiveModel = models.containsKey(selectedModel)
        ? selectedModel
        : models.keys.first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 16, 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xff34da15),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(size.width * .65),
                bottomLeft: Radius.circular(size.width * .5),
                topRight: Radius.circular(size.width * .75),
                bottomRight: Radius.circular(size.width * .75),
              ),
            ),
            child: Icon(
              CupertinoIcons.cube_box,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Model',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 0,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                DropdownButton<String>(
                  value: effectiveModel,
                  isExpanded: true,
                  underline: const SizedBox(),
                  dropdownColor: isDark
                      ? const Color(0xFF1A1A1A)
                      : Colors.white,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
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
                    if (val != null) onChanged(val);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiKeyGuide extends StatelessWidget {
  final bool isDark;
  final String url;
  final List<String> steps;
  final String note;

  const _ApiKeyGuide({
    required this.isDark,
    required this.url,
    required this.steps,
    required this.note,
  });

  Future<void> _launch() async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final dim = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.5);
    final accent = const Color(0xff34da15);

    return Padding(
      padding: const EdgeInsets.fromLTRB(50, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: isDark ? 0.09 : 0.07),
          borderRadius: BorderRadius.circular(23),
          // border: Border.all(color: accent.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _launch,
              child: Row(
                children: [
                  Icon(CupertinoIcons.link, size: 13, color: accent),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      url.replaceFirst('https://', ''),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accent,
                        decoration: TextDecoration.underline,
                        decorationColor: accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...steps.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${e.key + 1}. ',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: dim,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.value,
                        style: GoogleFonts.poppins(fontSize: 11, color: dim),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              note,
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
                color: dim.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
