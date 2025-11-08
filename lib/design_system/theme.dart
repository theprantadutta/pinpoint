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
  }) {
    final accent = accentColor ?? PinpointColors.mint;

    final colorScheme = ColorScheme.dark(
      primary: accent,
      onPrimary: Colors.white,
      primaryContainer: _darken(accent, 0.3),
      onPrimaryContainer: Colors.white,
      secondary: PinpointColors.iris,
      onSecondary: Colors.white,
      secondaryContainer: _darken(PinpointColors.iris, 0.3),
      onSecondaryContainer: Colors.white,
      tertiary: PinpointColors.ocean,
      onTertiary: Colors.white,
      error: PinpointColors.rose,
      onError: Colors.white,
      surface: highContrast
          ? PinpointColors.darkSurface1
          : PinpointColors.darkSurface2,
      onSurface: highContrast ? Colors.white : PinpointColors.darkTextPrimary,
      onSurfaceVariant: PinpointColors.darkTextSecondary,
      outline: PinpointColors.darkBorder,
      outlineVariant: PinpointColors.darkBorderSubtle,
      shadow: PinpointColors.shadowColor,
      scrim: Colors.black.withValues(alpha: 0.5),
      inverseSurface: PinpointColors.lightSurface2,
      onInverseSurface: PinpointColors.lightTextPrimary,
      inversePrimary: _darken(accent, 0.2),
      surfaceTint: accent,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,

      // Typography
      textTheme: PinpointTypography.createTextTheme(
        brightness: Brightness.dark,
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
        ).titleLarge,
      ),

      // Scaffold
      scaffoldBackgroundColor: PinpointColors.darkSurface1,

      // Card
      cardTheme: CardThemeData(
        elevation: 0,
        color: PinpointColors.darkSurface2,
        shadowColor: PinpointColors.shadowColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: PinpointColors.darkSurface3,
        selectedColor: accent.withValues(alpha: 0.2),
        disabledColor: PinpointColors.darkSurface3.withValues(alpha: 0.5),
        labelStyle: PinpointTypography.tagChip(brightness: Brightness.dark),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PinpointColors.darkSurface3,
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

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: PinpointColors.darkSurface2.withValues(alpha: 0.8),
        selectedItemColor: accent,
        unselectedItemColor: PinpointColors.darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: PinpointColors.darkSurface2,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
      ),

      // Bottom Sheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: PinpointColors.darkSurface2,
        modalBackgroundColor: PinpointColors.darkSurface2,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: PinpointColors.darkBorder,
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
  }) {
    final accent = accentColor ?? PinpointColors.mint;

    final colorScheme = ColorScheme.light(
      primary: accent,
      onPrimary: Colors.white,
      primaryContainer: _lighten(accent, 0.7),
      onPrimaryContainer: _darken(accent, 0.3),
      secondary: PinpointColors.iris,
      onSecondary: Colors.white,
      secondaryContainer: _lighten(PinpointColors.iris, 0.7),
      onSecondaryContainer: _darken(PinpointColors.iris, 0.3),
      tertiary: PinpointColors.ocean,
      onTertiary: Colors.white,
      error: PinpointColors.rose,
      onError: Colors.white,
      surface: highContrast ? Colors.white : PinpointColors.lightSurface1,
      onSurface: highContrast ? Colors.black : PinpointColors.lightTextPrimary,
      onSurfaceVariant: PinpointColors.lightTextSecondary,
      outline: PinpointColors.lightBorder,
      outlineVariant: PinpointColors.lightBorderSubtle,
      shadow: PinpointColors.shadowColor,
      scrim: Colors.black.withValues(alpha: 0.5),
      inverseSurface: PinpointColors.darkSurface2,
      onInverseSurface: PinpointColors.darkTextPrimary,
      inversePrimary: _lighten(accent, 0.2),
      surfaceTint: accent,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,

      // Typography
      textTheme: PinpointTypography.createTextTheme(
        brightness: Brightness.light,
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
        ).titleLarge,
      ),

      // Scaffold
      scaffoldBackgroundColor: PinpointColors.lightSurface1,

      // Card
      cardTheme: CardThemeData(
        elevation: 0,
        color: PinpointColors.lightSurface2,
        shadowColor: PinpointColors.shadowColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: PinpointColors.lightSurface3,
        selectedColor: accent.withValues(alpha: 0.15),
        disabledColor: PinpointColors.lightSurface3.withValues(alpha: 0.5),
        labelStyle: PinpointTypography.tagChip(brightness: Brightness.light),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PinpointColors.lightSurface3,
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

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: PinpointColors.lightSurface2.withValues(alpha: 0.9),
        selectedItemColor: accent,
        unselectedItemColor: PinpointColors.lightTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: PinpointColors.lightSurface2,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
      ),

      // Bottom Sheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: PinpointColors.lightSurface2,
        modalBackgroundColor: PinpointColors.lightSurface2,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: PinpointColors.lightBorder,
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
      backgroundColor: PinpointColors.darkSurface2,
      hoverColor: PinpointColors.darkSurface3,
      pressedColor: PinpointColors.darkSurface4,
      borderColor: PinpointColors.darkBorderSubtle,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(16),
      elevation: PinpointElevations.sm(Brightness.dark),
    );
  }

  factory ListItemStyle.light({Color? accentColor}) {
    return ListItemStyle(
      backgroundColor: PinpointColors.lightSurface2,
      hoverColor: PinpointColors.lightSurface3,
      pressedColor: PinpointColors.lightSurface4,
      borderColor: PinpointColors.lightBorderSubtle,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(16),
      elevation: PinpointElevations.sm(Brightness.light),
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
    final accent = accentColor ?? PinpointColors.mint;
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
    final accent = accentColor ?? PinpointColors.mint;
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
