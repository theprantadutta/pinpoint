import 'package:flutter/material.dart';

import '../colors.dart';

/// Horizontal row of Keep-style color swatches. Returns the chosen swatch name
/// (or 'default') via [onSelected]. Used in the editor and selection mode.
class NoteColorPicker extends StatelessWidget {
  /// Currently selected swatch name (null/'default' = no color).
  final String? selected;
  final ValueChanged<String> onSelected;

  const NoteColorPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final current = selected ?? 'default';

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: NoteSwatch.all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final swatch = NoteSwatch.all[i];
          final isDefault = swatch.name == 'default';
          final isSelected = swatch.name == current;
          final color =
              brightness == Brightness.dark ? swatch.dark : swatch.light;

          return _SwatchDot(
            color: color,
            isDefault: isDefault,
            isSelected: isSelected,
            label: swatch.label,
            onTap: () => onSelected(swatch.name),
          );
        },
      ),
    );
  }
}

class _SwatchDot extends StatelessWidget {
  final Color color;
  final bool isDefault;
  final bool isSelected;
  final String label;
  final VoidCallback onTap;

  const _SwatchDot({
    required this.color,
    required this.isDefault,
    required this.isSelected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label color${isSelected ? ', selected' : ''}',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? cs.primary
                  : cs.onSurface.withValues(alpha: 0.2),
              width: isSelected ? 2.5 : 1,
            ),
          ),
          child: isDefault
              ? Icon(Icons.format_color_reset_outlined,
                  size: 20, color: cs.onSurfaceVariant)
              : (isSelected
                  ? Icon(Icons.check, size: 20, color: cs.primary)
                  : null),
        ),
      ),
    );
  }
}

/// Shows the color picker as a bottom sheet and returns the chosen swatch name,
/// or null if dismissed.
Future<String?> showNoteColorPicker(
  BuildContext context, {
  String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Color',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              NoteColorPicker(
                selected: selected,
                onSelected: (name) => Navigator.of(sheetContext).pop(name),
              ),
            ],
          ),
        ),
      );
    },
  );
}
