import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';
import 'gradients.dart';
import 'typography.dart';
import 'elevations.dart';

/// Pinpoint Theme - Complete Material 3 theme with custom extensions
class PinpointTheme {
  // Private constructor to prevent instantiation
  PinpointTheme._();

  // ============================================
  // Theme Data
  // ============================================

  /// Create dark theme
  static ThemeData dark({
    Color? accentColor,
    bool highContrast = false,
    String? fontFamily,
  }) {
    final accent = accentColor ?? PinpointColors.accentRefined;

    final colorScheme = ColorScheme.dark(
      primary: accent,
      onPrimary: PinpointColors.onAccentRefined,
      primaryContainer: _darken(accent, 0.3),
      onPrimaryContainer: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      secondaryContainer: _darken(accent, 0.3),
      onSecondaryContainer: Colors.white,
      tertiary: accent,
      onTertiary: Colors.white,
      error: PinpointColors.rose,
      onError: Colors.white,
      surface: highContrast
          ? PinpointColors.darkSurface1
          : PinpointColors.keepDarkCard,
      surfaceContainerHighest: PinpointColors.keepDarkPill,
      onSurface:
          highContrast ? Colors.white : PinpointColors.keepDarkTextPrimary,
      onSurfaceVariant: PinpointColors.keepDarkTextSecondary,
      outline: PinpointColors.keepDarkDivider,
      outlineVariant: PinpointColors.keepDarkDivider,
      shadow: PinpointColors.shadowColor,
      scrim: Colors.black.withValues(alpha: 0.5),
      inverseSurface: PinpointColors.lightSurface2,
      onInverseSurface: PinpointColors.lightTextPrimary,
      inversePrimary: _darken(accent, 0.2),
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,

      // Typography
      textTheme: PinpointTypography.createTextTheme(
        brightness: Brightness.dark,
        primaryFont: fontFamily,
      ),

      // App Bar
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: PinpointTypography.createTextTheme(
          brightness: Brightness.dark,
          primaryFont: fontFamily,
        ).titleLarge,
      ),

      // Scaffold
      scaffoldBackgroundColor: PinpointColors.keepDarkCanvas,

      // Card — borderless, flat, Keep-style
      cardTheme: CardThemeData(
        elevation: 0,
        color: PinpointColors.keepDarkCard,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: PinpointColors.keepDarkPill,
        selectedColor: accent.withValues(alpha: 0.2),
        disabledColor: PinpointColors.keepDarkPill.withValues(alpha: 0.5),
        labelStyle: PinpointTypography.tagChip(brightness: Brightness.dark),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PinpointColors.keepDarkPill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: PinpointColors.rose, width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),

      // Floating Action Button — Keep-style rounded square
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: PinpointColors.onAccentRefined,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: PinpointColors.keepDarkBar,
        selectedItemColor: accent,
        unselectedItemColor: PinpointColors.keepDarkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: PinpointColors.keepDarkCard,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),

