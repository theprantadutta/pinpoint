import 'package:flutter/material.dart';
import '../../design/app_theme.dart';

class PillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primaryStyle;
  final bool destructive;

  const PillButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.primaryStyle = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final Color bg = switch ((primaryStyle, destructive, dark)) {
      (true, _, _) => AppTheme.primary,
      (false, true, _) => AppTheme.danger.withValues(alpha: dark ? 0.24 : 0.14),
      (false, false, true) => const Color(0xFF12151C).withValues(alpha: 0.78),
      _ => Colors.white.withValues(alpha: 0.78),
    };

    final Color fg = switch ((primaryStyle, destructive, dark)) {
      (true, _, _) => Colors.white,
      (false, true, _) => AppTheme.danger,
      (false, false, true) => Colors.white,
      _ => Colors.black.withValues(alpha: 0.84),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        splashColor: AppTheme.primary.withValues(alpha: 0.12),
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            border: Border.all(
              color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.06),
            ),
            boxShadow: AppTheme.shadowSoft(dark),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: text.labelLarge?.copyWith(
                  color: fg,
                  letterSpacing: 0.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
