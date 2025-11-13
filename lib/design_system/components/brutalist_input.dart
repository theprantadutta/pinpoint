import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../animations.dart';
import '../colors.dart';
import '../spacing.dart';
import '../typography.dart';

/// Brutalist Input Component
/// Bold text input with animated borders and smooth focus transitions
class BrutalistInput extends StatefulWidget {
  final TextEditingController? controller;
  final String? hint;
  final String? label;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconTap;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? maxLength;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final BrutalistInputVariant variant;

  const BrutalistInput({
    super.key,
    this.controller,
    this.hint,
    this.label,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    this.inputFormatters,
    this.variant = BrutalistInputVariant.outlined,
  });

  @override
  State<BrutalistInput> createState() => _BrutalistInputState();
}

class _BrutalistInputState extends State<BrutalistInput>
    with SingleTickerProviderStateMixin {
  late AnimationController _focusController;
  late Animation<double> _borderAnimation;
  late Animation<Color?> _borderColorAnimation;
  late FocusNode _internalFocusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = widget.focusNode ?? FocusNode();
    _internalFocusNode.addListener(_handleFocusChange);

    _focusController = AnimationController(
      duration: PinpointAnimations.fast,
      vsync: this,
    );

    _borderAnimation = Tween<double>(
      begin: PinpointColors.borderMedium,
      end: PinpointColors.borderThick,
    ).animate(
      CurvedAnimation(
        parent: _focusController,
        curve: PinpointAnimations.snappy,
      ),
    );
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _internalFocusNode.dispose();
    } else {
      _internalFocusNode.removeListener(_handleFocusChange);
    }
    _focusController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() => _isFocused = _internalFocusNode.hasFocus);
    if (_isFocused) {
      _focusController.forward();
      PinpointHaptics.light();
    } else {
      _focusController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final colorScheme = theme.colorScheme;

    final inputStyle = _getInputStyle(brightness, colorScheme);
    final hasError = widget.errorText != null;

    _borderColorAnimation = ColorTween(
      begin: hasError ? PinpointColors.error : inputStyle.borderColor,
      end: hasError ? PinpointColors.errorLight : colorScheme.primary,
    ).animate(_focusController);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: PinpointTypography.button(
              brightness: brightness,
              size: ButtonSize.small,
            ),
          ),
          SizedBox(height: PinpointSpacing.sm),
        ],
        AnimatedBuilder(
          animation: _focusController,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                color: widget.enabled
                    ? inputStyle.backgroundColor
                    : inputStyle.backgroundColor.withValues(alpha: 0.5),
                border: Border.all(
                  color: _borderColorAnimation.value ?? inputStyle.borderColor,
                  width: widget.variant == BrutalistInputVariant.filled
                      ? 0
                      : _borderAnimation.value,
                ),
                borderRadius: BorderRadius.circular(inputStyle.borderRadius),
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: _internalFocusNode,
                enabled: widget.enabled,
                autofocus: widget.autofocus,
                obscureText: widget.obscureText,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                maxLines: widget.maxLines,
                maxLength: widget.maxLength,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                inputFormatters: widget.inputFormatters,
                style: PinpointTypography.createTextTheme(
                  brightness: brightness,
                ).bodyLarge,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: PinpointTypography.createTextTheme(
                    brightness: brightness,
                  ).bodyLarge?.copyWith(
                        color: brightness == Brightness.dark
                            ? PinpointColors.darkTextTertiary
                            : PinpointColors.lightTextTertiary,
                      ),
                  prefixIcon: widget.prefixIcon != null
                      ? Icon(
                          widget.prefixIcon,
                          color: _isFocused
                              ? colorScheme.primary
                              : (brightness == Brightness.dark
                                  ? PinpointColors.darkTextSecondary
                                  : PinpointColors.lightTextSecondary),
                        )
                      : null,
                  suffixIcon: widget.suffixIcon != null
                      ? IconButton(
                          icon: Icon(
                            widget.suffixIcon,
                            color: _isFocused
                                ? colorScheme.primary
                                : (brightness == Brightness.dark
                                    ? PinpointColors.darkTextSecondary
                                    : PinpointColors.lightTextSecondary),
                          ),
                          onPressed: widget.onSuffixIconTap,
                        )
                      : null,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: PinpointSpacing.md,
                    vertical: PinpointSpacing.ms,
                  ),
                  border: InputBorder.none,
                  counterText: '', // Hide default counter
                ),
              ),
            );
          },
        ),
        if (widget.helperText != null || widget.errorText != null) ...[
          SizedBox(height: PinpointSpacing.xs),
          Text(
            widget.errorText ?? widget.helperText!,
            style: PinpointTypography.metadata(
              brightness: brightness,
            ).copyWith(
              color: widget.errorText != null
                  ? PinpointColors.error
                  : (brightness == Brightness.dark
                      ? PinpointColors.darkTextTertiary
                      : PinpointColors.lightTextTertiary),
            ),
          ),
        ],
      ],
    );
  }

  _InputStyle _getInputStyle(Brightness brightness, ColorScheme colorScheme) {
    switch (widget.variant) {
      case BrutalistInputVariant.outlined:
        return _InputStyle(
          backgroundColor: brightness == Brightness.dark
              ? PinpointColors.darkSurface2
              : PinpointColors.lightSurface1,
          borderColor: brightness == Brightness.dark
              ? PinpointColors.darkBorder
              : PinpointColors.lightBorder,
          borderRadius: 16,
        );

      case BrutalistInputVariant.filled:
        return _InputStyle(
          backgroundColor: brightness == Brightness.dark
              ? PinpointColors.darkSurface3
              : PinpointColors.lightSurface3,
          borderColor: Colors.transparent,
          borderRadius: 16,
        );

      case BrutalistInputVariant.bold:
        return _InputStyle(
          backgroundColor: brightness == Brightness.dark
              ? PinpointColors.darkSurface1
              : PinpointColors.lightSurface1,
          borderColor: brightness == Brightness.dark
              ? PinpointColors.darkBorderBold
              : PinpointColors.lightBorderBold,
          borderRadius: 12, // Sharper corners for bold variant
        );
    }
  }
}

enum BrutalistInputVariant {
  outlined, // Default with border
  filled, // Filled background, no border
  bold, // Bold border with sharper corners
}

class _InputStyle {
  final Color backgroundColor;
  final Color borderColor;
  final double borderRadius;

  _InputStyle({
    required this.backgroundColor,
    required this.borderColor,
    required this.borderRadius,
  });
}
