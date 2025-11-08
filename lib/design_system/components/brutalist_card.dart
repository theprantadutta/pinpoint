import 'package:flutter/material.dart';
import '../animations.dart';
import '../colors.dart';
import '../elevations.dart';
import '../spacing.dart';

/// Brutalist Card Component
/// Bold card with multiple variants and hover/press animations
class BrutalistCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BrutalistCardVariant variant;
  final double? width;
  final double? height;
  final EdgeInsets? padding;
  final double? borderRadius;
  final bool enableHoverEffect;
  final Color? customColor;
  final Color? customBorderColor;

  const BrutalistCard({
    super.key,
    required this.child,
    this.onTap,
    this.variant = BrutalistCardVariant.elevated,
    this.width,
    this.height,
    this.padding,
    this.borderRadius,
    this.enableHoverEffect = true,
    this.customColor,
    this.customBorderColor,
  });

  @override
  State<BrutalistCard> createState() => _BrutalistCardState();
}

class _BrutalistCardState extends State<BrutalistCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _elevationAnimation;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: PinpointAnimations.cardLift.duration,
      vsync: this,
    );
    _elevationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _hoverController,
        curve: PinpointAnimations.cardLift.curve,
      ),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(
        parent: _hoverController,
        curve: PinpointAnimations.emphasizedDecelerate,
      ),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _handleHoverEnter(PointerEvent details) {
    if (widget.enableHoverEffect && widget.onTap != null) {
      _hoverController.forward();
    }
  }

  void _handleHoverExit(PointerEvent details) {
    if (widget.enableHoverEffect) {
      _hoverController.reverse();
    }
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      setState(() => _isPressed = true);
      PinpointHaptics.light();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final colorScheme = theme.colorScheme;

    final cardStyle = _getCardStyle(brightness, colorScheme);

    return MouseRegion(
      onEnter: _handleHoverEnter,
      onExit: _handleHoverExit,
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _hoverController,
          builder: (context, child) {
            final currentElevation = _elevationAnimation.value;
            final shadows = _isPressed
                ? cardStyle.pressedShadow
                : _interpolateShadows(
                    cardStyle.shadow,
                    cardStyle.hoverShadow,
                    currentElevation,
                  );

            return ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: widget.width,
                height: widget.height,
                padding: widget.padding ?? SpacingPresets.cardPaddingGenerous,
                decoration: BoxDecoration(
                  color: widget.customColor ?? cardStyle.backgroundColor,
                  border: cardStyle.borderWidth > 0
                      ? Border.all(
                          color: widget.customBorderColor ??
                              cardStyle.borderColor,
                          width: cardStyle.borderWidth,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(
                    widget.borderRadius ?? cardStyle.borderRadius,
                  ),
                  boxShadow: shadows,
                ),
                child: widget.child,
              ),
            );
          },
        ),
      ),
    );
  }

  _CardStyle _getCardStyle(Brightness brightness, ColorScheme colorScheme) {
    switch (widget.variant) {
      case BrutalistCardVariant.elevated:
        return _CardStyle(
          backgroundColor: brightness == Brightness.dark
              ? PinpointColors.darkSurface2
              : PinpointColors.lightSurface1,
          borderColor: Colors.transparent,
          borderWidth: 0,
          borderRadius: 20,
          shadow: PinpointElevations.brutalist(brightness),
          hoverShadow: PinpointElevations.brutalistBold(brightness),
          pressedShadow: PinpointElevations.brutalistInset(brightness),
        );

      case BrutalistCardVariant.outlined:
        return _CardStyle(
          backgroundColor: brightness == Brightness.dark
              ? PinpointColors.darkSurface1
              : PinpointColors.lightSurface1,
          borderColor: brightness == Brightness.dark
              ? PinpointColors.darkBorderBold
              : PinpointColors.lightBorderBold,
          borderWidth: PinpointColors.borderThick,
          borderRadius: 20,
          shadow: [],
          hoverShadow: PinpointElevations.brutalist(brightness),
          pressedShadow: PinpointElevations.brutalistInset(brightness),
        );

      case BrutalistCardVariant.filled:
        return _CardStyle(
          backgroundColor: brightness == Brightness.dark
              ? PinpointColors.darkSurface3
              : PinpointColors.lightSurface3,
          borderColor: Colors.transparent,
          borderWidth: 0,
          borderRadius: 20,
          shadow: [],
          hoverShadow: PinpointElevations.brutalist(brightness),
          pressedShadow: [],
        );

      case BrutalistCardVariant.layered:
        return _CardStyle(
          backgroundColor: brightness == Brightness.dark
              ? PinpointColors.darkSurface2
              : PinpointColors.lightSurface1,
          borderColor: brightness == Brightness.dark
              ? PinpointColors.darkBorderBold
              : PinpointColors.lightBorderBold,
          borderWidth: PinpointColors.borderMedium,
          borderRadius: 20,
          shadow: PinpointElevations.brutalistLayered(
            brightness,
            accentColor: colorScheme.primary,
          ),
          hoverShadow: PinpointElevations.brutalistBold(
            brightness,
            color: colorScheme.primary,
          ),
          pressedShadow: PinpointElevations.brutalistInset(brightness),
        );

      case BrutalistCardVariant.glass:
        return _CardStyle(
          backgroundColor: brightness == Brightness.dark
              ? PinpointColors.glassWhiteMedium
              : PinpointColors.glassBlackMedium,
          borderColor: brightness == Brightness.dark
              ? PinpointColors.glassWhiteStrong
              : PinpointColors.glassBlackStrong,
          borderWidth: PinpointColors.borderThin,
          borderRadius: 24,
          shadow: PinpointElevations.soft(brightness),
          hoverShadow: PinpointElevations.md(brightness),
          pressedShadow: [],
        );
    }
  }

  List<BoxShadow> _interpolateShadows(
    List<BoxShadow> from,
    List<BoxShadow> to,
    double t,
  ) {
    if (from.isEmpty && to.isEmpty) return [];
    if (from.isEmpty) {
      return to
          .map((s) => BoxShadow(
                color: s.color.withValues(alpha: s.color.a * t),
                blurRadius: s.blurRadius * t,
                spreadRadius: s.spreadRadius * t,
                offset: Offset.lerp(Offset.zero, s.offset, t)!,
              ))
          .toList();
    }
    if (to.isEmpty) {
      return from
          .map((s) => BoxShadow(
                color: s.color.withValues(alpha: s.color.a * (1 - t)),
                blurRadius: s.blurRadius * (1 - t),
                spreadRadius: s.spreadRadius * (1 - t),
                offset: Offset.lerp(s.offset, Offset.zero, t)!,
              ))
          .toList();
    }

    return List.generate(
      from.length > to.length ? from.length : to.length,
      (i) {
        final shadowFrom = i < from.length ? from[i] : null;
        final shadowTo = i < to.length ? to[i] : null;
        if (shadowFrom == null && shadowTo == null) {
          return const BoxShadow(color: Colors.transparent);
        }
        if (shadowFrom == null) {
          return BoxShadow(
            color: shadowTo!.color.withValues(alpha: shadowTo.color.a * t),
            blurRadius: shadowTo.blurRadius * t,
            spreadRadius: shadowTo.spreadRadius * t,
            offset: Offset.lerp(Offset.zero, shadowTo.offset, t)!,
          );
        }
        if (shadowTo == null) {
          return BoxShadow(
            color: shadowFrom.color
                .withValues(alpha: shadowFrom.color.a * (1 - t)),
            blurRadius: shadowFrom.blurRadius * (1 - t),
            spreadRadius: shadowFrom.spreadRadius * (1 - t),
            offset: Offset.lerp(shadowFrom.offset, Offset.zero, t)!,
          );
        }
        return BoxShadow.lerp(shadowFrom, shadowTo, t)!;
      },
    );
  }
}

enum BrutalistCardVariant {
  elevated, // Elevated with shadow
  outlined, // Border with no shadow
  filled, // Filled background with no shadow
  layered, // Border + layered shadow
  glass, // Glassmorphic effect
}

class _CardStyle {
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final List<BoxShadow> shadow;
  final List<BoxShadow> hoverShadow;
  final List<BoxShadow> pressedShadow;

  _CardStyle({
    required this.backgroundColor,
    required this.borderColor,
    required this.borderWidth,
    required this.borderRadius,
    required this.shadow,
    required this.hoverShadow,
    required this.pressedShadow,
  });
}
