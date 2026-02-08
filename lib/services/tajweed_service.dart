import 'package:flutter/material.dart';

class TajweedRenderer {
  // Colors from the user provided image
  static const Color ghunnaColor = Color(0xFFFF7E1E); // Orange
  static const Color idghaamGhunnaColor = Color(0xFFE44CD4); // Magenta
  static const Color idghaamNoGhunnaColor = Color(0xFF9E9E9E); // Gray
  static const Color idghaamMeemColor = Color(0xFFE6E600); // Yellow
  static const Color iqlaabColor = Color(0xFF26A69A); // Teal
  static const Color ikhfaaColor = Color(0xFFFF3D00); // Red
  static const Color qalqalaColor = Color(0xFF00C853); // Green

  /// Parses the Arabic text and returns a list of TextSpans with Tajweed coloring.
  static List<TextSpan> getTajweedSpans(
    String text,
    TextStyle baseStyle, {
    bool isIndopak = true,
  }) {
    List<TextSpan> spans = [];
    int currentIndex = 0;

    // -------------------------------------------------------------------------
    // 1. Define Character Constraints
    // -------------------------------------------------------------------------

    // Marks that are "Safe" to appear on a Saakin letter (e.g. Waqf, Tatweel, Superscripts, Sukoon)
    // \u0652: Sukoon (Round)
    // \u06E1: Sukoon (Dotless Head of Khah - Uthmani style)
    // \u0670: Superscript Alif
    // \u0653: Maddah
    // \u0654: Hamza Above
    // \u06D6-\u06ED: Waqf signs (inc. small meems \u06E2, \u06ED)
    // \u06E5, \u06E6: Small high marks
    // \u0640: Tatweel
    // \u0656: Subscript Aleph
    final String safeMarks =
        r'[\u0652\u06E1\u0670\u0653\u0654\u06D6-\u06ED\u06E5\u06E6\u0640\u0656]*';

    // explicitSukoon matches the actual Sukoon symbol (Round or Khah-head)
    final String explicitSukoon = r'[\u0652\u06E1]';

    // Separator allowed between a Saakin letter and the next letter
    // Can be spaces, Tatweel, Alif (for Tanween), or Waqf signs
    final String separator = r'[\s\u0640\u0627\u06D6-\u06ED\u06E5\u06E6]*';

    // -------------------------------------------------------------------------
    // 2. Define Regex Patterns
    // -------------------------------------------------------------------------

    // General Marks (for things that CAN have vowels like Ghunna)
    // Includes standard marks \u064B-\u065F, and Uthmani Open Tanween \u08F0-\u08F2
    final String allMarks =
        r'[\u064B-\u065F\u0670\u06D6-\u06ED\u06E5\u06E6\u0640\u08F0-\u08F2\u06E2\u06ED]*';

    // 1. Ghunna (Noon/Meem Shadda)
    // Pattern: [Noon/Meem] + [Marks] + [Shadda]
    final RegExp ghunnaRegex = RegExp(
      r'([\u0646\u0645]' + allMarks + r'\u0651' + allMarks + r')',
    );

    // 2. Qalqala (Q5: Qaf, Taa, Ba, Jeem, Dal) with Sukoon
    // Pattern: [Q5 Letter] + [SafeMarks] + [Sukoon]
    final RegExp qalqalaRegex = RegExp(
      r'([\u0642\u0637\u0628\u062c\u062d\u062f]' +
          safeMarks +
          explicitSukoon +
          safeMarks +
          r')',
    );

    // 3. Ikhfaa / Idghaam Common Definitions
    // Noon Saakin: Noon + SafeMarks (no vowels)
    // Tanween: Previous Letter + [Marks] + [Tanween Mark] + [Marks]
    // Including the previous letter is CRITICAL to keep mark anchoring and ligation.
    final String noonSaakin = r'(\u0646' + safeMarks + r')';
    final String tanween =
        r'([\u0621-\u064a]' +
        allMarks +
        r'[\u064b\u064c\u064d\u08F0\u08F1\u08F2]' +
        allMarks +
        r')';

    // Group matching either Noon Saakin OR Tanween
    final String noonOrTanween = r'(' + noonSaakin + r'|' + tanween + r')';

    // 3. Ikhfaa - Noon/Tanween + following Ikhfaa letter
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

    // Idghaam Meem Saakin: Meem Sukoon + Following Meem
    final RegExp idghaamMeemRegex = RegExp(
      r'(\u0645' + safeMarks + r')' + separator + r'\u0645' + allMarks,
    );

    // 5. Iqlaab: Noon/Tanween -> Ba
    // Supports High Meem (\u06E2) and Low Meem (\u06ED)
    // Note: We MUST include the following Ba (\u0628) in the span to keep it joined to its vowel.
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
        // Check if current char is a waqf sign
        int codeUnit = text.codeUnitAt(currentIndex);

        // Strict Waqf signs for Indopak spacing
        // \u06D6-\u06DC are the major floating pause signs
        // Exclude \u06E5, \u06E6 (Small Waw/Ya) as they can be part of the word flow
        bool isWaqf = (codeUnit >= 0x06D6 && codeUnit <= 0x06DC);

        if (isWaqf && isIndopak) {
          // Robust Indopak Waqf sign positioning
          // \u200C (ZWNJ) disconnects the sign from the base letter
          // \u2009 (Thin Space) provides precise leftward spacing
          // Multiple thin spaces create the "floating" effect
          String signText =
              "\u200C\u2009\u2009\u2009${text[currentIndex]}\u2009";
          spans.add(
            TextSpan(
              text: signText,
              style: baseStyle.copyWith(
                color: baseStyle.color,
                // fontSize: baseStyle.fontSize, // Keep original size
              ),
            ),
          );
          currentIndex++;
        } else {
          // Normal character
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

          // Stop at Waqf signs for Indopak
          if (isIndopak) {
            int nextWaqfIndex = -1;
            for (int i = 0; i < remaining.length; i++) {
              int cu = remaining.codeUnitAt(i);
              bool isNextWaqf = (cu >= 0x06D6 && cu <= 0x06DC);
              if (isNextWaqf) {
                nextWaqfIndex = currentIndex + i;
                break;
              }
            }

            if (nextWaqfIndex != -1 && nextWaqfIndex < nextMatchIndex) {
              nextMatchIndex = nextWaqfIndex;
            }
          }

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
    }

    return spans;
  }
}
