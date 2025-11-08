import 'package:flutter/material.dart';

/// Pinpoint Design System - Colors
/// Dark-first color palette with cinematic gradients and Material 3 compatibility
class PinpointColors {
  // Private constructor to prevent instantiation
  PinpointColors._();

  // ============================================
  // Core Brand Colors
  // ============================================

  /// Deep ink surfaces for dark mode
  static const Color darkSurface1 = Color(0xFF0B0F1A);
  static const Color darkSurface2 = Color(0xFF111827);
  static const Color darkSurface3 = Color(0xFF1A202C);
  static const Color darkSurface4 = Color(0xFF2D3748);

  /// Paper white surfaces for light mode
  static const Color lightSurface1 = Color(0xFFFAFAFA);
  static const Color lightSurface2 = Color(0xFFF7F7F8);
  static const Color lightSurface3 = Color(0xFFF0F0F2);
  static const Color lightSurface4 = Color(0xFFE8E8EA);

  // ============================================
  // Accent Colors
  // ============================================

  /// Mint - Primary accent
  static const Color mint = Color(0xFF10B981);
  static const Color mintLight = Color(0xFF34D399);
  static const Color mintDark = Color(0xFF059669);
  static const Color mintSubtle = Color(0x2010B981);

  /// Iris - Secondary accent
  static const Color iris = Color(0xFF6366F1);
  static const Color irisLight = Color(0xFF818CF8);
  static const Color irisDark = Color(0xFF4F46E5);
  static const Color irisSubtle = Color(0x206366F1);

  /// Rose - Destructive/Love accent
  static const Color rose = Color(0xFFF43F5E);
  static const Color roseLight = Color(0xFFFB7185);
  static const Color roseDark = Color(0xFFE11D48);
  static const Color roseSubtle = Color(0x20F43F5E);

  /// Amber - Warning/Favorite accent
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberLight = Color(0xFFFBBF24);
  static const Color amberDark = Color(0xFFD97706);
  static const Color amberSubtle = Color(0x20F59E0B);

  /// Ocean - Info accent
  static const Color ocean = Color(0xFF0EA5E9);
  static const Color oceanLight = Color(0xFF38BDF8);
  static const Color oceanDark = Color(0xFF0284C7);
  static const Color oceanSubtle = Color(0x200EA5E9);

  // ============================================
  // Aliases for backward compatibility
  // ============================================

  static const Color purple = iris;
  static const Color pink = rose;
  static const Color orange = amber;
  static const Color blue = ocean;

  // ============================================
  // Semantic Colors
  // ============================================

  static const Color success = mint;
  static const Color successLight = mintLight;
  static const Color successDark = mintDark;
  static const Color successBackground = Color(0x1010B981);

  static const Color error = rose;
  static const Color errorLight = roseLight;
  static const Color errorDark = roseDark;
  static const Color errorBackground = Color(0x10F43F5E);

  static const Color warning = amber;
  static const Color warningLight = amberLight;
  static const Color warningDark = amberDark;
  static const Color warningBackground = Color(0x10F59E0B);

  static const Color info = ocean;
  static const Color infoLight = oceanLight;
  static const Color infoDark = oceanDark;
  static const Color infoBackground = Color(0x100EA5E9);

  // ============================================
  // Text Colors
  // ============================================

  /// Dark mode text
  static const Color darkTextPrimary = Color(0xFFF9FAFB);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkTextTertiary = Color(0xFF6B7280);
  static const Color darkTextDisabled = Color(0xFF4B5563);

  /// Light mode text
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightTextTertiary = Color(0xFF9CA3AF);
  static const Color lightTextDisabled = Color(0xFFD1D5DB);

  // ============================================
  // Glass Morphism Overlays
  // ============================================

  static const Color glassWhite = Color(0x0AFFFFFF);
  static const Color glassWhiteMedium = Color(0x14FFFFFF);
  static const Color glassWhiteStrong = Color(0x1FFFFFFF);

  static const Color glassBlack = Color(0x0A000000);
  static const Color glassBlackMedium = Color(0x14000000);
  static const Color glassBlackStrong = Color(0x1F000000);

  // ============================================
  // Border Colors
  // ============================================

  static const Color darkBorder = Color(0xFF2D3748);
  static const Color darkBorderSubtle = Color(0xFF1A202C);
  static const Color darkBorderBold = Color(0xFF4A5568); // Bold borders for brutalist style
  static const Color lightBorder = Color(0xFFE5E7EB);
  static const Color lightBorderSubtle = Color(0xFFF3F4F6);
  static const Color lightBorderBold = Color(0xFF9CA3AF); // Bold borders for brutalist style

