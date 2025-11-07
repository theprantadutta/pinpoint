import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../colors.dart';
import '../gradients.dart';
import '../animations.dart';

/// GradientScaffold - Base screen with animated background gradient
///
/// Features:
/// - Animated background gradient with slow loop
/// - Respects reduce motion setting
/// - Optional custom gradient
/// - Safe area padding
/// - Customizable app bar
class GradientScaffold extends StatefulWidget {
  final Widget? body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final Color? backgroundColor;
  final Gradient? backgroundGradient;
  final bool animateGradient;
  final bool safeArea;
  final bool extendBodyBehindAppBar;
  final EdgeInsets? padding;

  const GradientScaffold({
    super.key,
    this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.drawer,
    this.backgroundColor,
    this.backgroundGradient,
    this.animateGradient = true,
    this.safeArea = true,
    this.extendBodyBehindAppBar = false,
    this.padding,
  });

  @override
  State<GradientScaffold> createState() => _GradientScaffoldState();
}

class _GradientScaffoldState extends State<GradientScaffold>
    with SingleTickerProviderStateMixin {
  late AnimationController _gradientController;

  @override
  void initState() {
    super.initState();
    _gradientController = AnimationController(
      vsync: this,
      duration: PinpointAnimations.gradientLoop,
    );

    if (widget.animateGradient) {
      _gradientController.repeat();
    }
  }

  @override
  void didUpdateWidget(GradientScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateGradient != oldWidget.animateGradient) {
      if (widget.animateGradient) {
        _gradientController.repeat();
      } else {
        _gradientController.stop();
      }
    }
  }

  @override
  void dispose() {
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final motionSettings = MotionSettings.fromMediaQuery(context);

    // Stop animation if reduce motion is enabled
    if (motionSettings.reduceMotion && _gradientController.isAnimating) {
      _gradientController.stop();
      _gradientController.value = 0;
    }

    final body = widget.safeArea && widget.body != null
        ? SafeArea(
            child: widget.padding != null
                ? Padding(padding: widget.padding!, child: widget.body!)
                : widget.body!,
          )
        : widget.body != null
            ? widget.padding != null
                ? Padding(padding: widget.padding!, child: widget.body!)
                : widget.body!
            : null;

    return Scaffold(
      extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
      backgroundColor: Colors.transparent,
      appBar: widget.appBar,
      body: Stack(
        children: [
          // Animated background gradient
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _gradientController,
              builder: (context, child) {
                return _AnimatedGradientBackground(
                  animation: _gradientController,
                  gradient: widget.backgroundGradient ??
                      _getDefaultGradient(brightness),
                  backgroundColor: widget.backgroundColor ??
                      (brightness == Brightness.dark
                          ? PinpointColors.darkSurface1
                          : PinpointColors.lightSurface1),
                );
              },
            ),
          ),
          // Content
          if (body != null) body,
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
      bottomNavigationBar: widget.bottomNavigationBar,
      drawer: widget.drawer,
    );
  }

  Gradient _getDefaultGradient(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return PinpointGradients.crescentInk;
    } else {
      return PinpointGradients.oceanQuartz;
    }
  }
}

/// Animated gradient background with subtle movement
class _AnimatedGradientBackground extends StatelessWidget {
  final Animation<double> animation;
  final Gradient gradient;
  final Color backgroundColor;

  const _AnimatedGradientBackground({
    required this.animation,
    required this.gradient,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate animated position
    final animatedValue = animation.value;
    final offsetX = math.sin(animatedValue * 2 * math.pi) * 0.1;
    final offsetY = math.cos(animatedValue * 2 * math.pi) * 0.1;

    final animatedGradient = _createAnimatedGradient(
      gradient,
      offsetX,
      offsetY,
    );

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        gradient: animatedGradient,
      ),
    );
  }

  Gradient _createAnimatedGradient(
    Gradient baseGradient,
    double offsetX,
    double offsetY,
  ) {
    if (baseGradient is LinearGradient) {
      return LinearGradient(
        begin: Alignment(
          (baseGradient.begin as Alignment).x + offsetX,
          (baseGradient.begin as Alignment).y + offsetY,
        ),
        end: Alignment(
          (baseGradient.end as Alignment).x - offsetX,
          (baseGradient.end as Alignment).y - offsetY,
        ),
        colors: baseGradient.colors,
        stops: baseGradient.stops,
      );
    } else if (baseGradient is RadialGradient) {
      return RadialGradient(
        center: Alignment(
          (baseGradient.center as Alignment).x + offsetX,
          (baseGradient.center as Alignment).y + offsetY,
        ),
        radius: baseGradient.radius,
        colors: baseGradient.colors,
        stops: baseGradient.stops,
      );
    }
    return baseGradient;
  }
}
