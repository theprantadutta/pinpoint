import 'package:flutter/material.dart';
import 'colors.dart';

/// Pinpoint Design System - Gradients
/// Cinematic gradient presets with animation-ready configurations
class PinpointGradients {
  // Private constructor to prevent instantiation
  PinpointGradients._();

  // ============================================
  // Gradient Presets
  // ============================================

  /// Crescent Ink - Elegant dark gray gradient with subtle teal
  static const LinearGradient crescentInk = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0F172A), // Slate 900
      Color(0xFF1E293B), // Slate 800
      Color(0xFF0F2027), // Dark with teal hint
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const RadialGradient crescentInkRadial = RadialGradient(
    center: Alignment.center,
    radius: 1.5,
    colors: [
      Color(0xFF1E293B), // Slate 800 center
      Color(0xFF0F172A), // Slate 900
      Color(0xFF0B0F1A), // Deep Ink edge
    ],
    stops: [0.0, 0.6, 1.0],
  );

  /// Neon Mint - Teal to green gradient
  static const LinearGradient neonMint = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFF14B8A6), // Teal
      Color(0xFF10B981), // Mint
      Color(0xFF22C55E), // Green
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const RadialGradient neonMintRadial = RadialGradient(
    center: Alignment.center,
    radius: 1.2,
    colors: [
      Color(0xFF22C55E), // Green center
      Color(0xFF10B981), // Mint
      Color(0xFF14B8A6), // Teal edge
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// Solar Rose - Orange to pink gradient
  static const LinearGradient solarRose = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF97316), // Orange
      Color(0xFFF43F5E), // Rose
      Color(0xFFEC4899), // Pink
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const RadialGradient solarRoseRadial = RadialGradient(
    center: Alignment(0.3, -0.3),
    radius: 1.8,
    colors: [
      Color(0xFFFBBF24), // Yellow accent
      Color(0xFFF97316), // Orange
      Color(0xFFF43F5E), // Rose
      Color(0xFFEC4899), // Pink edge
    ],
    stops: [0.0, 0.3, 0.7, 1.0],
  );

  /// Ocean Quartz - Elegant light gray gradient with warm accent
  static const LinearGradient oceanQuartz = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [
      Color(0xFFF8FAFC), // Slate 50
      Color(0xFFF1F5F9), // Slate 100
      Color(0xFFE2E8F0), // Slate 200
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const RadialGradient oceanQuartzRadial = RadialGradient(
    center: Alignment.center,
    radius: 1.4,
    colors: [
      Color(0xFFF8FAFC), // Slate 50 center
      Color(0xFFF1F5F9), // Slate 100
      Color(0xFFE2E8F0), // Slate 200 edge
    ],
    stops: [0.0, 0.6, 1.0],
  );

  /// Midnight Aurora - Dark charcoal with subtle warmth (for dark backgrounds)
  static const LinearGradient midnightAurora = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0B0F1A), // Deep Ink
      Color(0xFF111827), // Gray 900
      Color(0xFF1A202C), // Darker with warmth
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// Sunset Dream - Warm gradient for accents
  static const LinearGradient sunsetDream = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFBBF24), // Yellow
      Color(0xFFF97316), // Orange
      Color(0xFFDC2626), // Red
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// Subtle gradients for backgrounds
  static LinearGradient subtleBackground(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          PinpointColors.darkSurface1,
          PinpointColors.darkSurface2,
        ],
      );
    } else {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          PinpointColors.lightSurface1,
          PinpointColors.lightSurface2,
        ],
      );
    }
  }

  /// Glass morphism gradient overlay
  static LinearGradient glassOverlay(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.1),
          Colors.white.withOpacity(0.05),
        ],
      );
    } else {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.black.withOpacity(0.05),
          Colors.black.withOpacity(0.02),
        ],
      );
    }
  }

  /// Get gradient by index (for dynamic selection)
  static Gradient getPreset(int index) {
    final presets = [
      crescentInk,
      neonMint,
      solarRose,
      oceanQuartz,
      midnightAurora,
      sunsetDream,
    ];
    return presets[index % presets.length];
  }

  /// Get radial gradient by index
  static RadialGradient getRadialPreset(int index) {
    final presets = [
      crescentInkRadial,
      neonMintRadial,
      solarRoseRadial,
      oceanQuartzRadial,
    ];
    return presets[index % presets.length];
  }
}

/// Animated gradient configuration
class AnimatedGradientConfig {
  final List<Gradient> gradients;
  final Duration duration;
  final Curve curve;
  final bool pauseOnReduceMotion;

  const AnimatedGradientConfig({
    required this.gradients,
    this.duration = const Duration(seconds: 10),
    this.curve = Curves.easeInOut,
    this.pauseOnReduceMotion = true,
  });

  /// Default animated background configuration
  static const AnimatedGradientConfig defaultBackground =
      AnimatedGradientConfig(
    gradients: [
      PinpointGradients.crescentInk,
      PinpointGradients.midnightAurora,
      PinpointGradients.oceanQuartz,
    ],
    duration: Duration(seconds: 12),
  );

  /// Fast animation for interactive elements
  static const AnimatedGradientConfig fastInteractive = AnimatedGradientConfig(
    gradients: [
      PinpointGradients.neonMint,
      PinpointGradients.solarRose,
    ],
    duration: Duration(seconds: 2),
    curve: Curves.easeOutCubic,
  );
}

/// Gradient utilities
class GradientUtils {
  /// Create a shimmer effect gradient for loading states
  static LinearGradient shimmer({
    required Brightness brightness,
    double angle = 0.0,
  }) {
    final transform = GradientRotation(angle);

    if (brightness == Brightness.dark) {
      return LinearGradient(
        colors: [
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(0.05),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: transform,
      );
    } else {
      return LinearGradient(
        colors: [
          Colors.black.withOpacity(0.0),
          Colors.black.withOpacity(0.03),
          Colors.black.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: transform,
      );
    }
  }

  /// Create a gradient with custom colors
  static LinearGradient custom({
    required List<Color> colors,
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
    List<double>? stops,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: colors,
      stops: stops,
    );
  }

  /// Blend two gradients
  static Gradient blend(
    Gradient gradient1,
    Gradient gradient2,
    double t,
  ) {
    if (gradient1 is LinearGradient && gradient2 is LinearGradient) {
      return LinearGradient(
        begin: AlignmentGeometry.lerp(gradient1.begin, gradient2.begin, t)!,
        end: AlignmentGeometry.lerp(gradient1.end, gradient2.end, t)!,
        colors: List.generate(
          gradient1.colors.length,
          (i) => Color.lerp(
            gradient1.colors[i],
            i < gradient2.colors.length
                ? gradient2.colors[i]
                : gradient2.colors.last,
            t,
          )!,
        ),
      );
    }
    // Fallback to first gradient if types don't match
    return gradient1;
  }
}
