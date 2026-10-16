import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_flutter_app/services/tajweed_service.dart';

void main() {
  test('Inspect Tajweed spans for Surah 2 Ayahs from Quran.db', () {
    final file = File('assets/db/Quran.db');
    final bytes = file.readAsBytesSync();
    final text = utf8.decode(bytes, allowMalformed: true);

    final matches = RegExp(r'([\u0621-\u064A\u0671-\u06DC\u06E0-\u06ED\s]{5,25}\u06DA[\u0621-\u064A\u0671-\u06DC\u06E0-\u06ED\s]{5,25})').allMatches(text);
    int count = 0;
    for (final m in matches) {
      if (count++ >= 8) break;
      final rawText = m.group(0)!;
      final cleanText = TajweedRenderer.cleanArabicText(rawText);
      stdout.writeln('=== Sample $count ===');
      stdout.writeln('Raw: "$rawText"');
      stdout.writeln('Cleaned: "$cleanText"');
      final spans = TajweedRenderer.getTajweedSpans(
        cleanText,
        const TextStyle(color: Colors.white, fontSize: 24),
      );
      for (int i = 0; i < spans.length; i++) {
        stdout.writeln('   Span $i: "${spans[i].text}" | Color: ${spans[i].style?.color}');
      }
      stdout.writeln('');
    }
  });
}
