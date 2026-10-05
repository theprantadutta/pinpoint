import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../design_system/design_system.dart';
import '../models/filter_options.dart';
import '../models/folder_summary.dart';
import '../models/note_with_details.dart';
import '../services/drift_note_folder_service.dart';
import '../services/drift_note_service.dart';
import '../services/filter_service.dart';
import '../util/folder_palette.dart';
import '../util/note_query.dart';

/// The Sketchbook Filters sheet: sort, note type, folders, pinned-only and
/// include-archived, with a live "Show N notes" button.
///
/// Edits a draft; nothing changes until the button is tapped, so dismissing
/// the sheet discards the edits. Reset clears the draft (and sort).
class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key});

  static Future<void> show(BuildContext context) => showSketchSheet<void>(
        context: context,
        builder: (_) => const FilterBottomSheet(),
      );

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late FilterOptions _draft;
  late NoteSort _sort;

  /// Every live note plus archived ones, for the live count.
  late final Stream<List<NoteWithDetails>> _notes =
      DriftNoteService.watchNotesWithDetailsV2(includeArchived: true);
  late final Stream<List<FolderSummary>> _folders =
      DriftNoteFolderService.watchFolderSummaries();

  @override
  void initState() {
    super.initState();
    final service = context.read<FilterService>();
    _draft = service.filterOptions;
    _sort = service.sort;
  }

  void _toggleType(String type) {
    final types = _draft.noteTypes.map(NoteQuery.typeKey).toSet();
    types.contains(type) ? types.remove(type) : types.add(type);
    setState(() => _draft = _draft.copyWith(noteTypes: types.toList()));
  }

  void _toggleFolder(int id) {
    final ids = _draft.folderIds.toSet();
    ids.contains(id) ? ids.remove(id) : ids.add(id);
    setState(() => _draft = _draft.copyWith(folderIds: ids.toList()));
  }

  Future<void> _apply() async {
    final service = context.read<FilterService>();
    final navigator = Navigator.of(context);
    await service.updateFilters(_draft);
    await service.setSort(_sort);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final t = context.type;
    final types = _draft.noteTypes.map(NoteQuery.typeKey).toSet();

    Widget label(String text, {bool first = false}) => Padding(
          padding: EdgeInsets.only(top: first ? 0 : 22, bottom: 10),
          child:
              Text(text, style: t.chip.copyWith(fontWeight: FontWeight.w700)),
        );

    Widget typeChip(String type, String text) => SketchChip(
          label: text,
          selected: types.contains(type),
          pastel: FolderPalette.typePastel(type),
          padding: SketchChip.filterPadding,
          onTap: () => _toggleType(type),
        );

    Widget sortChip(NoteSort sort, String text) => SketchChip(
          label: text,
          selected: _sort == sort,
          padding: SketchChip.filterPadding,
          onTap: () => setState(() => _sort = sort),
        );

    return StreamBuilder<List<NoteWithDetails>>(
      stream: _notes,
      builder: (context, notesSnap) {
        final count = notesSnap.hasData
            ? NoteQuery.apply(notesSnap.data!, _draft, sort: _sort).length
            : null;

        return SketchSheet(
          title: l10n.filterTitle,
          action: SketchTextAction(
            label: l10n.filtersReset,
            style: t.body.copyWith(fontSize: 14),
            onTap: () => setState(() {
              _draft = FilterOptions.empty;
              _sort = NoteSort.lastEdited;
            }),
          ),
          footer: PillButton(
            height: 58,
            label: count == 0
                ? l10n.filtersNoMatch
                : l10n.filtersShowNotes(count ?? 0),
            onPressed: count == 0 ? null : _apply,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              label(l10n.filtersSortBy, first: true),
              Wrap(
                spacing: SketchSpace.chip,
                runSpacing: SketchSpace.chip,
                children: [
                  sortChip(NoteSort.lastEdited, l10n.sortLastEdited),
                  sortChip(NoteSort.dateCreated, l10n.sortDateCreated),
                  sortChip(NoteSort.titleAz, l10n.sortTitleAz),
                ],
              ),
              label(l10n.filtersNoteType),
              Wrap(
                spacing: SketchSpace.chip,
                runSpacing: SketchSpace.chip,
                children: [
                  typeChip('text', l10n.noteTypeText),
                  typeChip('todo', l10n.noteTypeChecklist),
                  typeChip('voice', l10n.noteTypeVoice),
                  typeChip('reminder', l10n.noteTypeReminder),
                ],
              ),
              StreamBuilder<List<FolderSummary>>(
                stream: _folders,
                builder: (context, snap) {
                  final folders = snap.data ?? const <FolderSummary>[];
                  if (folders.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      label(l10n.filterFolders),
                      Wrap(
                        spacing: SketchSpace.chip,
                        runSpacing: SketchSpace.chip,
                        children: [
                          for (final f in folders)
                            SketchChip(
                              label: f.title,
                              selected: _draft.folderIds.contains(f.id),
                              pastel: f.color,
                              padding: SketchChip.filterPadding,
                              onTap: () => _toggleFolder(f.id),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),
              SketchGroup(
                margin: EdgeInsets.zero,
                children: [
                  SketchRow(
                    label: l10n.filtersPinnedOnly,
                    minHeight: 54,
                    trailing: SketchToggle(
                      value: _draft.pinsOnly,
                      semanticLabel: l10n.filtersPinnedOnly,
                      onChanged: (v) =>
                          setState(() => _draft = _draft.copyWith(pinsOnly: v)),
                    ),
                  ),
                  SketchRow(
                    label: l10n.filtersIncludeArchived,
                    minHeight: 54,
                    trailing: SketchToggle(
                      value: _draft.includeArchived,
                      semanticLabel: l10n.filtersIncludeArchived,
                      onChanged: (v) => setState(
                          () => _draft = _draft.copyWith(includeArchived: v)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
