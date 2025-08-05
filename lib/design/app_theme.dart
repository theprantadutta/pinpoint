import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand palette
  static const Color primary = Color(0xFF7C3AED); // Electric Purple
  static const Color secondary = Color(0xFF10B981); // Emerald
  static const Color surface = Color(0xFFF6F7FB);
  static const Color surfaceDark = Color(0xFF0D1015);
  static const Color neutral = Color(0xFF0F172A);

  // Semantic tones
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // Radii & spacing
  static const BorderRadius radiusXL = BorderRadius.all(Radius.circular(28));
  static const BorderRadius radiusL = BorderRadius.all(Radius.circular(20));
  static const BorderRadius radiusM = BorderRadius.all(Radius.circular(14));
  static const BorderRadius radiusS = BorderRadius.all(Radius.circular(10));

  // Shadows
  static List<BoxShadow> shadowSoft(bool dark) => [
        BoxShadow(
          color: (dark ? Colors.black : Colors.black87).withOpacity(0.08),
          blurRadius: 28,
          spreadRadius: 2,
          offset: const Offset(0, 12),
        ),
      ];

  // Typography scale
  static TextTheme _textTheme(Brightness b) {
    final base = GoogleFonts.interTextTheme(
        // ensure dynamic type friendliness
        );
    final on = b == Brightness.dark ? Colors.white : neutral;
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: on,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: on,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: on.withOpacity(0.92),
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        height: 1.28,
        color: on.withOpacity(0.9),
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        height: 1.28,
        color: on.withOpacity(0.86),
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: on,
      ),
    );
  }

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: secondary,
      surface: surface,
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      textTheme: _textTheme(Brightness.light),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: neutral,
        titleTextStyle: _textTheme(Brightness.light).titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white.withOpacity(0.78),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: radiusL),
        margin: const EdgeInsets.all(0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.78),
        hintStyle: _textTheme(Brightness.light).bodyMedium?.copyWith(
              color: Colors.black.withOpacity(0.45),
            ),
        border: OutlineInputBorder(
          borderRadius: radiusM,
          borderSide: BorderSide(color: Colors.black.withOpacity(0.07)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radiusM,
          borderSide: BorderSide(color: Colors.black.withOpacity(0.07)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: radiusM,
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      // Legendary bottom nav (light)
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: primary,
        unselectedItemColor: Colors.black.withOpacity(0.45),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedIconTheme: const IconThemeData(size: 24),
        unselectedIconTheme: const IconThemeData(size: 22),
        selectedLabelStyle: _textTheme(Brightness.light).labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
        showUnselectedLabels: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        indicatorColor: primary.withOpacity(0.16),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          final on = states.contains(MaterialState.selected)
              ? primary
              : Colors.black.withOpacity(0.60);
          return _textTheme(Brightness.light).labelLarge!.copyWith(
                color: on,
                fontWeight: states.contains(MaterialState.selected)
                    ? FontWeight.w800
                    : FontWeight.w700,
              );
        }),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          final c = states.contains(MaterialState.selected)
              ? primary
              : Colors.black.withOpacity(0.60);
          return IconThemeData(
              color: c,
              size: states.contains(MaterialState.selected) ? 26 : 22);
        }),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radiusL,
          side: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
        extendedTextStyle: _textTheme(Brightness.light).labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withOpacity(0.74),
        selectedColor: primary.withOpacity(0.12),
        labelStyle: _textTheme(Brightness.light).labelLarge!,
        shape: const StadiumBorder(),
        side: BorderSide(color: Colors.black.withOpacity(0.06)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        showCheckmark: false,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: primary,
      secondary: secondary,
      surface: surfaceDark,
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: surfaceDark,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      textTheme: _textTheme(Brightness.dark),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleTextStyle: _textTheme(Brightness.dark).titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF12151C).withOpacity(0.78),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(borderRadius: radiusL),
        margin: const EdgeInsets.all(0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF12151C).withOpacity(0.78),
        hintStyle: _textTheme(Brightness.dark).bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.55),
            ),
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
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      // Legendary bottom nav (dark)
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: primary,
        unselectedItemColor: Colors.white.withOpacity(0.55),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedIconTheme: const IconThemeData(size: 24),
        unselectedIconTheme: const IconThemeData(size: 22),
        selectedLabelStyle: _textTheme(Brightness.dark).labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
        showUnselectedLabels: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        indicatorColor: primary.withOpacity(0.22),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          final on = states.contains(MaterialState.selected)
              ? primary
              : Colors.white.withOpacity(0.72);
          return _textTheme(Brightness.dark).labelLarge!.copyWith(
                color: on,
                fontWeight: states.contains(MaterialState.selected)
                    ? FontWeight.w800
                    : FontWeight.w700,
              );
        }),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          final c = states.contains(MaterialState.selected)
              ? primary
              : Colors.white.withOpacity(0.72);
          return IconThemeData(
              color: c,
              size: states.contains(MaterialState.selected) ? 26 : 22);
        }),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radiusL,
          side: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        extendedTextStyle: _textTheme(Brightness.dark).labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF12151C).withOpacity(0.74),
        selectedColor: primary.withOpacity(0.16),
        labelStyle: _textTheme(Brightness.dark).labelLarge!,
        shape: const StadiumBorder(),
        side: BorderSide(color: Colors.white.withOpacity(0.06)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        showCheckmark: false,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      }),
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
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = AppTheme.radiusL,
    this.blur = 18,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: padding,
          decoration: BoxDecoration(
            color: (dark ? const Color(0xFF12151C) : Colors.white)
                .withOpacity(0.74),
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
