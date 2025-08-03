import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand colors
  static const Color primary = Color(0xFF7C3AED); // Electric Purple
  static const Color secondary = Color(0xFF10B981); // Emerald
  static const Color surface = Color(0xFFF7F7FB);
  static const Color surfaceDark = Color(0xFF0F1115);
  static const Color neutral = Color(0xFF111827);

  // Radii & elevations
  static const BorderRadius radiusL = BorderRadius.all(Radius.circular(20));
  static const BorderRadius radiusM = BorderRadius.all(Radius.circular(14));
  static const BorderRadius radiusS = BorderRadius.all(Radius.circular(10));

  // Shadows
  static List<BoxShadow> shadowSoft(bool dark) => [
        BoxShadow(
          color: (dark ? Colors.black : Colors.black87).withOpacity(0.06),
          blurRadius: 24,
          spreadRadius: 2,
          offset: const Offset(0, 10),
        ),
      ];

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: secondary,
      surface: surface,
    );
    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      textTheme: _textTheme(Brightness.light),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: surface,
        foregroundColor: neutral,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: Colors.white.withOpacity(0.72),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: radiusL),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.72),
        border: OutlineInputBorder(
          borderRadius: radiusM,
          borderSide: BorderSide(color: Colors.black.withOpacity(0.07)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radiusM,
          borderSide: BorderSide(color: Colors.black.withOpacity(0.07)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radiusM,
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withOpacity(0.68),
        selectedColor: primary.withOpacity(0.12),
        labelStyle: _textTheme(Brightness.light).labelLarge!,
        shape: const StadiumBorder(),
        side: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: primary,
      secondary: secondary,
      surface: surfaceDark,
    );
    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surfaceDark,
      textTheme: _textTheme(Brightness.dark),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: surfaceDark,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: const Color(0xFF12151C).withOpacity(0.72),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(borderRadius: radiusL),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF12151C).withOpacity(0.72),
        border: OutlineInputBorder(
          borderRadius: radiusM,
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radiusM,
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: radiusM,
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF12151C).withOpacity(0.68),
        selectedColor: primary.withOpacity(0.16),
        labelStyle: _textTheme(Brightness.dark).labelLarge!,
        shape: const StadiumBorder(),
        side: BorderSide(color: Colors.white.withOpacity(0.06)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }

  static TextTheme _textTheme(Brightness b) {
    final base = GoogleFonts.interTextTheme();
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.24),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.24),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final double blur;

  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = AppTheme.radiusL,
    this.blur = 16,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (dark ? const Color(0xFF12151C) : Colors.white)
                .withOpacity(0.68),
            borderRadius: borderRadius,
            boxShadow: AppTheme.shadowSoft(dark),
            border: Border.all(
              color: (dark ? Colors.white : Colors.black).withOpacity(0.06),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
