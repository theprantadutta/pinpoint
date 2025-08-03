// Flex color scheme removed in redesign
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

final kDefaultFontFamily = GoogleFonts.inter().fontFamily ?? 'Inter';

SystemUiOverlayStyle getDefaultSystemUiStyle(bool isDarkTheme) {
  return SystemUiOverlayStyle(
    // Status bar color
    statusBarColor: Colors.transparent,
    // Status bar brightness (optional)
    statusBarIconBrightness: isDarkTheme
        ? Brightness.light
        : Brightness.dark, // For Android (dark icons)
    statusBarBrightness: isDarkTheme
        ? Brightness.dark
        : Brightness.light, // For iOS (dark icons)
  );
}

BoxDecoration getBackgroundDecoration(Color kPrimaryColor) {
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        kPrimaryColor.withValues(alpha: 0.12), // Soft start
        kPrimaryColor.withValues(alpha: 0.06), // Lighter end
      ],
      stops: const [0.0, 1.0],
    ),
  );
}
