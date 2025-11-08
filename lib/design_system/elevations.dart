import 'package:flutter/material.dart';
import 'colors.dart';

/// Pinpoint Design System - Elevations
/// Standardized shadow presets for depth and hierarchy
class PinpointElevations {
  // Private constructor to prevent instantiation
  PinpointElevations._();

  // ============================================
  // Shadow Presets
  // ============================================

  /// No elevation - flat surface
  static List<BoxShadow> get none => const [];

  /// Extra small elevation - subtle depth
  static List<BoxShadow> xs(Brightness brightness) => [
        BoxShadow(
          color: _shadowColor(brightness, 0.04),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  /// Small elevation - cards and list items
  static List<BoxShadow> sm(Brightness brightness) => [
        BoxShadow(
          color: _shadowColor(brightness, 0.06),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: _shadowColor(brightness, 0.02),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  /// Medium elevation - floating elements
  static List<BoxShadow> md(Brightness brightness) => [
        BoxShadow(
          color: _shadowColor(brightness, 0.08),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: _shadowColor(brightness, 0.04),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  /// Large elevation - modals and dialogs
  static List<BoxShadow> lg(Brightness brightness) => [
        BoxShadow(
          color: _shadowColor(brightness, 0.10),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: _shadowColor(brightness, 0.05),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];

  /// Extra large elevation - high priority overlays
  static List<BoxShadow> xl(Brightness brightness) => [
        BoxShadow(
          color: _shadowColor(brightness, 0.12),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: _shadowColor(brightness, 0.06),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ];

  /// 2XL elevation - maximum depth
  static List<BoxShadow> xxl(Brightness brightness) => [
        BoxShadow(
          color: _shadowColor(brightness, 0.14),
          blurRadius: 32,
          offset: const Offset(0, 16),
        ),
        BoxShadow(
          color: _shadowColor(brightness, 0.08),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];

  // ============================================
  // Special Effect Shadows
  // ============================================

  /// Glow effect for interactive elements
  static List<BoxShadow> glow({
    required Color color,
    double intensity = 0.4,
    double blur = 16,
  }) =>
      [
        BoxShadow(
          color: color.withValues(alpha: intensity),
          blurRadius: blur,
          spreadRadius: blur * 0.3,
        ),
      ];

  /// Inner shadow for pressed/inset effect
  static List<BoxShadow> inner(Brightness brightness) => [
        BoxShadow(
          color: _shadowColor(brightness, 0.08),
          blurRadius: 4,
          offset: const Offset(0, -2),
        ),
      ];

  /// Colored elevation for accent elements
  static List<BoxShadow> colored({
    required Color color,
    required Brightness brightness,
    ElevationLevel level = ElevationLevel.medium,
  }) {
    final opacity = _getOpacityForLevel(level);
    final blur = _getBlurForLevel(level);
    final offset = _getOffsetForLevel(level);

    return [
      BoxShadow(
        color: color.withValues(alpha: opacity * 0.3),
        blurRadius: blur,
        offset: offset,
      ),
      BoxShadow(
        color: _shadowColor(brightness, opacity * 0.5),
        blurRadius: blur * 0.5,
        offset: Offset(offset.dx * 0.5, offset.dy * 0.5),
      ),
    ];
  }

  /// Soft ambient shadow
  static List<BoxShadow> soft(Brightness brightness) => [
        BoxShadow(
          color: _shadowColor(brightness, 0.05),
          blurRadius: 20,
          spreadRadius: -5,
          offset: const Offset(0, 10),
        ),
      ];

  /// Sharp shadow for text or icons
  static List<BoxShadow> sharp(Brightness brightness) => [
        BoxShadow(
          color: _shadowColor(brightness, 0.15),
          blurRadius: 0,
          offset: const Offset(2, 2),
        ),
      ];

  // ============================================
  // Helper Methods
  // ============================================

  /// Get shadow color based on brightness
  static Color _shadowColor(Brightness brightness, double opacity) {
    if (brightness == Brightness.dark) {
      // Darker, more subtle shadows for dark mode
      return Colors.black.withValues(alpha: opacity * 1.5);
    } else {
      // Much softer, barely visible shadows for light mode
      return PinpointColors.shadowColor.withValues(alpha: opacity * 0.3);
    }
  }

  /// Get opacity for elevation level
  static double _getOpacityForLevel(ElevationLevel level) {
    switch (level) {
      case ElevationLevel.none:
        return 0.0;
      case ElevationLevel.extraSmall:
        return 0.04;
      case ElevationLevel.small:
        return 0.06;
      case ElevationLevel.medium:
        return 0.08;
      case ElevationLevel.large:
        return 0.10;
      case ElevationLevel.extraLarge:
        return 0.12;
      case ElevationLevel.xxLarge:
        return 0.14;
    }
  }

  /// Get blur radius for elevation level
  static double _getBlurForLevel(ElevationLevel level) {
    switch (level) {
      case ElevationLevel.none:
        return 0;
      case ElevationLevel.extraSmall:
        return 2;
      case ElevationLevel.small:
        return 4;
      case ElevationLevel.medium:
        return 8;
      case ElevationLevel.large:
        return 16;
      case ElevationLevel.extraLarge:
        return 24;
      case ElevationLevel.xxLarge:
        return 32;
    }
  }

  /// Get offset for elevation level
  static Offset _getOffsetForLevel(ElevationLevel level) {
    switch (level) {
      case ElevationLevel.none:
        return Offset.zero;
      case ElevationLevel.extraSmall:
        return const Offset(0, 1);
      case ElevationLevel.small:
        return const Offset(0, 2);
      case ElevationLevel.medium:
        return const Offset(0, 4);
      case ElevationLevel.large:
        return const Offset(0, 8);
      case ElevationLevel.extraLarge:
        return const Offset(0, 12);
      case ElevationLevel.xxLarge:
        return const Offset(0, 16);
    }
  }

  /// Get elevation by level
  static List<BoxShadow> byLevel(
    Brightness brightness,
    ElevationLevel level,
  ) {
    switch (level) {
      case ElevationLevel.none:
        return none;
      case ElevationLevel.extraSmall:
        return xs(brightness);
      case ElevationLevel.small:
        return sm(brightness);
      case ElevationLevel.medium:
        return md(brightness);
      case ElevationLevel.large:
        return lg(brightness);
      case ElevationLevel.extraLarge:
        return xl(brightness);
      case ElevationLevel.xxLarge:
        return xxl(brightness);
    }
  }
}

/// Elevation levels enum
enum ElevationLevel {
  none,
  extraSmall,
  small,
  medium,
  large,
  extraLarge,
  xxLarge,
}

/// Material elevation mapping
class MaterialElevations {
  // Mapping Material Design elevation values to our system
  static ElevationLevel fromMaterial(double elevation) {
    if (elevation == 0) return ElevationLevel.none;
    if (elevation <= 1) return ElevationLevel.extraSmall;
    if (elevation <= 3) return ElevationLevel.small;
    if (elevation <= 6) return ElevationLevel.medium;
    if (elevation <= 8) return ElevationLevel.large;
    if (elevation <= 12) return ElevationLevel.extraLarge;
    return ElevationLevel.xxLarge;
  }

  /// Convert our elevation level to Material elevation
  static double toMaterial(ElevationLevel level) {
    switch (level) {
      case ElevationLevel.none:
        return 0;
      case ElevationLevel.extraSmall:
        return 1;
      case ElevationLevel.small:
        return 2;
      case ElevationLevel.medium:
        return 4;
      case ElevationLevel.large:
        return 8;
      case ElevationLevel.extraLarge:
        return 12;
      case ElevationLevel.xxLarge:
        return 16;
    }
  }
}

/// Elevation animation utilities
class ElevationAnimation {
  /// Animate between elevation levels
  static List<BoxShadow> lerp(
    List<BoxShadow> a,
    List<BoxShadow> b,
    double t,
  ) {
    if (a.isEmpty && b.isEmpty) return [];
    if (a.isEmpty) return b.map((s) => _lerpShadow(null, s, t)).toList();
    if (b.isEmpty) return a.map((s) => _lerpShadow(s, null, t)).toList();

    final maxLength = a.length > b.length ? a.length : b.length;
    return List.generate(maxLength, (i) {
      final shadowA = i < a.length ? a[i] : null;
      final shadowB = i < b.length ? b[i] : null;
      return _lerpShadow(shadowA, shadowB, t);
    });
  }

  static BoxShadow _lerpShadow(BoxShadow? a, BoxShadow? b, double t) {
    if (a == null && b == null) {
      return const BoxShadow(color: Colors.transparent);
    }
    if (a == null) {
      return BoxShadow(
        color: b!.color.withValues(alpha: b.color.opacity * t),
        blurRadius: b.blurRadius * t,
        spreadRadius: b.spreadRadius * t,
        offset: Offset.lerp(Offset.zero, b.offset, t)!,
      );
    }
    if (b == null) {
      return BoxShadow(
        color: a.color.withValues(alpha: a.color.opacity * (1 - t)),
        blurRadius: a.blurRadius * (1 - t),
        spreadRadius: a.spreadRadius * (1 - t),
        offset: Offset.lerp(a.offset, Offset.zero, t)!,
      );
    }
    return BoxShadow.lerp(a, b, t)!;
  }
}
