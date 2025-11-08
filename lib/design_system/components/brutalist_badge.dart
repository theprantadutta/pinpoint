import 'package:flutter/material.dart';
import '../colors.dart';
import '../elevations.dart';
import '../spacing.dart';
import '../typography.dart';

/// Brutalist Badge Component
/// Sharp, bold badge/chip for labels, tags, and status indicators
class BrutalistBadge extends StatelessWidget {
  final String text;
  final BrutalistBadgeVariant variant;
  final BrutalistBadgeSize size;
  final IconData? icon;
  final bool iconAfter;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Color? customColor;

  const BrutalistBadge({
    super.key,
    required this.text,
    this.variant = BrutalistBadgeVariant.filled,
    this.size = BrutalistBadgeSize.medium,
    this.icon,
    this.iconAfter = false,
    this.onTap,
    this.onDelete,
    this.customColor,
  });

  /// Primary accent badge
  factory BrutalistBadge.primary(
    String text, {
    BrutalistBadgeSize size = BrutalistBadgeSize.medium,
    IconData? icon,
    VoidCallback? onTap,
  }) {
    return BrutalistBadge(
      text: text,
      variant: BrutalistBadgeVariant.primary,
      size: size,
      icon: icon,
      onTap: onTap,
    );
  }

  /// Success/positive badge
  factory BrutalistBadge.success(
    String text, {
    BrutalistBadgeSize size = BrutalistBadgeSize.medium,
    IconData? icon,
  }) {
    return BrutalistBadge(
      text: text,
      variant: BrutalistBadgeVariant.success,
      size: size,
      icon: icon,
    );
  }

  /// Error/danger badge
  factory BrutalistBadge.error(
    String text, {
    BrutalistBadgeSize size = BrutalistBadgeSize.medium,
    IconData? icon,
  }) {
    return BrutalistBadge(
      text: text,
      variant: BrutalistBadgeVariant.error,
      size: size,
      icon: icon,
    );
  }

  /// Warning badge
  factory BrutalistBadge.warning(
    String text, {
    BrutalistBadgeSize size = BrutalistBadgeSize.medium,
    IconData? icon,
  }) {
    return BrutalistBadge(
      text: text,
      variant: BrutalistBadgeVariant.warning,
      size: size,
      icon: icon,
    );
  }

