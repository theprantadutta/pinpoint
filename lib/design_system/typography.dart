import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pinpoint Design System - Typography
/// Writing-focused type system optimized for note-taking
class PinpointTypography {
  // Private constructor to prevent instantiation
  PinpointTypography._();

  // ============================================
  // Font Families
  // ============================================

  /// Primary font for UI and reading
  static String get primaryFontFamily => 'Inter';

  /// Secondary font for headings and emphasis
  static String get headingFontFamily => 'Montserrat';

  /// Monospace font for code blocks
  static String get monospaceFontFamily => 'JetBrains Mono';

  /// Writing font for editor (optimized for long-form writing)
  static String get writingFontFamily => 'Source Sans 3';

  // ============================================
  // Script fallbacks
  // ============================================

  /// Faces consulted, per glyph, when the chosen UI font has nothing to draw.
  ///
  /// Every bundled google_fonts family is a **Latin subset** — Inter-Regular is
  /// 66 KB where the full face is ~300 KB — and `allowRuntimeFetching` is off
  /// (see main.dart), so nothing is downloaded to cover the gap at runtime.
  /// Without this chain, Thai, Bengali, Arabic and Persian render as tofu or
  /// silently fall through to whatever the OS provides, which throws away the
  /// user's font choice on exactly the locales that need it most.
  ///
  /// Ordering is irrelevant to correctness — the scripts do not overlap, so at
  /// most one family can supply any given glyph. Declared statically in
  /// pubspec.yaml so these names resolve in the font registry.
  static const List<String> scriptFallbacks = <String>[
    'Noto Sans Thai',
    'Noto Sans Bengali',
    // Covers Persian as well as Arabic.
    'Noto Sans Arabic',
  ];

  /// [GoogleFonts.getFont] with the script fallback chain attached.
  ///
  /// Every style in this file goes through here (or [_mono]) rather than
  /// calling google_fonts directly, so a new text style cannot accidentally
  /// ship without non-Latin coverage.
  static TextStyle _font(
    String family, {
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    Color? color,
  }) {
    return GoogleFonts.getFont(
      family,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
    ).copyWith(fontFamilyFallback: scriptFallbacks);
  }

  /// Monospace equivalent of [_font]. JetBrains Mono is Latin-only too, and
  /// code blocks can legitimately contain non-Latin text in comments.
  static TextStyle _mono({
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    Color? color,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
    ).copyWith(fontFamilyFallback: scriptFallbacks);
  }

  // ============================================
  // Text Themes
  // ============================================

