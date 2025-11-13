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
    // final motionSettings = MotionSettings.fromMediaQuery(context);

    final gradient = widget.gradientHalo ??
        (theme.brightness == Brightness.dark
            ? PinpointGradients.neonMint
            : PinpointGradients.oceanQuartz);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Scale down for small spaces
              final isCompact = constraints.maxHeight < 250;
              final iconSize = isCompact ? 60.0 : 120.0;
              final iconContentSize = isCompact ? 32.0 : 64.0;
              final padding = isCompact ? 16.0 : 24.0;
              final spacing = isCompact ? 12.0 : 24.0;

              return SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon with gradient halo
                      Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: BoxDecoration(
                          gradient: gradient,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            widget.icon,
                            size: iconContentSize,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ),

                      SizedBox(height: spacing),

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
                        SizedBox(height: isCompact ? 8 : 12),
                        Text(
                          widget.message!,
                          style: PinpointTypography.emptyState(
                            brightness: theme.brightness,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      // Action button
                      if (widget.actionLabel != null &&
                          widget.onAction != null) ...[
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () {
                            PinpointHaptics.medium();
                            widget.onAction!();
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: Text(widget.actionLabel!),
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
