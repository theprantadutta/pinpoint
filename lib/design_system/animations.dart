import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pinpoint Design System - Animations
/// Motion configurations and animation utilities
class PinpointAnimations {
  // Private constructor to prevent instantiation
  PinpointAnimations._();

  // ============================================
  // Duration Presets
  // ============================================

  /// Instant - no animation
  static const Duration instant = Duration.zero;

  /// Very fast - micro-interactions
  static const Duration veryFast = Duration(milliseconds: 100);

  /// Fast - quick transitions
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration durationFast = Duration(milliseconds: 200); // Alias

  /// Normal - standard transitions
  static const Duration normal = Duration(milliseconds: 300);

  /// Medium - modal/sheet animations
  static const Duration medium = Duration(milliseconds: 400);

  /// Slow - page transitions
  static const Duration slow = Duration(milliseconds: 500);

  /// Very slow - background animations
  static const Duration verySlow = Duration(milliseconds: 800);

  /// Background gradient animation duration
  static const Duration gradientLoop = Duration(seconds: 12);

  /// Shimmer animation duration
  static const Duration shimmer = Duration(milliseconds: 1500);

  // ============================================
  // Curve Presets
  // ============================================

  /// Standard easing - most common
  static const Curve standard = Curves.easeInOut;

  /// Deceleration - entering elements
  static const Curve decelerate = Curves.easeOut;

  /// Acceleration - exiting elements
  static const Curve accelerate = Curves.easeIn;

  /// Sharp - quick emphasis
  static const Curve sharp = Curves.easeInOutCubic;

  /// Emphasized - Material 3 emphasized easing
  static const Curve emphasized = Cubic(0.2, 0.0, 0, 1.0);

  /// Emphasized decelerate - Material 3
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Emphasized accelerate - Material 3
  static const Curve emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);

  /// Spring - bouncy effect
  static const Curve spring = Curves.elasticOut;

  /// Smooth - gentle animation
  static const Curve smooth = Curves.easeOutQuart;

  // ============================================
  // Animation Configs
  // ============================================

  /// Page transition configuration
  static const AnimationConfig pageTransition = AnimationConfig(
    duration: slow,
    curve: emphasizedDecelerate,
  );

  /// Sheet/modal transition configuration
  static const AnimationConfig sheetTransition = AnimationConfig(
    duration: medium,
    curve: emphasized,
  );

  /// Card/list item entrance
  static const AnimationConfig itemEntrance = AnimationConfig(
    duration: normal,
    curve: emphasizedDecelerate,
  );

  /// Micro-interaction (buttons, chips)
  static const AnimationConfig microInteraction = AnimationConfig(
    duration: fast,
    curve: sharp,
  );

  /// Fade transition
  static const AnimationConfig fade = AnimationConfig(
    duration: normal,
    curve: standard,
  );

  /// Scale transition
  static const AnimationConfig scale = AnimationConfig(
    duration: fast,
    curve: emphasizedDecelerate,
  );

  /// Slide transition
  static const AnimationConfig slide = AnimationConfig(
    duration: normal,
    curve: emphasized,
  );

  /// Stagger delay between list items
  static const Duration staggerDelay = Duration(milliseconds: 50);

  /// Maximum stagger offset for lists
  static const Duration maxStaggerOffset = Duration(milliseconds: 300);
}

/// Animation configuration
class AnimationConfig {
  final Duration duration;
  final Curve curve;

  const AnimationConfig({
    required this.duration,
    required this.curve,
  });

  /// Get duration adjusted for reduce motion
  Duration getDuration(bool reduceMotion) {
    return reduceMotion ? PinpointAnimations.instant : duration;
  }

  /// Get curve adjusted for reduce motion
  Curve getCurve(bool reduceMotion) {
    return reduceMotion ? Curves.linear : curve;
  }
}

/// Motion settings - respects system reduce motion preference
class MotionSettings {
  final bool reduceMotion;
  final bool disableAnimations;

  const MotionSettings({
    this.reduceMotion = false,
    this.disableAnimations = false,
  });

  /// Check if animations should be enabled
  bool get animationsEnabled => !disableAnimations && !reduceMotion;

  /// Get duration (0 if animations disabled)
  Duration getDuration(Duration baseDuration) {
    if (disableAnimations || reduceMotion) return Duration.zero;
    return baseDuration;
  }