  /// Create a complete text theme for the app
  static TextTheme createTextTheme({
    required Brightness brightness,
    String? primaryFont,
    String? headingFont,
    String? monoFont,
  }) {
    final primary = primaryFont ?? primaryFontFamily;
    final heading = headingFont ?? headingFontFamily;
    // final mono = monoFont ?? monospaceFontFamily;

    final baseTextColor = brightness == Brightness.dark
        ? const Color(0xFFF9FAFB)
        : const Color(0xFF111827);

    return TextTheme(
      // Display styles - for hero headers and onboarding (BOLD)
      displayLarge: _font(
        heading,
        fontSize: 60, // Slightly larger
        fontWeight: FontWeight.w900, // BOLD: Increased from w700
        letterSpacing: -2.0, // Tighter for modern feel
        height: 1.1, // Tighter line height
        color: baseTextColor,
      ),
      displayMedium: _font(
        heading,
        fontSize: 48, // Slightly larger
        fontWeight: FontWeight.w800, // BOLD: Increased from w600
        letterSpacing: -1.0, // Tighter
        height: 1.15,
        color: baseTextColor,
      ),
      displaySmall: _font(
        heading,
        fontSize: 38, // Slightly larger
        fontWeight: FontWeight.w800, // BOLD: Increased from w600
        letterSpacing: -0.5, // Tighter
        height: 1.2,
        color: baseTextColor,
      ),

      // Headline styles - for section headers (BOLD)
      headlineLarge: _font(
        heading,
        fontSize: 34, // Slightly larger
        fontWeight: FontWeight.w800, // BOLD: Increased from w600
        letterSpacing: -0.5, // Tighter
        height: 1.25,
        color: baseTextColor,
      ),
      headlineMedium: _font(
        heading,
        fontSize: 30, // Slightly larger
        fontWeight: FontWeight.w700, // BOLD: Increased from w500
        letterSpacing: -0.3,
        height: 1.3,
        color: baseTextColor,
      ),
      headlineSmall: _font(
        primary,
        fontSize: 26, // Slightly larger
        fontWeight: FontWeight.w700, // BOLD: Increased from w500
        letterSpacing: -0.2,
        height: 1.35,
        color: baseTextColor,
      ),

      // Title styles - for cards and list items (BOLD)
      titleLarge: _font(
        primary,
        fontSize: 22,
        fontWeight: FontWeight.w700, // BOLD: Increased from w600
        letterSpacing: -0.1, // Tighter
        height: 1.4,
        color: baseTextColor,
      ),
      titleMedium: _font(
        primary,
        fontSize: 18,
        fontWeight: FontWeight.w600, // BOLD: Increased from w500
        letterSpacing: 0,
        height: 1.45,
        color: baseTextColor,
      ),
      titleSmall: _font(
        primary,
        fontSize: 14,
        fontWeight: FontWeight.w600, // BOLD: Increased from w500
        letterSpacing: 0,
        height: 1.5,
        color: baseTextColor,
      ),

      // Body styles - for content
      bodyLarge: _font(
        primary,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        height: 1.6,
        color: baseTextColor,
      ),
      bodyMedium: _font(
        primary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        height: 1.5,
        color: baseTextColor,
      ),
      bodySmall: _font(
        primary,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.5,
        color: baseTextColor.withValues(alpha: 0.8),
      ),

      // Label styles - for buttons and chips (BOLD)
      labelLarge: _font(
        primary,
        fontSize: 14,
        fontWeight: FontWeight.w700, // BOLD: Increased from w600
        letterSpacing: 0.3, // Slightly tighter
        height: 1.4,
        color: baseTextColor,
      ),
      labelMedium: _font(
        primary,
        fontSize: 12,
        fontWeight: FontWeight.w600, // BOLD: Increased from w500
        letterSpacing: 0.4,
        height: 1.4,
        color: baseTextColor,
      ),
      labelSmall: _font(
        primary,
        fontSize: 11,
        fontWeight: FontWeight.w600, // BOLD: Increased from w500
        letterSpacing: 0.4,
        height: 1.4,
        color: baseTextColor.withValues(alpha: 0.8),
      ),
    );
  }

  // ============================================
  // Specialized Text Styles
  // ============================================

  /// Editor title style - large, prominent for note titles (BOLD)
  static TextStyle editorTitle({required Brightness brightness}) {
    final color = brightness == Brightness.dark
        ? const Color(0xFFF9FAFB)
        : const Color(0xFF111827);

    return _font(
      headingFontFamily,
      fontSize: 32, // Larger
      fontWeight: FontWeight.w800, // BOLD: Increased from w700
      letterSpacing: -0.8, // Tighter
      height: 1.25,
      color: color,
    );
  }

  /// Editor body style - optimized for writing
  static TextStyle editorBody({
    required Brightness brightness,
    bool focusMode = false,
  }) {
    final color = brightness == Brightness.dark
        ? const Color(0xFFF9FAFB)
        : const Color(0xFF111827);

    return _font(
      writingFontFamily,
      fontSize: focusMode ? 18 : 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: focusMode ? 1.8 : 1.6,
      color: color,
    );
  }