      // Bottom Sheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: PinpointColors.keepDarkBar,
        modalBackgroundColor: PinpointColors.keepDarkBar,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: PinpointColors.keepDarkDivider,
        thickness: 1,
        space: 1,
      ),

      // Icon
      iconTheme: IconThemeData(
        color: colorScheme.onSurface,
        size: 24,
      ),

      // Extensions
      extensions: [
        NoteGradients.dark(accentColor: accent),
        GlassSurface.dark(highContrast: highContrast),
        ListItemStyle.dark(accentColor: accent),
        TagStyle.dark(),
        ToolbarStyle.dark(accentColor: accent),
      ],
    );
  }

  /// Create light theme
  static ThemeData light({
    Color? accentColor,
    bool highContrast = false,
    String? fontFamily,
  }) {
    final accent = accentColor ?? PinpointColors.accentRefined;

    final colorScheme = ColorScheme.light(
      primary: accent,
      onPrimary: PinpointColors.onAccentRefined,
      primaryContainer: _lighten(accent, 0.7),
      onPrimaryContainer: _darken(accent, 0.3),
      secondary: accent,
      onSecondary: Colors.white,
      secondaryContainer: _lighten(accent, 0.7),
      onSecondaryContainer: _darken(accent, 0.3),
      tertiary: accent,
      onTertiary: Colors.white,
      error: PinpointColors.rose,
      onError: Colors.white,
      surface: highContrast ? Colors.white : PinpointColors.keepLightCanvas,
      surfaceContainerHighest: PinpointColors.keepLightPill,
      onSurface:
          highContrast ? Colors.black : PinpointColors.keepLightTextPrimary,
      onSurfaceVariant: PinpointColors.keepLightTextSecondary,
      outline: PinpointColors.keepLightDivider,
      outlineVariant: PinpointColors.keepLightCardBorder,
      shadow: PinpointColors.shadowColor,
      scrim: Colors.black.withValues(alpha: 0.5),
      inverseSurface: PinpointColors.darkSurface2,
      onInverseSurface: PinpointColors.darkTextPrimary,
      inversePrimary: _lighten(accent, 0.2),
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,

      // Typography
      textTheme: PinpointTypography.createTextTheme(
        brightness: Brightness.light,
        primaryFont: fontFamily,
      ),

      // App Bar
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: PinpointTypography.createTextTheme(
          brightness: Brightness.light,
          primaryFont: fontFamily,
        ).titleLarge,
      ),

      // Scaffold
      scaffoldBackgroundColor: PinpointColors.keepLightCanvas,

      // Card — borderless, flat, Keep-style
      cardTheme: CardThemeData(
        elevation: 0,
        color: PinpointColors.keepLightCard,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: PinpointColors.keepLightPill,
        selectedColor: accent.withValues(alpha: 0.15),
        disabledColor: PinpointColors.keepLightPill.withValues(alpha: 0.5),
        labelStyle: PinpointTypography.tagChip(brightness: Brightness.light),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PinpointColors.keepLightPill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: PinpointColors.rose, width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),

      // Floating Action Button — Keep-style rounded square
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: PinpointColors.onAccentRefined,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: PinpointColors.keepLightBar,
        selectedItemColor: accent,
        unselectedItemColor: PinpointColors.keepLightTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: PinpointColors.keepLightCard,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),

      // Bottom Sheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: PinpointColors.keepLightBar,
        modalBackgroundColor: PinpointColors.keepLightBar,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: PinpointColors.keepLightDivider,
        thickness: 1,
        space: 1,
      ),

      // Icon
      iconTheme: IconThemeData(
        color: colorScheme.onSurface,
        size: 24,
      ),

      // Extensions
      extensions: [
        NoteGradients.light(accentColor: accent),
        GlassSurface.light(highContrast: highContrast),
        ListItemStyle.light(accentColor: accent),
        TagStyle.light(),
        ToolbarStyle.light(accentColor: accent),
      ],
    );
  }

  // ============================================
  // Helper Methods
  // ============================================

  static Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

  static Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final hslLight =
        hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }
}

// ============================================
// Theme Extensions
// ============================================

/// Note gradient theme extension
class NoteGradients extends ThemeExtension<NoteGradients> {
  final Gradient heroGradient;
  final Gradient backgroundGradient;
  final Gradient accentGradient;
  final Gradient subtleGradient;

  const NoteGradients({
    required this.heroGradient,
    required this.backgroundGradient,
    required this.accentGradient,
    required this.subtleGradient,
  });

  factory NoteGradients.dark({Color? accentColor}) {
    return NoteGradients(
      heroGradient: PinpointGradients.crescentInk,
      backgroundGradient: PinpointGradients.subtleBackground(Brightness.dark),
      accentGradient: PinpointGradients.midnightAurora,
      subtleGradient: PinpointGradients.glassOverlay(Brightness.dark),
    );
  }

  factory NoteGradients.light({Color? accentColor}) {
    return NoteGradients(
      heroGradient: PinpointGradients.oceanQuartz,
      backgroundGradient: PinpointGradients.subtleBackground(Brightness.light),
      accentGradient: PinpointGradients.oceanQuartz,
      subtleGradient: PinpointGradients.glassOverlay(Brightness.light),
    );
  }

  @override
  NoteGradients copyWith({
    Gradient? heroGradient,
    Gradient? backgroundGradient,
    Gradient? accentGradient,
    Gradient? subtleGradient,
  }) {
    return NoteGradients(
      heroGradient: heroGradient ?? this.heroGradient,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      accentGradient: accentGradient ?? this.accentGradient,
      subtleGradient: subtleGradient ?? this.subtleGradient,
    );
  }

  @override
  NoteGradients lerp(ThemeExtension<NoteGradients>? other, double t) {
    if (other is! NoteGradients) return this;
    return NoteGradients(
      heroGradient: Gradient.lerp(heroGradient, other.heroGradient, t)!,
      backgroundGradient:
          Gradient.lerp(backgroundGradient, other.backgroundGradient, t)!,
      accentGradient: Gradient.lerp(accentGradient, other.accentGradient, t)!,
      subtleGradient: Gradient.lerp(subtleGradient, other.subtleGradient, t)!,
    );
  }
}

/// Glass surface theme extension
class GlassSurface extends ThemeExtension<GlassSurface> {
  final Color overlayColor;
  final Color borderColor;
  final double blurAmount;
  final double opacity;

