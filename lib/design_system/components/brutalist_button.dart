import 'package:flutter/material.dart';
import '../animations.dart';
import '../colors.dart';
import '../elevations.dart';
import '../spacing.dart';
import '../typography.dart';

/// Brutalist Button Component
/// Bold, confident button with spring animations and brutalist shadows
class BrutalistButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final BrutalistButtonVariant variant;
  final BrutalistButtonSize size;
  final IconData? icon;
  final bool iconAfter;
  final bool isLoading;
  final bool fullWidth;

  const BrutalistButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = BrutalistButtonVariant.primary,
    this.size = BrutalistButtonSize.medium,
    this.icon,
    this.iconAfter = false,
    this.isLoading = false,
    this.fullWidth = false,
  });

  @override
  State<BrutalistButton> createState() => _BrutalistButtonState();
}

class _BrutalistButtonState extends State<BrutalistButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: PinpointAnimations.buttonPress.duration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: PinpointAnimations.snappy,
      ),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null) {
      setState(() => _isPressed = true);
      _scaleController.forward();
      PinpointHaptics.medium();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _scaleController.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final colorScheme = theme.colorScheme;

    final isDisabled = widget.onPressed == null || widget.isLoading;

    // Get variant styles
    final buttonStyle = _getButtonStyle(context, brightness, colorScheme);

    // Get size dimensions
    final dimensions = _getButtonDimensions();

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: isDisabled ? null : widget.onPressed,
        child: Container(
          height: dimensions.height,
          width: widget.fullWidth ? double.infinity : null,
          padding: dimensions.padding,
          decoration: BoxDecoration(
            color: isDisabled
                ? buttonStyle.backgroundColor.withValues(alpha: 0.5)
                : buttonStyle.backgroundColor,
            border: Border.all(
              color: isDisabled
                  ? buttonStyle.borderColor.withValues(alpha: 0.5)
                  : buttonStyle.borderColor,
              width: buttonStyle.borderWidth,
            ),
            borderRadius: BorderRadius.circular(buttonStyle.borderRadius),
            boxShadow: isDisabled
                ? []
                : (_isPressed ? buttonStyle.pressedShadow : buttonStyle.shadow),
          ),
          child: _buildContent(context, brightness, buttonStyle, isDisabled),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Brightness brightness,
    _ButtonStyle buttonStyle,
    bool isDisabled,
  ) {
    if (widget.isLoading) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(buttonStyle.textColor),
          ),
        ),
      );
    }

    final textStyle = PinpointTypography.button(
      brightness: brightness,
      size: _getButtonSize(),
      color: isDisabled
          ? buttonStyle.textColor.withValues(alpha: 0.5)
          : buttonStyle.textColor,
    );

    final iconWidget = widget.icon != null
        ? Icon(
            widget.icon,
            size: _getIconSize(),
            color: isDisabled
                ? buttonStyle.textColor.withValues(alpha: 0.5)
                : buttonStyle.textColor,
          )
        : null;

    final textWidget = Text(
      widget.text,
      style: textStyle,
      textAlign: TextAlign.center,
    );

    if (iconWidget == null) {
      return Center(child: textWidget);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: widget.iconAfter
          ? [
              textWidget,
              SizedBox(width: PinpointSpacing.sm),
              iconWidget,
            ]
          : [
              iconWidget,
              SizedBox(width: PinpointSpacing.sm),
              textWidget,
            ],
    );
  }

  _ButtonStyle _getButtonStyle(
    BuildContext context,
    Brightness brightness,
    ColorScheme colorScheme,
  ) {
    switch (widget.variant) {
      case BrutalistButtonVariant.primary:
        return _ButtonStyle(
          backgroundColor: colorScheme.primary,
          textColor: colorScheme.onPrimary,
          borderColor: colorScheme.primary,
          borderWidth: PinpointColors.borderMedium,
          borderRadius: 16,
          shadow: PinpointElevations.brutalist(brightness,
              color: colorScheme.primary),
          pressedShadow: PinpointElevations.brutalistInset(brightness),
        );

      case BrutalistButtonVariant.secondary:
        return _ButtonStyle(
          backgroundColor: brightness == Brightness.dark
              ? PinpointColors.darkSurface3
              : PinpointColors.lightSurface3,
          textColor: brightness == Brightness.dark
              ? PinpointColors.darkTextPrimary
              : PinpointColors.lightTextPrimary,
          borderColor: brightness == Brightness.dark
              ? PinpointColors.darkBorderBold
              : PinpointColors.lightBorderBold,
          borderWidth: PinpointColors.borderThick,
          borderRadius: 16,
          shadow: PinpointElevations.brutalist(brightness),
          pressedShadow: PinpointElevations.brutalistInset(brightness),
        );

      case BrutalistButtonVariant.tertiary:
        return _ButtonStyle(
          backgroundColor: Colors.transparent,
          textColor: colorScheme.primary,
          borderColor: colorScheme.primary,
          borderWidth: PinpointColors.borderMedium,
          borderRadius: 16,
          shadow: [],
          pressedShadow: [],
        );

      case BrutalistButtonVariant.ghost:
        return _ButtonStyle(
          backgroundColor: Colors.transparent,
          textColor: brightness == Brightness.dark
              ? PinpointColors.darkTextPrimary
              : PinpointColors.lightTextPrimary,
          borderColor: Colors.transparent,
          borderWidth: 0,
          borderRadius: 16,
          shadow: [],
          pressedShadow: [],
        );

      case BrutalistButtonVariant.danger:
        return _ButtonStyle(
          backgroundColor: PinpointColors.error,
          textColor: Colors.white,
          borderColor: PinpointColors.errorDark,
          borderWidth: PinpointColors.borderMedium,
          borderRadius: 16,
          shadow: PinpointElevations.brutalist(brightness,
              color: PinpointColors.error),
          pressedShadow: PinpointElevations.brutalistInset(brightness),
        );
    }
  }

  _ButtonDimensions _getButtonDimensions() {
    switch (widget.size) {
      case BrutalistButtonSize.small:
        return _ButtonDimensions(
          height: 36,
          padding: EdgeInsets.symmetric(
            horizontal: PinpointSpacing.md,
            vertical: PinpointSpacing.sm,
          ),
        );
      case BrutalistButtonSize.medium:
        return _ButtonDimensions(
          height: 44,
          padding: EdgeInsets.symmetric(
            horizontal: PinpointSpacing.ml,
            vertical: PinpointSpacing.ms,
          ),
        );
      case BrutalistButtonSize.large:
        return _ButtonDimensions(
          height: 52,
          padding: EdgeInsets.symmetric(
            horizontal: PinpointSpacing.lg,
            vertical: PinpointSpacing.md,
          ),
        );
    }
  }

  ButtonSize _getButtonSize() {
    switch (widget.size) {
      case BrutalistButtonSize.small:
        return ButtonSize.small;
      case BrutalistButtonSize.medium:
        return ButtonSize.medium;
      case BrutalistButtonSize.large:
        return ButtonSize.large;
    }
  }

  double _getIconSize() {
    switch (widget.size) {
      case BrutalistButtonSize.small:
        return 16;
      case BrutalistButtonSize.medium:
        return 20;
      case BrutalistButtonSize.large:
        return 24;
    }
  }
}

enum BrutalistButtonVariant {
  primary,
  secondary,
  tertiary,
  ghost,
  danger,
}

enum BrutalistButtonSize {
  small,
  medium,
  large,
}

class _ButtonStyle {
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final List<BoxShadow> shadow;
  final List<BoxShadow> pressedShadow;

  _ButtonStyle({
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
    required this.borderWidth,
    required this.borderRadius,
    required this.shadow,
    required this.pressedShadow,
  });
}

class _ButtonDimensions {
  final double height;
  final EdgeInsets padding;

  _ButtonDimensions({
    required this.height,
    required this.padding,
  });
}