  // ============================================
  // Shadow Colors
  // ============================================

  static const Color shadowColor = Color(0x1A000000);
  static const Color shadowColorStrong = Color(0x33000000);
  static const Color shadowColorLight = Color(0x0D000000);

  // ============================================
  // Brutalist/Bold Design Elements
  // ============================================

  /// Bold border widths for brutalist aesthetic
  static const double borderThin = 1.0;
  static const double borderMedium = 2.0;
  static const double borderThick = 3.0;
  static const double borderExtraThick = 4.0;

  /// High contrast overlays for emphasis
  static const Color highContrastLight = Color(0xFFFFFFFF);
  static const Color highContrastDark = Color(0xFF000000);
}

/// Material 3 Color Scheme Extensions
extension PinpointColorScheme on ColorScheme {
  /// Get accent color based on index
  Color getAccentColor(int index) {
    final accents = [
      PinpointColors.mint,
      PinpointColors.iris,
      PinpointColors.rose,
      PinpointColors.amber,
      PinpointColors.ocean,
    ];
    return accents[index % accents.length];
  }

  /// Get surface color based on elevation level
  Color getSurfaceColor(int level) {
    if (brightness == Brightness.dark) {
      switch (level) {
        case 1:
          return PinpointColors.darkSurface1;
        case 2:
          return PinpointColors.darkSurface2;
        case 3:
          return PinpointColors.darkSurface3;
        case 4:
          return PinpointColors.darkSurface4;
        default:
          return PinpointColors.darkSurface1;
      }
    } else {
      switch (level) {
        case 1:
          return PinpointColors.lightSurface1;
        case 2:
          return PinpointColors.lightSurface2;
        case 3:
          return PinpointColors.lightSurface3;
        case 4:
          return PinpointColors.lightSurface4;
        default:
          return PinpointColors.lightSurface1;
      }
    }
  }

  /// Get text color based on emphasis
  Color getTextColor(TextEmphasis emphasis) {
    if (brightness == Brightness.dark) {
      switch (emphasis) {
        case TextEmphasis.primary:
          return PinpointColors.darkTextPrimary;
        case TextEmphasis.secondary:
          return PinpointColors.darkTextSecondary;
        case TextEmphasis.tertiary:
          return PinpointColors.darkTextTertiary;
        case TextEmphasis.disabled:
          return PinpointColors.darkTextDisabled;
      }
    } else {
      switch (emphasis) {
        case TextEmphasis.primary:
          return PinpointColors.lightTextPrimary;
        case TextEmphasis.secondary:
          return PinpointColors.lightTextSecondary;
        case TextEmphasis.tertiary:
          return PinpointColors.lightTextTertiary;
        case TextEmphasis.disabled:
          return PinpointColors.lightTextDisabled;
      }
    }
  }

  /// Get glass overlay color
  Color getGlassOverlay({bool strong = false}) {
    if (brightness == Brightness.dark) {
      return strong
          ? PinpointColors.glassWhiteStrong
          : PinpointColors.glassWhite;
    } else {
      return strong
          ? PinpointColors.glassBlackStrong
          : PinpointColors.glassBlack;
    }
  }
}

/// Text emphasis levels
enum TextEmphasis {
  primary,
  secondary,
  tertiary,
  disabled,
}

/// Tag color palette
class TagColors {
  final Color background;
  final Color foreground;
  final Color border;

  const TagColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  static const List<TagColors> presets = [
    TagColors(
      background: PinpointColors.mintSubtle,
      foreground: PinpointColors.mint,
      border: PinpointColors.mint,
    ),
    TagColors(
      background: PinpointColors.irisSubtle,
      foreground: PinpointColors.iris,
      border: PinpointColors.iris,
    ),
    TagColors(
      background: PinpointColors.roseSubtle,
      foreground: PinpointColors.rose,
      border: PinpointColors.rose,
    ),
    TagColors(
      background: PinpointColors.amberSubtle,
      foreground: PinpointColors.amber,
      border: PinpointColors.amber,
    ),
    TagColors(
      background: PinpointColors.oceanSubtle,
      foreground: PinpointColors.ocean,
      border: PinpointColors.ocean,
    ),
  ];

  static TagColors getPreset(int index) {
    return presets[index % presets.length];
  }
}
