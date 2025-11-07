import 'dart:ui';
import 'package:flutter/material.dart';
import '../gradients.dart';
import '../animations.dart';

/// ConfirmSheet - Bottom sheet with gradient header for confirmations
///
/// Features:
/// - Gradient header
/// - Primary and secondary actions
/// - Optional destructive style
/// - Entrance animation
class ConfirmSheet extends StatelessWidget {
  final String title;
  final String? message;
  final String? primaryLabel;
  final String? secondaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;
  final bool isDestructive;
  final IconData? icon;
  final Gradient? headerGradient;

  const ConfirmSheet({
    super.key,
    required this.title,
    this.message,
    this.primaryLabel,
    this.secondaryLabel,
    this.onPrimary,
    this.onSecondary,
    this.isDestructive = false,
    this.icon,
    this.headerGradient,
  });

  /// Show confirm sheet as bottom sheet
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    String? message,
    String? primaryLabel,
    String? secondaryLabel,
    bool isDestructive = false,
    IconData? icon,
    Gradient? headerGradient,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ConfirmSheet(
        title: title,
        message: message,
        primaryLabel: primaryLabel,
        secondaryLabel: secondaryLabel,
        isDestructive: isDestructive,
        icon: icon,
        headerGradient: headerGradient,
        onPrimary: () => Navigator.of(context).pop(true),
        onSecondary: () => Navigator.of(context).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final motionSettings = MotionSettings.fromMediaQuery(context);

    final gradient = headerGradient ??
        (isDestructive
            ? PinpointGradients.solarRose
            : theme.brightness == Brightness.dark
                ? PinpointGradients.crescentInk
                : PinpointGradients.oceanQuartz);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Gradient header
          Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Stack(
              children: [
                // Blur effect
                if (!motionSettings.reduceMotion)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(28)),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          color: Colors.transparent,
                        ),
                      ),
                    ),
                  ),

                // Icon
                Center(
                  child: Icon(
                    icon ??
                        (isDestructive
                            ? Icons.warning_rounded
                            : Icons.info_rounded),
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                Text(
                  title,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),

                // Message
                if (message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    message!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 24),

                // Actions
                Row(
                  children: [
                    // Secondary button
                    if (onSecondary != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            PinpointHaptics.light();
                            onSecondary!();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(secondaryLabel ?? 'Cancel'),
                        ),
                      ),

                    if (onSecondary != null && onPrimary != null)
                      const SizedBox(width: 12),

                    // Primary button
                    if (onPrimary != null)
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            PinpointHaptics.medium();
                            onPrimary!();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: isDestructive
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                            foregroundColor: isDestructive
                                ? theme.colorScheme.onError
                                : theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            primaryLabel ??
                                (isDestructive ? 'Delete' : 'Confirm'),
                          ),
                        ),
                      ),
                  ],
                ),

                // Safe area padding
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
