import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../animations.dart';
import '../../colors.dart';
import '../../elevations.dart';
import '../../spacing.dart';
import 'sketch_pressable.dart';

/// One slot in the [SketchDock].
class SketchDockItem {
  const SketchDockItem({
    required this.icon,
    required this.label,
    this.activeIcon,
  });

  final IconData icon;
  final IconData? activeIcon;

  /// Semantics label (the dock shows no text).
  final String label;
}

/// The floating inverse pill dock: 300×62, radius 31, bottom 26.
///
/// Four destinations around a centre Create button. The active destination
/// shows a 4px dot beneath it; the others sit at 60% opacity. Create opens
/// the editor on tap; [onCreateLongPress] opens the note-type chooser.
class SketchDock extends StatelessWidget {
  const SketchDock({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    required this.onCreate,
    required this.createLabel,
    this.onCreateLongPress,
  }) : assert(items.length == 4, 'Two slots each side of Create');

  final List<SketchDockItem> items;

  /// Index into [items], or -1 when no destination is active.
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;
  final VoidCallback? onCreateLongPress;
  final String createLabel;

  static const double width = 300;
  static const double height = 62;

  /// Total vertical space the dock occupies from the bottom edge, including
  /// the system inset. Scroll views pad by [SketchSpace.dockClearance].
  static double footprint(BuildContext context) =>
      height + SketchSpace.dockBottom + MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;

    Widget slot(int i) => _DockSlot(
          item: items[i],
          active: i == currentIndex,
          onTap: () => onSelect(i),
        );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: s.inverse,
          borderRadius: BorderRadius.circular(SketchRadius.dock),
          boxShadow: SketchShadows.dock,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            slot(0),
            slot(1),
            _CreateButton(
              label: createLabel,
              onTap: onCreate,
              onLongPress: onCreateLongPress,
            ),
            slot(2),
            slot(3),
          ],
        ),
      ),
    );
  }
}

class _DockSlot extends StatelessWidget {
  const _DockSlot({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final SketchDockItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final dur = SketchMotion.of(context, SketchMotion.base);
    return SketchPressable(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      semanticLabel: item.label,
      selected: active,
      child: SizedBox(
        width: 48,
        height: 48,
        child: AnimatedOpacity(
          opacity: active ? 1 : 0.6,
          duration: dur,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                active ? (item.activeIcon ?? item.icon) : item.icon,
                color: s.onInverse,
                size: 22,
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: dur,
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? s.onInverse : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({
    required this.label,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    return SketchPressable(
      onTap: onTap,
      onLongPress: onLongPress,
      haptic: true,
      semanticLabel: label,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: s.bg,
          shape: BoxShape.circle,
          // Inset 2px inverse ring, then a 2px on-inverse outer ring.
          border: Border.all(color: s.onInverse, width: 2),
        ),
        child: Container(
          margin: const EdgeInsets.all(0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: s.inverse, width: 2),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.edit_rounded, color: s.ink, size: 22),
        ),
      ),
    );
  }
}
