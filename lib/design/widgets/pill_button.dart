import 'package:flutter/material.dart';
import '../../design/app_theme.dart';

class PillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primaryStyle;

  const PillButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.primaryStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final bg = primaryStyle
        ? AppTheme.primary
        : (dark ? const Color(0xFF12151C) : Colors.white).withOpacity(0.72);
    final fg = primaryStyle
        ? Colors.white
        : (dark ? Colors.white : Colors.black.withOpacity(0.8));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: const StadiumBorder().radius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            border: Border.all(
              color: (dark ? Colors.white : Colors.black).withOpacity(0.06),
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
              Text(label, style: text.labelLarge?.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
