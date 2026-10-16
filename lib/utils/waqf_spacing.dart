import 'package:flutter/widgets.dart';

/// Spacing for Indo-Pak pause signs (waqf marks) in the `qalammajeed3` font.
///
/// Two things go wrong with these signs if the text is rendered as-is:
///
/// 1. The Indo-Pak data glues the sign onto the word ("...هِۚوَمَنْ") and the
///    font draws it as a zero-advance floating mark that overhangs its
///    neighbours by up to ~0.2 em, so the next word runs into the previous one.
///    [apply] reserves real space on both sides with plain spaces (0.1 em in
///    this font; thin spaces such as U+2009 are not in the font).
///
/// 2. Spaces alone are not enough. The font's positioning rules for these marks
///    are contextual lookups that *ignore base glyphs* (spaces included) and
///    tuck the sign against the previous marks, e.g. right up against a long
///    madd stroke. Shaping the sign as its own text run switches that off, so
///    the spaces take effect. A tiny font-size difference is enough to split
///    the run; see [isolateSigns].
///
/// Only needed for the Indo-Pak font: the Uthmani (`hafs`) text already has
/// spaces around its signs and the font gives them real advance widths.
class WaqfSpacing {
  WaqfSpacing._();

  /// Pause signs U+06D6..U+06DB. U+06DC (small seen) is excluded on purpose:
  /// it modifies a letter inside a word (e.g. بِمُصَۜيْطِرٍ) and must stay attached.
  static bool isPauseSign(int codeUnit) =>
      codeUnit >= 0x06D6 && codeUnit <= 0x06DB;

  // Spaces to put before / after each sign. In RTL text "before" is the side
  // facing the previous word (the right), where the mark's x-max overhangs.
  // Derived from the glyph bounds in qalammajeed3.ttf (2048 upem, space = 202):
  //   spaces = ceil((overhang + 0.15 em clearance) / 202)
  //   sign    x-min  x-max
  //   U+06D6  -372    414
  //   U+06D7  -371    415
  //   U+06D8  -279    195
  //   U+06D9  -248    120
  //   U+06DA  -182    231   (jeem)
  //   U+06DB  -164    220
  static const Map<int, (int, int)> _gaps = {
    0x06D6: (4, 4),
    0x06D7: (4, 4),
    0x06D8: (3, 3),
    0x06D9: (3, 3),
    0x06DA: (3, 3),
    0x06DB: (3, 3),
  };

  static const String _space = r'[ \t  - ]*';
  static final RegExp _signRun = RegExp('$_space([ۖ-ۛ]+)$_space');
  static final RegExp _anySignRun = RegExp('[ۖ-ۛ]+');

  /// Large enough to force a separate shaping run, far too small to see.
  static const double _runSplitScale = 1.001;

  /// Returns [text] with exactly the right amount of space around each pause
  /// sign. Idempotent, so it is safe to apply more than once.
  static String apply(String text) {
    return text.replaceAllMapped(_signRun, (m) {
      final run = m.group(1)!;
      final before = _gaps[run.codeUnitAt(0)]!.$1;
      final after = _gaps[run.codeUnitAt(run.length - 1)]!.$2;
      return '${' ' * before}$run${' ' * after}';
    });
  }

  /// Splits [span] so every pause sign is its own span, styled with a font
  /// size that differs by 0.1 % so it is shaped as a separate run and no
  /// longer snaps onto the preceding letter's marks. Colour and the rest of
  /// the style are kept.
  static List<TextSpan> isolateSigns(TextSpan span) {
    final text = span.text;
    if (text == null || !_anySignRun.hasMatch(text)) return [span];

    final style = span.style ?? const TextStyle();
    final signStyle = style.copyWith(
      fontSize: (style.fontSize ?? 14) * _runSplitScale,
    );
    final pieces = <TextSpan>[];
    var last = 0;
    for (final m in _anySignRun.allMatches(text)) {
      if (m.start > last) {
        pieces.add(TextSpan(text: text.substring(last, m.start), style: style));
      }
      pieces.add(TextSpan(text: m.group(0), style: signStyle));
      last = m.end;
    }
    if (last < text.length) {
      pieces.add(TextSpan(text: text.substring(last), style: style));
    }
    return pieces;
  }

  /// [text] spaced and split into spans, ready for `Text.rich` / `RichText`.
  static List<TextSpan> spans(String text, TextStyle style) =>
      isolateSigns(TextSpan(text: apply(text), style: style));

  /// Drop-in for `Text(...)` for verse text. When [indopak] is true the pause
  /// signs are spaced and isolated; otherwise this is a plain [Text].
  static Text text(
    String text, {
    required bool indopak,
    required TextStyle style,
    TextAlign? textAlign,
    TextDirection? textDirection,
  }) {
    if (!indopak) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        textDirection: textDirection,
      );
    }
    return Text.rich(
      TextSpan(children: spans(text, style)),
      textAlign: textAlign,
      textDirection: textDirection,
    );
  }
}
