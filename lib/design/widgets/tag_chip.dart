import 'package:flutter/material.dart';
import 'package:pinpoint/design/app_theme.dart';

class TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  const TagChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    final bg = selected
        ? cs.primary.withValues(alpha: 0.12)
        : (dark ? const Color(0xFF1A1F28) : Colors.white).withAlpha(200);

    final fg = selected
        ? cs.primary
        : (dark ? Colors.white : Colors.black.withValues(alpha: 0.84));

    return Container(
      margin: const EdgeInsets.all(2),
      child: Glass(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        borderRadius: AppTheme.radiusL,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppTheme.radiusL,
            splashColor: cs.primary.withValues(alpha: 0.10),
            highlightColor: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: AppTheme.radiusL,
                border: Border.all(
                  color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: fg),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}