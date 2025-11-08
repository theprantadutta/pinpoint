import 'package:flutter/material.dart';
import '../gradients.dart';
import '../typography.dart';
import '../animations.dart';

/// EmptyState - Friendly empty state with illustration
///
/// Features:
/// - Icon with gradient halo
/// - Title and message
/// - Optional action button
/// - Entrance animation
class EmptyState extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Gradient? gradientHalo;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.gradientHalo,
  });

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: PinpointAnimations.medium,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: PinpointAnimations.emphasizedDecelerate,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: PinpointAnimations.emphasized,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final motionSettings = MotionSettings.fromMediaQuery(context);

    final gradient = widget.gradientHalo ??
        (theme.brightness == Brightness.dark
            ? PinpointGradients.neonMint
            : PinpointGradients.oceanQuartz);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon with gradient halo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      widget.icon,
                      size: 64,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Title
                Text(
                  widget.title,
                  style: PinpointTypography.emptyState(
                    brightness: theme.brightness,
                    isTitle: true,
                  ),
                  textAlign: TextAlign.center,
                ),

                // Message
                if (widget.message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.message!,
                    style: PinpointTypography.emptyState(
                      brightness: theme.brightness,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                // Action button
                if (widget.actionLabel != null && widget.onAction != null) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      PinpointHaptics.medium();
                      widget.onAction!();
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: Text(widget.actionLabel!),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
