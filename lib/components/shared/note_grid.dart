import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../../design_system/design_system.dart';
import '../../models/note_with_details.dart';
import '../../widgets/filter_bottom_sheet.dart';
import '../home_screen/home_screen_recent_notes.dart';

/// The Sketchbook notes masonry as a sliver — the home grid's layout for the
/// other note lists (all notes, a folder, archive, trash).
///
/// Two columns on phones, three once the (width-capped) content reaches
/// 560, gap 12, 20px side padding. Each note is a [NoteListItem] unless
/// [itemBuilder] says otherwise.
class NoteGridSliver extends StatelessWidget {
  const NoteGridSliver({
    super.key,
    required this.notes,
    this.itemBuilder,
    this.columns,
    this.padding = const EdgeInsets.symmetric(horizontal: SketchSpace.screenX),
  });

  /// Fixed column count (1 = the list view); null picks 2 or 3 by width.
  final int? columns;

  final List<NoteWithDetails> notes;
  final Widget Function(BuildContext context, NoteWithDetails note)?
      itemBuilder;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverLayoutBuilder(
        builder: (context, c) {
          final count = columns ?? (c.crossAxisExtent >= 560 ? 3 : 2);
          return SliverMasonryGrid.count(
            crossAxisCount: count,
            mainAxisSpacing: SketchSpace.grid,
            crossAxisSpacing: SketchSpace.grid,
            childCount: notes.length,
            itemBuilder: (context, i) {
              final note = notes[i];
              return KeyedSubtree(
                key: ValueKey('${note.note.noteType}-${note.note.id}'),
                child: itemBuilder?.call(context, note) ??
                    NoteListItem(note: note),
              );
            },
          );
        },
      ),
    );
  }
}

/// Bottom padding for a list that scrolls behind the floating dock.
double dockAwareBottomPadding(BuildContext context) =>
    SketchSpace.dockClearance + MediaQuery.paddingOf(context).bottom;

/// The search field the list screens reveal from their search button: an
/// outlined stadium with a leading search icon and a clear button.
class SketchSearchField extends StatelessWidget {
  const SketchSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.autofocus = true,
    this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(SketchRadius.dock),
      borderSide: BorderSide(color: s.outline, width: SketchStroke.outline),
    );
    return TextField(
      controller: controller,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      style: t.bodyRegular.copyWith(color: s.ink),
      cursorColor: s.ink,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: s.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        prefixIcon: Icon(Icons.search_rounded, color: s.muted, size: 20),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, v, _) => v.text.isEmpty
              ? const SizedBox.shrink()
              : SketchPressable(
                  semanticLabel:
                      MaterialLocalizations.of(context).deleteButtonTooltip,
                  onTap: () {
                    controller.clear();
                    onClear?.call();
                  },
                  child: SizedBox(
                    width: SketchSpace.minTap,
                    height: SketchSpace.minTap,
                    child: Icon(Icons.close_rounded, color: s.muted, size: 20),
                  ),
                ),
        ),
        enabledBorder: border,
        border: border,
        focusedBorder:
            border.copyWith(borderSide: BorderSide(color: s.ink, width: 2)),
      ),
    );
  }
}

/// A circle filter button with the active-filter count as a small inverse
/// badge. Opens the Filters sheet.
class NoteFilterButton extends StatelessWidget {
  const NoteFilterButton({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = context.sketch;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleIconButton(
          icon: Icons.tune_rounded,
          fill: count > 0 ? s.highlight : null,
          semanticLabel:
              count > 0 ? '${l10n.notesFilters}, $count' : l10n.notesFilters,
          onPressed: () => FilterBottomSheet.show(context),
        ),
        if (count > 0)
          PositionedDirectional(
            top: 0,
            end: 0,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: SketchTag(label: '$count', inverse: true, dense: true),
              ),
            ),
          ),
      ],
    );
  }
}

/// One small action under a managed note (restore, delete forever…).
class NoteAction {
  const NoteAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;

  /// Screen-reader label.
  final String label;
  final Future<void> Function() onTap;
  final bool destructive;
}

/// An archive / trash grid item: the note card dimmed to 70%, then a row
/// with an optional muted [caption] and small circle [actions]. Actions
/// show a spinner and ignore taps while one is running.
class ManagedNoteItem extends StatefulWidget {
  const ManagedNoteItem({
    super.key,
    required this.note,
    required this.actions,
    this.caption,
    this.isTrashView = false,
  });

  final NoteWithDetails note;
  final List<NoteAction> actions;
  final String? caption;
  final bool isTrashView;

  @override
  State<ManagedNoteItem> createState() => _ManagedNoteItemState();
}

class _ManagedNoteItemState extends State<ManagedNoteItem> {
  bool _busy = false;

  Future<void> _run(NoteAction a) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await a.onTap();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NoteListItem(
          note: widget.note,
          isArchivedView: !widget.isTrashView,
          isTrashView: widget.isTrashView,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: widget.caption == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsetsDirectional.only(start: 4),
                      child: Text(
                        widget.caption!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.caption,
                      ),
                    ),
            ),
            if (_busy)
              SizedBox(
                width: SketchSpace.minTap,
                height: SketchSpace.minTap,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(strokeWidth: 2, color: s.ink),
                  ),
                ),
              )
            else
              for (final a in widget.actions)
                CircleIconButton(
                  icon: a.icon,
                  size: 34,
                  iconSize: 18,
                  iconColor: a.destructive ? SketchFunctional.error : null,
                  semanticLabel: a.label,
                  onPressed: () => _run(a),
                ),
          ],
        ),
      ],
    );
  }
}
