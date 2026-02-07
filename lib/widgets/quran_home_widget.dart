import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A fully adaptive home screen widget that:
/// 1. Fills all available space (width + height)
/// 2. Adapts to any size using LayoutBuilder
/// 3. Never overflows using FittedBox for text
/// 4. Supports light and dark themes
class QuranHomeWidget extends StatelessWidget {
  final String surahName;
  final String verseRef;
  final String arabicText;
  final String translation;
  final bool isDarkMode;

  const QuranHomeWidget({
    Key? key,
    required this.surahName,
    required this.verseRef,
    required this.arabicText,
    required this.translation,
    this.isDarkMode = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode
        ? const Color(0xFF1A1A2E)
        : const Color(0xFFF8F9FA);
    final primaryText = isDarkMode ? Colors.white : Colors.black87;
    final secondaryText = isDarkMode ? Colors.white70 : Colors.black54;
    final accentColor = isDarkMode
        ? const Color(0xFF6C63FF)
        : const Color(0xFF4A4AE8);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        final headerSize = (height * 0.12).clamp(8.0, 14.0);
        final arabicSize = (height * 0.30).clamp(14.0, 28.0);
        final translationSize = (height * 0.14).clamp(8.0, 12.0);
        final padding = (width * 0.03).clamp(8.0, 16.0);

        return Container(
          width: 1000,
          height: 200,
          padding: EdgeInsets.all(18.5),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(37),
            border: Border.all(color: accentColor.withOpacity(0.3), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              /// HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      surahName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: accentColor,
                        fontSize: headerSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: padding * 0.6,
                      vertical: padding * 0.2,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      verseRef,
                      style: GoogleFonts.poppins(
                        color: accentColor,
                        fontSize: headerSize * 0.85,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 9,),

              /// ARABIC TEXT
              // Expanded(
              //   flex: 2,
              //   child: Center(
              //     child: Directionality(
              //       textDirection: TextDirection.rtl,
              //       child: FittedBox(
              //         fit: BoxFit.scaleDown,
              //         child: Text(
              //           arabicText,
              //           textAlign: TextAlign.center,
              //           style: TextStyle(
              //             color: primaryText,
              //             fontSize: arabicSize,
              //             fontWeight: FontWeight.bold,
              //             fontFamily: 'qalammajeed3',
              //             height: 1.4,
              //           ),
              //         ),
              //       ),
              //     ),
              //   ),
              // ),

              /// TRANSLATION
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(9.0),
                  child: Center(
                    child: Text(
                      translation,
                      maxLines: 7,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                      style: GoogleFonts.poppins(
                        color: secondaryText,
                        fontSize: translationSize,
                        height: 1.2,
                      ),
                    ),
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
