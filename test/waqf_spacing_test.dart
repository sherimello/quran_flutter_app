import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_flutter_app/services/tajweed_service.dart';
import 'package:quran_flutter_app/utils/waqf_spacing.dart';

const _jeem = 'ۚ';
const _smallSeen = 'ۜ';
// Verse 2:1 in the Indo-Pak text: alif, lam+madd, meem+shadda+madd, jeem sign.
const _verse2_1 = 'الٓمّٓ$_jeem';
// "...of Allah" + jeem + "and who": the sign is glued to the words, no spaces.
const _glued = 'اللّٰهِ$_jeemوَمَنْ';

void main() {
  group('WaqfSpacing.apply', () {
    test('puts space on both sides of a glued sign', () {
      final out = WaqfSpacing.apply(_glued);
      expect(out, contains('هِ   $_jeem   و'));
    });

    test('uses wider gaps for the larger signs', () {
      expect(WaqfSpacing.apply('aۖb'), 'a    ۖ    b');
      expect(WaqfSpacing.apply('aۗb'), 'a    ۗ    b');
      for (final sign in ['ۘ', 'ۙ', 'ۚ', 'ۛ']) {
        expect(WaqfSpacing.apply('a${sign}b'), 'a   $sign   b', reason: sign);
      }
    });

    test('reserves the trailing gap for a verse-final sign', () {
      expect(WaqfSpacing.apply(_verse2_1).endsWith('$_jeem   '), isTrue);
    });

    test('normalises existing spaces instead of adding to them', () {
      expect(WaqfSpacing.apply('a $_jeem b'), 'a   $_jeem   b');
      expect(WaqfSpacing.apply('a      $_jeem b'), 'a   $_jeem   b');
    });

    test('is idempotent', () {
      for (final s in [_glued, _verse2_1, 'a $_jeem b', 'plain text']) {
        final once = WaqfSpacing.apply(s);
        expect(WaqfSpacing.apply(once), once, reason: s);
      }
    });

    test('leaves text without pause signs alone', () {
      const s = 'بِسْمِ اللّهِ';
      expect(WaqfSpacing.apply(s), s);
    });

    test('never touches the small seen, which is part of a word', () {
      const s = 'بِمُصَ$_smallSeenيْطِرٍ';
      expect(WaqfSpacing.apply(s), s);
      expect(WaqfSpacing.isPauseSign(0x06DC), isFalse);
    });
  });

  group('WaqfSpacing.isolateSigns', () {
    const style = TextStyle(fontSize: 29, color: Colors.white);

    test('puts each sign in its own span with a slightly different size', () {
      final spans = WaqfSpacing.isolateSigns(
        const TextSpan(text: 'ab   $_jeem   cd', style: style),
      );
      expect(spans.map((s) => s.text).toList(), ['ab   ', _jeem, '   cd']);
      expect(spans[0].style!.fontSize, 29);
      expect(spans[1].style!.fontSize, closeTo(29 * 1.001, 1e-9));
      expect(spans[1].style!.fontSize, isNot(29));
      expect(spans[2].style!.fontSize, 29);
      // Everything else about the style is preserved.
      expect(spans[1].style!.color, Colors.white);
    });

    test('returns spans without signs unchanged', () {
      const span = TextSpan(text: 'no signs here', style: style);
      expect(identical(WaqfSpacing.isolateSigns(span).single, span), isTrue);
    });
  });

  group('TajweedRenderer with the Indo-Pak font', () {
    const base = TextStyle(fontSize: 29, color: Colors.white);

    test('verse 2:1: the jeem is not swallowed by the ghunna span', () {
      final spans = TajweedRenderer.getTajweedSpans(_verse2_1, base);

      final withJeem = spans.where((s) => s.text!.contains(_jeem)).toList();
      expect(withJeem, hasLength(1));
      expect(withJeem.single.text, _jeem);
      // Plain colour, not the orange ghunna colour the meem gets.
      expect(withJeem.single.style!.color, Colors.white);
      expect(
        spans.any((s) => s.style!.color == TajweedRenderer.ghunnaColor),
        isTrue,
        reason: 'the meem+shadda should still be coloured',
      );
      // ...and it is shaped as its own run.
      expect(withJeem.single.style!.fontSize, isNot(29));
    });

    test('the text is the spaced text, nothing lost or added', () {
      final spans = TajweedRenderer.getTajweedSpans(_glued, base);
      expect(spans.map((s) => s.text).join(), WaqfSpacing.apply(_glued));
    });

    test('a sign inside a coloured rule span is still isolated', () {
      // noon sakin + sign + ikhfaa letter: the rule regex matches across the
      // sign, so the sign must be split back out of the coloured span.
      const text = 'مِنْ$_jeemكَ';
      final spans = TajweedRenderer.getTajweedSpans(text, base);
      final jeemSpan = spans.singleWhere((s) => s.text!.contains(_jeem));
      expect(jeemSpan.text, _jeem);
      expect(spans.map((s) => s.text).join(), WaqfSpacing.apply(text));
    });

    test('the Uthmani font path is left exactly as it was', () {
      final spans = TajweedRenderer.getTajweedSpans(
        'a $_jeem b',
        base,
        isIndopak: false,
      );
      expect(spans.map((s) => s.text).join(), 'a $_jeem b');
      expect(spans.every((s) => s.style!.fontSize == 29), isTrue);
    });
  });

  group('WaqfSpacing.text', () {
    const style = TextStyle(fontSize: 29);

    testWidgets('is a plain Text for the Uthmani font', (tester) async {
      final w = WaqfSpacing.text('a $_jeem b', indopak: false, style: style);
      expect(w.data, 'a $_jeem b');
      expect(w.textSpan, isNull);
    });

    testWidgets('spaces and isolates signs for the Indo-Pak font', (tester) async {
      final w = WaqfSpacing.text(_glued, indopak: true, style: style);
      final root = w.textSpan! as TextSpan;
      final children = root.children!.cast<TextSpan>();
      expect(children.map((s) => s.text).join(), WaqfSpacing.apply(_glued));
      expect(children.where((s) => s.text == _jeem), hasLength(1));
    });
  });
}
