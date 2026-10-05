import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../../../design_system/design_system.dart';

/// One task as the checklist editor shows it.
@immutable
class ChecklistEntry {
  const ChecklistEntry({
    required this.id,
    required this.text,
    required this.done,
  });

  final int id;
  final String text;
  final bool done;
}

/// The body of a checklist note, as slivers: the mint progress card (with
/// three celebration stickers once everything is ticked), the open tasks
/// (long-press to drag; the handle appears while moving), then the done
/// tasks. Swiping a task towards the start deletes it.
///
/// [items] is the display order. The screen applies every change to its list
/// first and persists after, so a toggled task moves group in the same frame
/// (with a short fade-and-rise) and a dismissed one is gone before the
/// database write finishes.
class ChecklistEditorSliver extends StatefulWidget {
  const ChecklistEditorSliver({
    super.key,
    required this.items,
    required this.onToggle,
    required this.onDelete,
    required this.onReorder,
    required this.onEdit,
    this.horizontalPadding = SketchSpace.screenX,
  });

  final List<ChecklistEntry> items;
  final ValueChanged<ChecklistEntry> onToggle;
  final ValueChanged<ChecklistEntry> onDelete;

  /// The open tasks' ids in their new order.
  final ValueChanged<List<int>> onReorder;
  final void Function(ChecklistEntry entry, String text) onEdit;
  final double horizontalPadding;

  @override
  State<ChecklistEditorSliver> createState() => _ChecklistEditorSliverState();
}

class _ChecklistEditorSliverState extends State<ChecklistEditorSliver> {
  /// Tasks that just changed group; they fade and rise into place.
  final Set<int> _moved = {};
  Timer? _movedTimer;

  /// Bumped each time the list becomes all-done, to replay the stickers.
  int _celebration = 0;
  bool _reordering = false;

  bool _allDone(List<ChecklistEntry> items) =>
      items.isNotEmpty && items.every((e) => e.done);

  @override
  void didUpdateWidget(ChecklistEditorSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = {for (final e in oldWidget.items) e.id: e.done};
    final changed = [
      for (final e in widget.items)
        if (before.containsKey(e.id) && before[e.id] != e.done) e.id,
    ];
    if (changed.isNotEmpty) {
      _moved.addAll(changed);
      _movedTimer?.cancel();
      _movedTimer = Timer(const Duration(milliseconds: 450), () {
        if (mounted) setState(_moved.clear);
      });
    }
    if (_allDone(widget.items) && !_allDone(oldWidget.items)) _celebration++;
  }

