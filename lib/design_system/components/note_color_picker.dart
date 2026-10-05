import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../animations.dart';
import '../colors.dart';
import '../spacing.dart';
import '../typography.dart';
import 'sketch/sketch_pressable.dart';
import 'sketch/sketch_sheet.dart';

/// The note colours as swatches: "no colour" plus the five pastels
/// ([NoteSwatch.all]). Returns the chosen swatch name (or 'default') via
/// [onSelected]. Used by the editor's colour dot and its ⋯ menu.
class NoteColorPicker extends StatelessWidget {
  /// Currently selected swatch name (null/'default' = no colour). Legacy Keep
  /// names resolve to their nearest pastel.
  final String? selected;
  final ValueChanged<String> onSelected;

  const NoteColorPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  /// The localized name of a swatch.
  static String labelFor(BuildContext context, NoteSwatch swatch) {
    final l10n = AppL10n.of(context);
    return switch (swatch.name) {
      'yellow' => l10n.edColorYellow,
      'lavender' => l10n.edColorLavender,
      'mint' => l10n.edColorMint,
      'sky' => l10n.edColorSky,
      'pink' => l10n.edColorPink,
      _ => l10n.edColorDefault,
    };
  }

  @override
  Widget build(BuildContext context) {
    final current = NoteSwatch.selectedFor(selected).name;

    return Wrap(
      spacing: 6,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        for (final swatch in NoteSwatch.all)
          _Swatch(
            swatch: swatch,
            label: labelFor(context, swatch),
            selected: swatch.name == current,
            onTap: () => onSelected(swatch.name),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.swatch,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final NoteSwatch swatch;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final isDefault = swatch.color == null;
    final fill = swatch.color ?? s.surface;
    // A pastel always carries an ink outline; "no colour" follows the theme.
    final stroke = isDefault ? s.outline : SketchPastels.onPastel;
    final mark = isDefault ? s.ink : SketchPastels.onPastel;

    return SketchPressable(
      onTap: onTap,
      semanticLabel: label,
      selected: selected,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: SketchMotion.of(context, SketchMotion.base),
              curve: SketchMotion.enter,
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? s.ink : Colors.transparent,
                  width: SketchStroke.checkbox,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: stroke, width: SketchStroke.outline),
                ),
                alignment: Alignment.center,
                child: selected
                    ? Icon(Icons.check_rounded, size: 20, color: mark)
                    : isDefault
                        ? Icon(Icons.format_color_reset_outlined,
                            size: 18, color: s.muted)
                        : null,
              ),
            ),
            const SizedBox(height: 6),
            ExcludeSemantics(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: t.caption.copyWith(
                  fontSize: 11,
                  color: selected ? s.ink : s.muted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the colour picker as a Sketchbook sheet and returns the chosen
/// swatch name ('default' for no colour), or null if dismissed.
Future<String?> showNoteColorPicker(
  BuildContext context, {
  String? selected,
}) {
  return showSketchSheet<String>(
    context: context,
    builder: (sheetContext) => SketchSheet(
      title: AppL10n.of(sheetContext).colorPickerTitle,
      scrollable: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: SketchSpace.titleToContent),
        child: NoteColorPicker(
          selected: selected,
          onSelected: (name) => Navigator.of(sheetContext).pop(name),
        ),
      ),
    ),
  );
}
