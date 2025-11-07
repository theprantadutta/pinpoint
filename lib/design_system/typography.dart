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
  static String get writingFontFamily => 'Source Sans Pro';

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
    final mono = monoFont ?? monospaceFontFamily;

    final baseTextColor = brightness == Brightness.dark
        ? const Color(0xFFF9FAFB)
        : const Color(0xFF111827);

    return TextTheme(
      // Display styles - for hero headers and onboarding
      displayLarge: GoogleFonts.getFont(
        heading,
        fontSize: 57,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
        height: 1.2,
        color: baseTextColor,
      ),
      displayMedium: GoogleFonts.getFont(
        heading,
        fontSize: 45,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.2,
        color: baseTextColor,
      ),
      displaySmall: GoogleFonts.getFont(
        heading,
        fontSize: 36,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.3,
        color: baseTextColor,
      ),

      // Headline styles - for section headers
      headlineLarge: GoogleFonts.getFont(
        heading,
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.3,
        color: baseTextColor,
      ),
      headlineMedium: GoogleFonts.getFont(
        heading,
        fontSize: 28,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.3,
        color: baseTextColor,
      ),
      headlineSmall: GoogleFonts.getFont(
        primary,
        fontSize: 24,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.4,
        color: baseTextColor,
      ),

      // Title styles - for cards and list items
      titleLarge: GoogleFonts.getFont(
        primary,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.4,
        color: baseTextColor,
      ),
      titleMedium: GoogleFonts.getFont(
        primary,
        fontSize: 18,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.5,
        color: baseTextColor,
      ),
      titleSmall: GoogleFonts.getFont(
        primary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.5,
        color: baseTextColor,
      ),

      // Body styles - for content
      bodyLarge: GoogleFonts.getFont(
        primary,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        height: 1.6,
        color: baseTextColor,
      ),
      bodyMedium: GoogleFonts.getFont(
        primary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        height: 1.5,
        color: baseTextColor,
      ),
      bodySmall: GoogleFonts.getFont(
        primary,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.5,
        color: baseTextColor.withOpacity(0.8),
      ),

      // Label styles - for buttons and chips
      labelLarge: GoogleFonts.getFont(
        primary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        height: 1.4,
        color: baseTextColor,
      ),
      labelMedium: GoogleFonts.getFont(
        primary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.4,
        color: baseTextColor,
      ),
      labelSmall: GoogleFonts.getFont(
        primary,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.4,
        color: baseTextColor.withOpacity(0.8),
      ),
    );
  }

  // ============================================
  // Specialized Text Styles
  // ============================================

  /// Editor title style - large, prominent for note titles
  static TextStyle editorTitle({required Brightness brightness}) {
    final color = brightness == Brightness.dark
        ? const Color(0xFFF9FAFB)
        : const Color(0xFF111827);

    return GoogleFonts.getFont(
      headingFontFamily,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.3,
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

    return GoogleFonts.getFont(
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

    return GoogleFonts.jetBrainsMono(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.4,
      color: color,
    );
  }

  /// Note card title
  static TextStyle noteCardTitle({required Brightness brightness}) {
    final color = brightness == Brightness.dark
        ? const Color(0xFFF9FAFB)
        : const Color(0xFF111827);

    return GoogleFonts.getFont(
      primaryFontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.4,
      color: color,
    );
  }

  /// Note card excerpt
  static TextStyle noteCardExcerpt({required Brightness brightness}) {
    final color = brightness == Brightness.dark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);

    return GoogleFonts.getFont(
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

    return GoogleFonts.getFont(
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

    return GoogleFonts.getFont(
      primaryFontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
      height: 1.3,
      color: textColor,
    );
  }

  /// Button text styles
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
        fontSize = 12;
        fontWeight = FontWeight.w500;
        break;
      case ButtonSize.medium:
        fontSize = 14;
        fontWeight = FontWeight.w600;
        break;
      case ButtonSize.large:
        fontSize = 16;
        fontWeight = FontWeight.w600;
        break;
    }

    return GoogleFonts.getFont(
      primaryFontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: 0.5,
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
      return GoogleFonts.getFont(
        headingFontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.4,
        color: color,
      );
    }

    return GoogleFonts.getFont(
      primaryFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.5,
      color: color.withOpacity(0.8),
    );
  }

  /// Keyboard shortcut hint text
  static TextStyle keyboardHint({required Brightness brightness}) {
    final color = brightness == Brightness.dark
        ? const Color(0xFF6B7280)
        : const Color(0xFF9CA3AF);

    return GoogleFonts.jetBrainsMono(
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