  @override
  void dispose() {
    _movedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = context.sketch;
    final t = context.type;
    final pad = widget.horizontalPadding;

    final open = [
      for (final e in widget.items)
        if (!e.done) e
    ];
    final done = [
      for (final e in widget.items)
        if (e.done) e
    ];
    final total = widget.items.length;
    final allDone = _allDone(widget.items);

    final header = total == 0
        ? Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 8),
            child: Text(l10n.edChecklistEmpty,
                style: t.bodySmall.copyWith(color: s.muted)),
          )
        : Stack(
            clipBehavior: Clip.none,
            children: [
              ProgressCard(
                done: done.length,
                total: total,
                label: l10n.edChecklistProgress,
                summary: l10n.edChecklistDoneOf(done.length, total),
              ),
              if (allDone)
                PositionedDirectional(
                  top: -20,
                  end: 12,
                  child: Semantics(
                    liveRegion: true,
                    label: l10n.edAllDone,
                    child: _CelebrationStickers(key: ValueKey(_celebration)),
                  ),
                ),
            ],
          );

    Widget row(ChecklistEntry e, {int? index}) {
      Widget child = ChecklistItem(
        text: e.text,
        isChecked: e.done,
        onChanged: (_) => widget.onToggle(e),
        onTextChanged: (text) => widget.onEdit(e, text),
        editHint: l10n.edEditTask,
        dragHandleLabel: l10n.edDragToReorder,
        showDragHandle: _reordering && !e.done,
      );
      child = Dismissible(
        key: ValueKey('dismiss-${e.id}'),
        direction: DismissDirection.endToStart,
        background: const _DeleteBackground(),
        onDismissed: (_) => widget.onDelete(e),
        child: child,
      );
      if (_moved.contains(e.id)) child = _RiseIn(child: child);
      if (index != null) {
        child = ReorderableDelayedDragStartListener(index: index, child: child);
      }
      return Padding(
        key: ValueKey(e.id),
        padding: const EdgeInsets.only(bottom: 10),
        child: child,
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 20, pad, 18),
          sliver: SliverToBoxAdapter(child: header),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          sliver: SliverReorderableList(
            itemCount: open.length,
            itemBuilder: (_, i) => row(open[i], index: i),
            onReorderStart: (_) => setState(() => _reordering = true),
            onReorderEnd: (_) => setState(() => _reordering = false),
            onReorderItem: (oldIndex, newIndex) {
              final ids = [for (final e in open) e.id];
              final moved = ids.removeAt(oldIndex);
              ids.insert(newIndex, moved);
              widget.onReorder(ids);
            },
            proxyDecorator: (child, index, animation) => AnimatedBuilder(
              animation: animation,
              builder: (_, __) {
                final v = Curves.easeOut.transform(animation.value);
                return Transform.rotate(
                  angle: -1.5 * math.pi / 180 * v,
                  child: Transform.scale(
                    scale: 1 + 0.02 * v,
                    child: Material(
                      type: MaterialType.transparency,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ChecklistItem(
                          text: open[index].text,
                          isChecked: false,
                          showDragHandle: true,
                          dragHandleLabel: l10n.edDragToReorder,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          sliver: SliverList.list(
            children: [for (final e in done) row(e)],
          ),
        ),
      ],
    );
  }
}

/// Revealed behind a task being swiped away: a pink pastel row with a bin.
class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SketchPastels.pink,
        borderRadius: BorderRadius.circular(SketchRadius.card),
        border: Border.all(
            color: SketchPastels.onPastel, width: SketchStroke.outline),
      ),
      alignment: AlignmentDirectional.centerEnd,
      padding: const EdgeInsetsDirectional.only(end: 20),
      child: const Icon(Icons.delete_outline_rounded,
          color: SketchPastels.onPastel, size: 22),
    );
  }
}

/// A short fade-and-rise for a task arriving in its new group.
class _RiseIn extends StatelessWidget {
  const _RiseIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: SketchMotion.of(context, SketchMotion.slow),
      curve: SketchMotion.enter,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 8 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

/// Three small stickers that pop in (300ms, staggered) when every task is
/// done. Static under reduced motion.
class _CelebrationStickers extends StatelessWidget {
  const _CelebrationStickers({super.key});

  @override
  Widget build(BuildContext context) {
    final dur = SketchMotion.of(context, const Duration(milliseconds: 420));
    const stickers = [
      (SketchPastels.yellow, Icons.star_rounded, 30.0, -10.0),
      (SketchPastels.lavender, Icons.celebration_rounded, 34.0, 8.0),
      (SketchPastels.pink, Icons.favorite_rounded, 28.0, -6.0),
    ];
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < stickers.length; i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: dur == Duration.zero ? 1 : 0, end: 1),
                duration: dur,
                // 300ms each, 60ms apart.
                curve: Interval(i * 0.14, (i * 0.14 + 0.72).clamp(0.0, 1.0),
                    curve: Curves.easeOutBack),
                builder: (_, v, child) =>
                    Transform.scale(scale: v.clamp(0.0, 1.2), child: child),
                child: StickerTile(
                  color: stickers[i].$1,
                  icon: stickers[i].$2,
                  size: stickers[i].$3,
                  angle: stickers[i].$4,
                  shadowOffset: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
