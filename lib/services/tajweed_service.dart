import 'package:flutter/material.dart';

import '../utils/waqf_spacing.dart';

class TajweedRenderer {
  // Colors for Tajweed rules
  static const Color ghunnaColor = Color(0xFFFF7E1E); // Orange
  static const Color idghaamGhunnaColor = Color(0xFFE44CD4); // Magenta
  static const Color idghaamNoGhunnaColor = Color(0xFF9E9E9E); // Gray
  static const Color idghaamMeemColor = Color(0xFFE6E600); // Yellow
  static const Color iqlaabColor = Color(0xFF26A69A); // Teal
  static const Color ikhfaaColor = Color(0xFFFF3D00); // Red
  static const Color qalqalaColor = Color(0xFF00C853); // Green

  /// Clean control characters (ZWNJ, thin spaces) and fix diacritic spacing.
  /// For the Indo-Pak font also spaces the waqf pause marks (see [WaqfSpacing]);
  /// the Uthmani text already has spaces around its marks.
  static String cleanArabicText(String input, {bool indopak = true}) {
    if (input.isEmpty) return input;

    // 1. Remove zero-width control characters and extra thin spaces
    String text = input.replaceAll(RegExp(r'[\u200B-\u200D\u2009\uFEFF]'), '');

    // 2. Remove accidental spaces before diacritics / Maddah
    text = text.replaceAllMapped(
      RegExp(r'\s+([\u064B-\u065F\u0670\u06E4\u08F0-\u08F2])'),
      (m) => '${m.group(1)}',
    );

    // 3. Collapse multiple regular spaces into a single space
    text = text.replaceAll(RegExp(r' +'), ' ').trim();

    // 4. Space the pause marks last, so step 3 doesn't collapse the gaps.
    // Non-breaking and thin spaces don't work here: in qalammajeed3 the NBSP is
    // a zero-width mark and U+2009 isn't in the font at all.
    if (indopak) text = WaqfSpacing.apply(text);

    return text;
  }

