import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_flutter_app/services/tajweed_service.dart';

void main() {
  group('TajweedRenderer & Arabic Text Formatting Tests', () {
    test('getTajweedSpans does not insert ZWNJ', () {
      const sampleText = 'مِنْ قَبْلِهِ ۚ وَهُوَ عَلِيمٌ';
      final spans = TajweedRenderer.getTajweedSpans(
        sampleText,
        const TextStyle(fontFamily: 'qalammajeed3', fontSize: 24, color: Colors.white),
        isIndopak: true,
      );

      final fullResult = spans.map((s) => s.text).join();
      expect(fullResult.contains('\u200C'), false, reason: 'ZWNJ should not be inserted');
    });

    test('cleanArabicText spaces pause marks with plain spaces (Indo-Pak)', () {
      // Jeem (U+06DA): 3 spaces each side; Sala (U+06D6): 4 each side.
      // NBSP / thin spaces must not be used: NBSP is a zero-width mark in
      // qalammajeed3 and U+2009 is not in the font.
      const raw1 = 'ٱلۡأَرۡضِ ۚ أُوْلَٰٓئِكَ';
      expect(TajweedRenderer.cleanArabicText(raw1), 'ٱلۡأَرۡضِ   ۚ   أُوْلَٰٓئِكَ');

      const raw2 = 'ا ۖ و';
      expect(TajweedRenderer.cleanArabicText(raw2), 'ا    ۖ    و');

      const raw3 = 'مۡ ۖ و';
      expect(TajweedRenderer.cleanArabicText(raw3), 'مۡ    ۖ    و');

      const raw4 = 'فَوۡقَهَا ۚ فَأَمَّا';
      expect(TajweedRenderer.cleanArabicText(raw4), 'فَوۡقَهَا   ۚ   فَأَمَّا');

      // Old padding (NBSP + thin spaces) saved earlier is normalised too.
      const legacy =
          'ا\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u2009\u2009\u2009\u2009ۚ\u2009 و';
      expect(TajweedRenderer.cleanArabicText(legacy), 'ا   ۚ   و');
    });

    test('cleanArabicText leaves Uthmani text spacing alone', () {
      const raw = 'ٱلۡأَرۡضِ ۚ أُوْلَٰٓئِكَ';
      expect(TajweedRenderer.cleanArabicText(raw, indopak: false), raw);
    });

    test('Waqf pause marks (Jeem U+06DA) are not engulfed into Tajweed rule colors', () {
      const sampleGhunnaWithJeem = 'إِنَّ\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u2009\u2009\u2009\u2009ۚ\u2009 هُوَ';
      final spans = TajweedRenderer.getTajweedSpans(
        sampleGhunnaWithJeem,
        const TextStyle(color: Colors.white, fontSize: 24),
      );

      bool foundJeemInBaseColor = false;
      for (final span in spans) {
        if (span.text!.contains('\u06DA') && span.style?.color == Colors.white) {
          foundJeemInBaseColor = true;
        }
      }
      expect(foundJeemInBaseColor, true, reason: 'Jeem U+06DA must be rendered in baseStyle color');
    });
  });
}