  const GlassSurface({
    required this.overlayColor,
    required this.borderColor,
    required this.blurAmount,
    required this.opacity,
  });

  factory GlassSurface.dark({bool highContrast = false}) {
    return GlassSurface(
      overlayColor: highContrast
          ? PinpointColors.glassWhiteStrong
          : PinpointColors.glassWhiteMedium,
      borderColor: PinpointColors.darkBorder,
      blurAmount: highContrast ? 5 : 10,
      opacity: highContrast ? 0.15 : 0.1,
    );
  }

  factory GlassSurface.light({bool highContrast = false}) {
    return GlassSurface(
      overlayColor: highContrast
          ? PinpointColors.glassWhiteStrong
          : PinpointColors.glassWhiteMedium,
      borderColor: PinpointColors.lightBorder,
      blurAmount: highContrast ? 5 : 8,
      opacity: highContrast ? 0.95 : 0.9,
    );
  }

  @override
  GlassSurface copyWith({
    Color? overlayColor,
    Color? borderColor,
    double? blurAmount,
    double? opacity,
  }) {
    return GlassSurface(
      overlayColor: overlayColor ?? this.overlayColor,
      borderColor: borderColor ?? this.borderColor,
      blurAmount: blurAmount ?? this.blurAmount,
      opacity: opacity ?? this.opacity,
    );
  }

  @override
  GlassSurface lerp(ThemeExtension<GlassSurface>? other, double t) {
    if (other is! GlassSurface) return this;
    return GlassSurface(
      overlayColor: Color.lerp(overlayColor, other.overlayColor, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      blurAmount: lerpDouble(blurAmount, other.blurAmount, t)!,
      opacity: lerpDouble(opacity, other.opacity, t)!,
    );
  }
}

/// List item style theme extension
class ListItemStyle extends ThemeExtension<ListItemStyle> {
  final Color backgroundColor;
  final Color hoverColor;
  final Color pressedColor;
  final Color borderColor;
  final BorderRadius borderRadius;
  final EdgeInsets padding;
  final List<BoxShadow> elevation;

  const ListItemStyle({
    required this.backgroundColor,
    required this.hoverColor,
    required this.pressedColor,
    required this.borderColor,
    required this.borderRadius,
    required this.padding,
    required this.elevation,
  });

  factory ListItemStyle.dark({Color? accentColor}) {
    return ListItemStyle(
      backgroundColor: PinpointColors.keepDarkCard,
      hoverColor: PinpointColors.keepDarkPill,
      pressedColor: PinpointColors.keepDarkPill,
      borderColor: Colors.transparent, // borderless in dark
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.all(14),
      elevation: const [],
    );
  }

  factory ListItemStyle.light({Color? accentColor}) {
    return ListItemStyle(
      backgroundColor: PinpointColors.keepLightCard,
      hoverColor: PinpointColors.keepLightPill,
      pressedColor: PinpointColors.keepLightPill,
      borderColor: PinpointColors.keepLightCardBorder, // hairline in light
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.all(14),
      elevation: const [],
    );
  }

  @override
  ListItemStyle copyWith({
    Color? backgroundColor,
    Color? hoverColor,
    Color? pressedColor,
    Color? borderColor,
    BorderRadius? borderRadius,
    EdgeInsets? padding,
    List<BoxShadow>? elevation,
  }) {
    return ListItemStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      hoverColor: hoverColor ?? this.hoverColor,
      pressedColor: pressedColor ?? this.pressedColor,
      borderColor: borderColor ?? this.borderColor,
      borderRadius: borderRadius ?? this.borderRadius,
      padding: padding ?? this.padding,
      elevation: elevation ?? this.elevation,
    );
  }

  @override
  ListItemStyle lerp(ThemeExtension<ListItemStyle>? other, double t) {
    if (other is! ListItemStyle) return this;
    return ListItemStyle(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t)!,
      hoverColor: Color.lerp(hoverColor, other.hoverColor, t)!,
      pressedColor: Color.lerp(pressedColor, other.pressedColor, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      borderRadius: BorderRadius.lerp(borderRadius, other.borderRadius, t)!,
      padding: EdgeInsets.lerp(padding, other.padding, t)!,
      elevation: ElevationAnimation.lerp(elevation, other.elevation, t),
    );
  }
}

/// Tag style theme extension
class TagStyle extends ThemeExtension<TagStyle> {
  final List<TagColors> presets;
  final BorderRadius borderRadius;
  final EdgeInsets padding;
  final double fontSize;

  const TagStyle({
    required this.presets,
    required this.borderRadius,
    required this.padding,
    required this.fontSize,
  });