  /// Parses the Arabic text and returns a list of TextSpans with Tajweed coloring.
  static List<TextSpan> getTajweedSpans(
    String text,
    TextStyle baseStyle, {
    bool isIndopak = true,
  }) {
    text = cleanArabicText(text, indopak: isIndopak);

    List<TextSpan> spans = [];
    int currentIndex = 0;

    // -------------------------------------------------------------------------
    // 1. Define Character Constraints
    // EXCLUDE Waqf pause marks (\u06D6-\u06DC, \u06E2, \u06ED) from Tajweed rule
    // matching so pause notations are never engulfed into rule matches and
    // remain styled in baseStyle.color.
    // -------------------------------------------------------------------------

    final String safeMarks =
        r'[\u0652\u06E1\u0670\u0653\u0654\u06E5\u06E6\u0640\u0656]*';

    final String explicitSukoon = r'[\u0652\u06E1]';

    final String separator = r'[\s\u0640\u0627]*';

    final String allMarks =
        r'[\u064B-\u065F\u0670\u06E5\u06E6\u0640\u08F0-\u08F2]*';

    // 1. Ghunna (Noon/Meem Shadda)
    final RegExp ghunnaRegex = RegExp(
      r'([\u0646\u0645]' + allMarks + r'\u0651' + allMarks + r')',
    );

    // 2. Qalqala (Q5: Qaf, Taa, Ba, Jeem, Dal) with Sukoon
    final RegExp qalqalaRegex = RegExp(
      r'([\u0642\u0637\u0628\u062c\u062d\u062f]' +
          safeMarks +
          explicitSukoon +
          safeMarks +
          r')',
    );

    // 3. Ikhfaa / Idghaam Common Definitions
    final String noonSaakin = r'(\u0646' + safeMarks + r')';
    final String tanween =
        r'([\u0621-\u064a]' +
        allMarks +
        r'[\u064b\u064c\u064d\u08F0\u08F1\u08F2]' +
        allMarks +
        r')';

    final String noonOrTanween = r'(' + noonSaakin + r'|' + tanween + r')';

    // 3. Ikhfaa
    final String ikhfaaLetters =
        r'[\u062a\u062b\u062c\u062d\u062f\u0630\u0632\u0633\u0634\u0635\u0636\u0637\u0638\u0641\u0642\u0643]';
    final RegExp ikhfaaRegex = RegExp(
      noonOrTanween + separator + ikhfaaLetters + allMarks,
    );

    // 4. Idghaam w/ Ghunna
    final String idghaamGhunnaLetters = r'[\u064a\u0646\u0645\u0648]';
    final RegExp idghaamGhunnaRegex = RegExp(
      noonOrTanween + separator + idghaamGhunnaLetters + allMarks,
    );

    // Idghaam w/o Ghunna
    final String idghaamNoGhunnaLetters = r'[\u0644\u0631]';
    final RegExp idghaamNoGhunnaRegex = RegExp(
      noonOrTanween + separator + idghaamNoGhunnaLetters + allMarks,
    );

    // Idghaam Meem Saakin
    final RegExp idghaamMeemRegex = RegExp(
      r'(\u0645' + safeMarks + r')' + separator + r'\u0645' + allMarks,
    );

    // 5. Iqlaab
    final String iqlaabTrigger =
        r'([\u0646\u0621-\u064a]' +
        allMarks +
        r'[\u06e2\u06ed\u064b\u064c\u064d\u08F0\u08F1\u08F2]' +
        allMarks +
        r')';

    final RegExp iqlaabRegex = RegExp(
      iqlaabTrigger + separator + r'\u0628' + allMarks,
    );

    while (currentIndex < text.length) {
      Match? bestMatch;
      Color? matchColor;
      int matchLength = 0;

      String remaining = text.substring(currentIndex);

      void check(RegExp regex, Color color) {
        Match? m = regex.matchAsPrefix(remaining);
        if (m != null) {
          if (bestMatch == null || m.end > matchLength) {
            bestMatch = m;
            matchColor = color;
            matchLength = m.end;
          }
        }
      }

      // Check all rules (order = priority)
      check(idghaamMeemRegex, idghaamMeemColor);
      check(idghaamGhunnaRegex, idghaamGhunnaColor);
      check(idghaamNoGhunnaRegex, idghaamNoGhunnaColor);
      check(iqlaabRegex, iqlaabColor);
      check(ikhfaaRegex, ikhfaaColor);
      check(ghunnaRegex, ghunnaColor);
      check(qalqalaRegex, qalqalaColor);

      if (bestMatch != null) {
        String matchText = remaining.substring(0, bestMatch!.end);

        spans.add(
          TextSpan(
            text: matchText,
            style: baseStyle.copyWith(color: matchColor),
          ),
        );
        currentIndex += bestMatch!.end;
      } else {
        // Normal character chunk processing
        int nextMatchIndex = text.length;

        void findNext(RegExp regex) {
          Match? m = regex.firstMatch(remaining);
          if (m != null) {
            if ((currentIndex + m.start) < nextMatchIndex) {
              nextMatchIndex = currentIndex + m.start;
            }
          }
        }

        findNext(idghaamMeemRegex);
        findNext(idghaamGhunnaRegex);
        findNext(idghaamNoGhunnaRegex);
        findNext(iqlaabRegex);
        findNext(ikhfaaRegex);
        findNext(ghunnaRegex);
        findNext(qalqalaRegex);

        if (nextMatchIndex > currentIndex) {
          String normalText = text.substring(currentIndex, nextMatchIndex);
          spans.add(TextSpan(text: normalText, style: baseStyle));
          currentIndex = nextMatchIndex;
        } else {
          spans.add(TextSpan(text: text[currentIndex], style: baseStyle));
          currentIndex++;
        }
      }
    }

    // Give every pause mark its own shaping run; otherwise the font's
    // contextual positioning tucks it against the previous letter's marks
    // (e.g. the madd stroke in 2:1) and the spacing has no effect.
    return isIndopak ? spans.expand(WaqfSpacing.isolateSigns).toList() : spans;
  }
}
