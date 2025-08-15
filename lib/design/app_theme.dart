import 'dart:ui';

import 'package:flex_color_scheme/flex_color_scheme.dart';
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
          color: (dark ? Colors.black : Colors.black87).withAlpha(20),
          blurRadius: 28,
          spreadRadius: 2,
          offset: const Offset(0, 12),
        ),
      ];

  // Typography scale
  static TextTheme getTextThemeForFont(String fontName, TextTheme base) {
    switch (fontName) {
      case 'Roboto':
        return GoogleFonts.robotoTextTheme(base);
      case 'Open Sans':
        return GoogleFonts.openSansTextTheme(base);
      case 'Lato':
        return GoogleFonts.latoTextTheme(base);
      case 'Montserrat':
        return GoogleFonts.montserratTextTheme(base);
      case 'Poppins':
        return GoogleFonts.poppinsTextTheme(base);
      case 'Source Sans Pro':
        return GoogleFonts.sourceSans3TextTheme(base);
      case 'Noto Sans':
        return GoogleFonts.notoSansTextTheme(base);
      case 'Inter':
      default:
        return GoogleFonts.interTextTheme(base);
    }
  }

  static ThemeData light([FlexScheme? scheme, String? fontName]) {
    final colorScheme = scheme != null
        ? FlexColorScheme.light(scheme: scheme).toScheme
        : ColorScheme.fromSeed(
            seedColor: primary,
            brightness: Brightness.light,
            primary: primary,
            secondary: secondary,
            surface: surface,
          );
    final base = ThemeData.light(useMaterial3: true);
    
    // Apply custom font if specified
    final textTheme = fontName != null 
        ? getTextThemeForFont(fontName, base.textTheme)
        : base.textTheme;
        
    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: neutral,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white.withAlpha(199),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: radiusL),
        margin: const EdgeInsets.all(0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withAlpha(199),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.black.withAlpha(114),
        ),
        border: OutlineInputBorder(
          borderRadius: radiusM,
          borderSide: BorderSide(color: Colors.black.withAlpha(17)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radiusM,
          borderSide: BorderSide(color: Colors.black.withAlpha(17)),
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
        unselectedItemColor: Colors.black.withAlpha(114),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedIconTheme: const IconThemeData(size: 24),
        unselectedIconTheme: const IconThemeData(size: 22),
        selectedLabelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        showUnselectedLabels: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        indicatorColor: primary.withAlpha(40),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final on = states.contains(WidgetState.selected)
              ? primary
              : Colors.black.withAlpha(153);
          return textTheme.labelLarge!.copyWith(
            color: on,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w700,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final c = states.contains(WidgetState.selected)
              ? primary
              : Colors.black.withAlpha(153);
          return IconThemeData(
              color: c, size: states.contains(WidgetState.selected) ? 26 : 22);
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
          side: BorderSide(color: Colors.black.withAlpha(15)),
        ),
        extendedTextStyle: textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withAlpha(188),
        selectedColor: primary.withAlpha(30),
        labelStyle: textTheme.labelLarge!,
        shape: const StadiumBorder(),
        side: BorderSide(color: Colors.black.withAlpha(15)),
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

  static ThemeData dark([FlexScheme? scheme, String? fontName]) {
    final colorScheme = scheme != null
        ? FlexColorScheme.dark(scheme: scheme).toScheme
        : ColorScheme.fromSeed(
            seedColor: primary,
            brightness: Brightness.dark,
            primary: primary,
            secondary: secondary,
            surface: surfaceDark,
          );
    final base = ThemeData.dark(useMaterial3: true);
    
    // Apply custom font if specified
    final textTheme = fontName != null 
        ? getTextThemeForFont(fontName, base.textTheme)
        : base.textTheme;
        
    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surfaceDark,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF12151C).withAlpha(199),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(borderRadius: radiusL),
        margin: const EdgeInsets.all(0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF12151C).withAlpha(199),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white.withAlpha(140),
        ),
        border: OutlineInputBorder(
          borderRadius: radiusM,
          borderSide: BorderSide(color: Colors.white.withAlpha(20)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radiusM,
          borderSide: BorderSide(color: Colors.white.withAlpha(20)),
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
        unselectedItemColor: Colors.white.withAlpha(140),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedIconTheme: const IconThemeData(size: 24),
        unselectedIconTheme: const IconThemeData(size: 22),
        selectedLabelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        showUnselectedLabels: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        indicatorColor: primary.withAlpha(56),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final on = states.contains(WidgetState.selected)
              ? primary
              : Colors.white.withAlpha(183);
          return textTheme.labelLarge!.copyWith(
            color: on,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w700,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final c = states.contains(WidgetState.selected)
              ? primary
              : Colors.white.withAlpha(183);
          return IconThemeData(
              color: c, size: states.contains(WidgetState.selected) ? 26 : 22);
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
          side: BorderSide(color: Colors.white.withAlpha(15)),
        ),
        extendedTextStyle: textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF12151C).withAlpha(188),
        selectedColor: primary.withAlpha(40),
        labelStyle: textTheme.labelLarge!,
        shape: const StadiumBorder(),
        side: BorderSide(color: Colors.white.withAlpha(15)),
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
            color:
                (dark ? const Color(0xFF12151C) : Colors.white).withAlpha(188),
            borderRadius: borderRadius,
            boxShadow: AppTheme.shadowSoft(dark),
            border: Border.all(
              color: (dark ? Colors.white : Colors.black).withAlpha(15),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}