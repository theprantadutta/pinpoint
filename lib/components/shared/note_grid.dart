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
    this.padding = const EdgeInsets.symmetric(horizontal: SketchSpace.screenX),
  });

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
          final columns = c.crossAxisExtent >= 560 ? 3 : 2;
          return SliverMasonryGrid.count(
            crossAxisCount: columns,
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
        focusedBorder: border.copyWith(
            borderSide: BorderSide(color: s.ink, width: 2)),
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
