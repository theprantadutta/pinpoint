import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

/// Custom tooltip widget for walkthrough coach marks.
/// Provides a beautiful, theme-aware tooltip with icon, title, description, and next button.
class WalkthroughTooltip extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onNext;
  final bool showNextButton;
  /// Null means "use the default label", resolved at build time — a default
  /// parameter value cannot read Localizations.
  final String? nextButtonText;

  const WalkthroughTooltip({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.onNext,
    this.showNextButton = true,
    this.nextButtonText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Always the theme accent. There is deliberately no override parameter:
    // the accent is user-selectable, and the one caller that used to pass a
    // fixed colour is why the first coach mark stayed mint after the app moved
    // to the indigo-blue accent.
    final color = theme.colorScheme.primary;

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon and Title Row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),

          // Next Button
          if (showNextButton) ...[
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: onNext,
                style: TextButton.styleFrom(
                  backgroundColor: color.withValues(alpha: 0.15),
                  foregroundColor: color,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nextButtonText ?? AppL10n.of(context).commonNext,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