  /// Info badge
  factory BrutalistBadge.info(
    String text, {
    BrutalistBadgeSize size = BrutalistBadgeSize.medium,
    IconData? icon,
  }) {
    return BrutalistBadge(
      text: text,
      variant: BrutalistBadgeVariant.info,
      size: size,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final colorScheme = theme.colorScheme;

    final badgeStyle = _getBadgeStyle(brightness, colorScheme);
    final dimensions = _getBadgeDimensions();

    final isInteractive = onTap != null;

    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          PinpointHaptics.light();
          onTap!();
        }
      },
      child: Container(
        height: dimensions.height,
        padding: dimensions.padding,
        decoration: BoxDecoration(
          color: badgeStyle.backgroundColor,
          border: badgeStyle.borderWidth > 0
              ? Border.all(
                  color: badgeStyle.borderColor,
                  width: badgeStyle.borderWidth,
                )
              : null,
          borderRadius: BorderRadius.circular(badgeStyle.borderRadius),
          boxShadow: isInteractive
              ? PinpointElevations.brutalist(brightness, offsetX: 2, offsetY: 2)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null && !iconAfter) ...[
              Icon(
                icon,
                size: dimensions.iconSize,
                color: badgeStyle.textColor,
              ),
              SizedBox(width: PinpointSpacing.xs),
            ],
            Text(
              text,
              style: PinpointTypography.tagChip(
                brightness: brightness,
                color: badgeStyle.textColor,
              ).copyWith(
                fontSize: dimensions.fontSize,
                fontWeight: FontWeight.w700, // BOLD
              ),
            ),
            if (icon != null && iconAfter) ...[
              SizedBox(width: PinpointSpacing.xs),
              Icon(
                icon,
                size: dimensions.iconSize,
                color: badgeStyle.textColor,
              ),
            ],
            if (onDelete != null) ...[
              SizedBox(width: PinpointSpacing.xs),
              GestureDetector(
                onTap: () {
                  PinpointHaptics.light();
                  onDelete!();
                },
                child: Icon(
                  Icons.close,
                  size: dimensions.iconSize,
                  color: badgeStyle.textColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _BadgeStyle _getBadgeStyle(Brightness brightness, ColorScheme colorScheme) {
    if (customColor != null) {
      return _BadgeStyle(
        backgroundColor: customColor!.withValues(alpha: 0.15),
        borderColor: customColor!,
        borderWidth: variant == BrutalistBadgeVariant.outlined
            ? PinpointColors.borderMedium
            : 0,
        textColor: customColor!,
        borderRadius: variant == BrutalistBadgeVariant.sharp ? 8 : 999,
      );
    }

    switch (variant) {
      case BrutalistBadgeVariant.filled:
        return _BadgeStyle(
          backgroundColor: brightness == Brightness.dark
              ? PinpointColors.darkSurface3
              : PinpointColors.lightSurface3,
          borderColor: brightness == Brightness.dark
              ? PinpointColors.darkBorder
              : PinpointColors.lightBorder,
          borderWidth: 0,
          textColor: brightness == Brightness.dark
              ? PinpointColors.darkTextPrimary
              : PinpointColors.lightTextPrimary,
          borderRadius: 999,
        );

      case BrutalistBadgeVariant.outlined:
        return _BadgeStyle(
          backgroundColor: Colors.transparent,
          borderColor: brightness == Brightness.dark
              ? PinpointColors.darkBorder
              : PinpointColors.lightBorder,
          borderWidth: PinpointColors.borderMedium,
          textColor: brightness == Brightness.dark
              ? PinpointColors.darkTextPrimary
              : PinpointColors.lightTextPrimary,
          borderRadius: 999,
        );

      case BrutalistBadgeVariant.sharp:
        return _BadgeStyle(
          backgroundColor: brightness == Brightness.dark
              ? PinpointColors.darkSurface3
              : PinpointColors.lightSurface3,
          borderColor: brightness == Brightness.dark
              ? PinpointColors.darkBorderBold
              : PinpointColors.lightBorderBold,
          borderWidth: PinpointColors.borderMedium,
          textColor: brightness == Brightness.dark
              ? PinpointColors.darkTextPrimary
              : PinpointColors.lightTextPrimary,
          borderRadius: 8,
        );

      case BrutalistBadgeVariant.primary:
        return _BadgeStyle(
          backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
          borderColor: colorScheme.primary,
          borderWidth: 0,
          textColor: colorScheme.primary,
          borderRadius: 999,
        );

      case BrutalistBadgeVariant.success:
        return _BadgeStyle(
          backgroundColor: PinpointColors.successBackground,
          borderColor: PinpointColors.success,
          borderWidth: 0,
          textColor: PinpointColors.success,
          borderRadius: 999,
        );

      case BrutalistBadgeVariant.error:
        return _BadgeStyle(
          backgroundColor: PinpointColors.errorBackground,
          borderColor: PinpointColors.error,
          borderWidth: 0,
          textColor: PinpointColors.error,
          borderRadius: 999,
        );

      case BrutalistBadgeVariant.warning:
        return _BadgeStyle(
          backgroundColor: PinpointColors.warningBackground,
          borderColor: PinpointColors.warning,
          borderWidth: 0,
          textColor: PinpointColors.warning,
          borderRadius: 999,
        );

      case BrutalistBadgeVariant.info:
        return _BadgeStyle(
          backgroundColor: PinpointColors.infoBackground,
          borderColor: PinpointColors.info,
          borderWidth: 0,
          textColor: PinpointColors.info,
          borderRadius: 999,
        );
    }
  }

  _BadgeDimensions _getBadgeDimensions() {
    switch (size) {
      case BrutalistBadgeSize.small:
        return _BadgeDimensions(
          height: 24,
          padding: EdgeInsets.symmetric(
            horizontal: PinpointSpacing.sm,
            vertical: PinpointSpacing.xxs,
          ),
          fontSize: 11,
          iconSize: 14,
        );
      case BrutalistBadgeSize.medium:
        return _BadgeDimensions(
          height: 28,
          padding: EdgeInsets.symmetric(
            horizontal: PinpointSpacing.ms,
            vertical: PinpointSpacing.xs,
          ),
          fontSize: 12,
          iconSize: 16,
        );
      case BrutalistBadgeSize.large:
        return _BadgeDimensions(
          height: 32,
          padding: EdgeInsets.symmetric(
            horizontal: PinpointSpacing.md,
            vertical: PinpointSpacing.sm,
          ),
          fontSize: 14,
          iconSize: 18,
        );
    }
  }
}

enum BrutalistBadgeVariant {
  filled, // Filled background
  outlined, // Outline only
  sharp, // Sharp corners, brutalist style
  primary, // Primary color
  success, // Success/positive
  error, // Error/danger
  warning, // Warning
  info, // Info
}

enum BrutalistBadgeSize {
  small,
  medium,
  large,
}

class _BadgeStyle {
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final Color textColor;
  final double borderRadius;

  _BadgeStyle({
    required this.backgroundColor,
    required this.borderColor,
    required this.borderWidth,
    required this.textColor,
    required this.borderRadius,
  });
}

class _BadgeDimensions {
  final double height;
  final EdgeInsets padding;
  final double fontSize;
  final double iconSize;

  _BadgeDimensions({
    required this.height,
    required this.padding,
    required this.fontSize,
    required this.iconSize,
  });
}
