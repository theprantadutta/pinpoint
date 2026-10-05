import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../../design_system/design_system.dart';
import '../../services/crash_breadcrumbs.dart';
import '../../widgets/pinpoint_popup_menu_button.dart';

/// One row of the editor's "⋯" menu.
@immutable
class EditorMenuEntry {
  const EditorMenuEntry({
    required this.value,
    required this.icon,
    required this.label,
    this.enabled = true,
    this.destructive = false,
    this.badge,
    this.dividerBefore = false,
  });

  final String value;
  final IconData icon;
  final String label;
  final bool enabled;

  /// Error-coloured (Delete).
  final bool destructive;

  /// A small tag after the label ("SOON").
  final String? badge;
  final bool dividerBefore;
}

/// The editor's "⋯" button: a [CircleIconButton] opening the crash-safe
/// [PinpointPopupMenuButton] with Sketchbook rows (surface, outline r18 from
/// the theme; 15/600 labels; ink icons).
class EditorOverflowMenu extends StatelessWidget {
  const EditorOverflowMenu({
    super.key,
    required this.entries,
    required this.onSelected,
  });

  /// Built per open so quota labels ("Export PDF (5/10)") are current.
  final List<EditorMenuEntry> Function() entries;
  final ValueChanged<String> onSelected;

  static const String breadcrumb = 'editor.overflow';

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return PinpointPopupMenuButton<String>(
      offset: const Offset(0, 48),
      onOpened: () => CrashBreadcrumbs.popupMenuOpened(breadcrumb),
      onCanceled: () => CrashBreadcrumbs.popupMenuClosed(breadcrumb),
      onSelected: (value) {
        CrashBreadcrumbs.popupMenuClosed(breadcrumb, selected: value);
        onSelected(value);
      },
      builder: (context, open) => CircleIconButton(
        icon: Icons.more_horiz_rounded,
        iconSize: 22,
        semanticLabel: l10n.edMoreOptions,
        onPressed: open,
      ),
      itemBuilder: (context) {
        final s = context.sketch;
        final t = context.type;
        final items = <PopupMenuEntry<String>>[];
        for (final e in entries()) {
          if (e.dividerBefore && items.isNotEmpty) {
            items.add(PopupMenuDivider(height: 9, color: s.hairline));
          }
          final fg = !e.enabled
              ? s.muted
              : e.destructive
                  ? SketchFunctional.error
                  : s.ink;
          items.add(PopupMenuItem<String>(
            value: e.enabled ? e.value : null,
            enabled: e.enabled,
            height: 48,
            child: Row(
              children: [
                Icon(e.icon, size: 20, color: fg),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(e.label, style: t.body.copyWith(color: fg)),
                ),
                if (e.badge != null) ...[
                  const SizedBox(width: 8),
                  SketchTag(label: e.badge!, textColor: s.muted),
                ],
              ],
            ),
          ));
        }
        return items;
      },
    );
  }
}