  /// Code block style - monospace for code
  static TextStyle codeBlock({required Brightness brightness}) {
    final color = brightness == Brightness.dark
        ? const Color(0xFF10B981) // Mint for dark mode
        : const Color(0xFF059669); // Darker mint for light mode

    return _mono(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.4,
      color: color,
    );
  }

  /// Note card title (BOLD)
  static TextStyle noteCardTitle({required Brightness brightness}) {
    final color = brightness == Brightness.dark
        ? const Color(0xFFF9FAFB)
        : const Color(0xFF111827);

    return _font(
      primaryFontFamily,
      fontSize: 17, // Slightly larger
      fontWeight: FontWeight.w700, // BOLD: Increased from w600
      letterSpacing: -0.1, // Tighter
      height: 1.4,
      color: color,
    );
  }

  /// Note card excerpt
  static TextStyle noteCardExcerpt({required Brightness brightness}) {
    final color = brightness == Brightness.dark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);

    return _font(
      primaryFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.5,
      color: color,
    );
  }

  /// Metadata text (timestamps, counts, etc.)
  static TextStyle metadata({required Brightness brightness}) {
    final color = brightness == Brightness.dark
        ? const Color(0xFF6B7280)
        : const Color(0xFF9CA3AF);

    return _font(
      primaryFontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.3,
      height: 1.4,
      color: color,
    );
  }

  /// Tag chip text
  static TextStyle tagChip({
    required Brightness brightness,
    Color? color,
  }) {
    final textColor = color ??
        (brightness == Brightness.dark
            ? const Color(0xFFF9FAFB)
            : const Color(0xFF111827));

    return _font(
      primaryFontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
      height: 1.3,
      color: textColor,
    );
  }

  /// Button text styles (BOLD)
  static TextStyle button({
    required Brightness brightness,
    ButtonSize size = ButtonSize.medium,
    Color? color,
  }) {
    final textColor = color ??
        (brightness == Brightness.dark
            ? const Color(0xFFF9FAFB)
            : const Color(0xFF111827));

    double fontSize;
    FontWeight fontWeight;

    switch (size) {
      case ButtonSize.small:
        fontSize = 13; // Slightly larger
        fontWeight = FontWeight.w600; // BOLD: Increased from w500
        break;
      case ButtonSize.medium:
        fontSize = 15; // Slightly larger
        fontWeight = FontWeight.w700; // BOLD: Increased from w600
        break;
      case ButtonSize.large:
        fontSize = 17; // Slightly larger
        fontWeight = FontWeight.w700; // BOLD: Same weight
        break;
    }

    return _font(
      primaryFontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: 0.3, // Tighter
      height: 1.4,
      color: textColor,
    );
  }

  /// Empty state text
  static TextStyle emptyState({
    required Brightness brightness,
    bool isTitle = false,
  }) {
    final color = brightness == Brightness.dark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);

    if (isTitle) {
      return _font(
        headingFontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.4,
        color: color,
      );
    }

    return _font(
      primaryFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.5,
      color: color.withValues(alpha: 0.8),
    );
  }

  /// Keyboard shortcut hint text
  static TextStyle keyboardHint({required Brightness brightness}) {
    final color = brightness == Brightness.dark
        ? const Color(0xFF6B7280)
        : const Color(0xFF9CA3AF);

    return _mono(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.3,
      color: color,
    );
  }
}

/// Button size variants
enum ButtonSize {
  small,
  medium,
  large,
}

/// Text style utilities
class TextStyleUtils {
  /// Apply gradient to text
  static ShaderMask gradientText({
    required Widget child,
    required Gradient gradient,
  }) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: child,
    );
  }

  /// Get responsive font size
  static double responsiveFontSize(
    BuildContext context,
    double baseSize, {
    double? minSize,
    double? maxSize,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth / 375; // Base on iPhone 11 width

    final scaledSize = baseSize * scaleFactor;

    if (minSize != null && scaledSize < minSize) return minSize;
    if (maxSize != null && scaledSize > maxSize) return maxSize;

    return scaledSize;
  }
}
