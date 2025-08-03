import 'package:flutter/material.dart';

class TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const TagChip({super.key, required this.label, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: const StadiumBorder().radius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: ShapeDecoration(
          shape: const StadiumBorder(
            side: BorderSide(width: 0.8, color: Colors.transparent),
          ),
          color: selected
              ? theme.colorScheme.primary.withOpacity(0.12)
              : theme.chipTheme.backgroundColor,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: selected ? theme.colorScheme.primary : null,
          ),
        ),
      ),
    );
  }
}