  /// Get curve (linear if animations disabled)
  Curve getCurve(Curve baseCurve) {
    if (disableAnimations || reduceMotion) return Curves.linear;
    return baseCurve;
  }

  /// Create from MediaQuery
  factory MotionSettings.fromMediaQuery(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return MotionSettings(reduceMotion: reduceMotion);
  }
}

/// Haptic feedback utilities
class PinpointHaptics {
  /// Light impact - tap, toggle
  static Future<void> light() async {
    await HapticFeedback.lightImpact();
  }

  /// Medium impact - button press, card tap
  static Future<void> medium() async {
    await HapticFeedback.mediumImpact();
  }

  /// Heavy impact - important action, error
  static Future<void> heavy() async {
    await HapticFeedback.heavyImpact();
  }

  /// Selection changed - slider, picker
  static Future<void> selection() async {
    await HapticFeedback.selectionClick();
  }

  /// Success - completed action
  static Future<void> success() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }

  /// Error - failed action
  static Future<void> error() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.mediumImpact();
  }

  /// Warning - caution needed
  static Future<void> warning() async {
    await HapticFeedback.mediumImpact();
  }
}

/// Stagger animation helper
class StaggerAnimation {
  final Duration delay;
  final Duration itemDelay;
  final int itemCount;

  const StaggerAnimation({
    this.delay = Duration.zero,
    this.itemDelay = PinpointAnimations.staggerDelay,
    required this.itemCount,
  });

  /// Get delay for item at index
  Duration getDelay(int index) {
    final staggerOffset = itemDelay * index;
    final cappedOffset = staggerOffset > PinpointAnimations.maxStaggerOffset
        ? PinpointAnimations.maxStaggerOffset
        : staggerOffset;
    return delay + cappedOffset;
  }

  /// Calculate total animation duration
  Duration get totalDuration {
    return delay + (itemDelay * itemCount.clamp(0, 6));
  }
}

/// Page transition builders
class PinpointPageTransitions {
  /// Slide and fade transition
  static Widget slideAndFade({
    required BuildContext context,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
    SlideDirection direction = SlideDirection.fromRight,
  }) {
    final offsetTween = _getOffsetTween(direction);

    return SlideTransition(
      position: animation.drive(
        offsetTween.chain(CurveTween(curve: PinpointAnimations.emphasized)),
      ),
      child: FadeTransition(
        opacity: animation.drive(
          Tween<double>(begin: 0.0, end: 1.0).chain(
            CurveTween(curve: PinpointAnimations.emphasizedDecelerate),
          ),
        ),
        child: child,
      ),
    );
  }

  /// Spring sheet transition (from bottom)
  static Widget springSheet({
    required BuildContext context,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
  }) {
    return SlideTransition(
      position: animation.drive(
        Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).chain(CurveTween(curve: PinpointAnimations.emphasized)),
      ),
      child: FadeTransition(
        opacity: animation.drive(
          Tween<double>(begin: 0.0, end: 1.0).chain(
            CurveTween(curve: Curves.easeOut),
          ),
        ),
        child: child,
      ),
    );
  }

  /// Fade transition
  static Widget fade({
    required BuildContext context,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
  }) {
    return FadeTransition(
      opacity: animation.drive(
        Tween<double>(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: PinpointAnimations.standard),
        ),
      ),
      child: child,
    );
  }

  /// Scale and fade transition
  static Widget scaleAndFade({
    required BuildContext context,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
  }) {
    return ScaleTransition(
      scale: animation.drive(
        Tween<double>(begin: 0.9, end: 1.0).chain(
          CurveTween(curve: PinpointAnimations.emphasizedDecelerate),
        ),
      ),
      child: FadeTransition(
        opacity: animation.drive(
          Tween<double>(begin: 0.0, end: 1.0).chain(
            CurveTween(curve: Curves.easeOut),
          ),
        ),
        child: child,
      ),
    );
  }

  static Tween<Offset> _getOffsetTween(SlideDirection direction) {
    switch (direction) {
      case SlideDirection.fromRight:
        return Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        );
      case SlideDirection.fromLeft:
        return Tween<Offset>(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        );
      case SlideDirection.fromTop:
        return Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        );
      case SlideDirection.fromBottom:
        return Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        );
    }
  }
}

/// Slide direction for page transitions
enum SlideDirection {
  fromRight,
  fromLeft,
  fromTop,
  fromBottom,
}