  factory TagStyle.dark() {
    return TagStyle(
      presets: TagColors.presets,
      borderRadius: BorderRadius.circular(999),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      fontSize: 12,
    );
  }

  factory TagStyle.light() {
    return TagStyle(
      presets: TagColors.presets,
      borderRadius: BorderRadius.circular(999),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      fontSize: 12,
    );
  }

  @override
  TagStyle copyWith({
    List<TagColors>? presets,
    BorderRadius? borderRadius,
    EdgeInsets? padding,
    double? fontSize,
  }) {
    return TagStyle(
      presets: presets ?? this.presets,
      borderRadius: borderRadius ?? this.borderRadius,
      padding: padding ?? this.padding,
      fontSize: fontSize ?? this.fontSize,
    );
  }

  @override
  TagStyle lerp(ThemeExtension<TagStyle>? other, double t) {
    if (other is! TagStyle) return this;
    return TagStyle(
      presets: t < 0.5 ? presets : other.presets,
      borderRadius: BorderRadius.lerp(borderRadius, other.borderRadius, t)!,
      padding: EdgeInsets.lerp(padding, other.padding, t)!,
      fontSize: lerpDouble(fontSize, other.fontSize, t)!,
    );
  }
}

/// Toolbar style theme extension
class ToolbarStyle extends ThemeExtension<ToolbarStyle> {
  final Color backgroundColor;
  final Gradient backgroundGradient;
  final Color iconColor;
  final Color activeIconColor;
  final BorderRadius borderRadius;
  final EdgeInsets padding;
  final List<BoxShadow> elevation;

  const ToolbarStyle({
    required this.backgroundColor,
    required this.backgroundGradient,
    required this.iconColor,
    required this.activeIconColor,
    required this.borderRadius,
    required this.padding,
    required this.elevation,
  });

  factory ToolbarStyle.dark({Color? accentColor}) {
    final accent = accentColor ?? PinpointColors.accentRefined;
    return ToolbarStyle(
      backgroundColor: PinpointColors.darkSurface3,
      backgroundGradient: PinpointGradients.glassOverlay(Brightness.dark),
      iconColor: PinpointColors.darkTextSecondary,
      activeIconColor: accent,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      elevation: PinpointElevations.md(Brightness.dark),
    );
  }

  factory ToolbarStyle.light({Color? accentColor}) {
    final accent = accentColor ?? PinpointColors.accentRefined;
    return ToolbarStyle(
      backgroundColor: PinpointColors.lightSurface3,
      backgroundGradient: PinpointGradients.glassOverlay(Brightness.light),
      iconColor: PinpointColors.lightTextSecondary,
      activeIconColor: accent,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      elevation: PinpointElevations.md(Brightness.light),
    );
  }

  @override
  ToolbarStyle copyWith({
    Color? backgroundColor,
    Gradient? backgroundGradient,
    Color? iconColor,
    Color? activeIconColor,
    BorderRadius? borderRadius,
    EdgeInsets? padding,
    List<BoxShadow>? elevation,
  }) {
    return ToolbarStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      iconColor: iconColor ?? this.iconColor,
      activeIconColor: activeIconColor ?? this.activeIconColor,
      borderRadius: borderRadius ?? this.borderRadius,
      padding: padding ?? this.padding,
      elevation: elevation ?? this.elevation,
    );
  }

  @override
  ToolbarStyle lerp(ThemeExtension<ToolbarStyle>? other, double t) {
    if (other is! ToolbarStyle) return this;
    return ToolbarStyle(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t)!,
      backgroundGradient:
          Gradient.lerp(backgroundGradient, other.backgroundGradient, t)!,
      iconColor: Color.lerp(iconColor, other.iconColor, t)!,
      activeIconColor: Color.lerp(activeIconColor, other.activeIconColor, t)!,
      borderRadius: BorderRadius.lerp(borderRadius, other.borderRadius, t)!,
      padding: EdgeInsets.lerp(padding, other.padding, t)!,
      elevation: ElevationAnimation.lerp(elevation, other.elevation, t),
    );
  }
}

// ============================================
// Theme Extension Helpers
// ============================================

/// Helper to get theme extensions with compile-time safety
extension ThemeExtensions on ThemeData {
  NoteGradients get noteGradients => extension<NoteGradients>()!;
  GlassSurface get glassSurface => extension<GlassSurface>()!;
  ListItemStyle get listItemStyle => extension<ListItemStyle>()!;
  TagStyle get tagStyle => extension<TagStyle>()!;
  ToolbarStyle get toolbarStyle => extension<ToolbarStyle>()!;
}
