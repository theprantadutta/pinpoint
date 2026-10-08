import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';
import 'package:pinpoint/screens/create_note_screen_v2.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../models/note_with_details.dart';
import '../../navigation/new_note.dart';
import '../../services/drift_note_service.dart';
import '../../services/filter_service.dart';
import '../../util/localized_dates.dart';
import '../../util/note_query.dart';
import '../../util/note_utils.dart';
import '../../widgets/filter_bottom_sheet.dart';

/// "Recent notes" plus the current sort, as a sliver. The sort label opens
/// the Filters sheet.
class RecentNotesHeader extends StatelessWidget {
  const RecentNotesHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = context.sketch;
    final filters = context.watch<FilterService>();
    final sortLabel = switch (filters.sort) {
      NoteSort.lastEdited => l10n.sortLastEdited,
      NoteSort.dateCreated => l10n.sortDateCreated,
      NoteSort.titleAz => l10n.sortTitleAz,
    };
    final active = filters.activeFilterCount;

    return SketchSectionHeader(
      title: l10n.homeRecentNotes,
      action: SketchPressable(
        onTap: () => FilterBottomSheet.show(context),
        semanticLabel: '${l10n.filterTitle}, $sortLabel',
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SketchSpace.minTap),
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (active > 0) ...[
                  SketchTag(label: '$active', inverse: true),
                  const SizedBox(width: 8),
                ],
                Text(sortLabel,
                    style: context.type.chip.copyWith(color: s.muted)),
                Icon(Icons.arrow_drop_down_rounded, color: s.muted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The notes grid as a sliver: a 2-column masonry of [NoteCard]s (one column
/// in the tablet master–detail list), filtered and sorted by [FilterService].
class RecentNotesSliver extends StatefulWidget {
  const RecentNotesSliver({
    super.key,
    required this.searchQuery,
    this.onNoteSelected,
    this.selectedNoteUuid,
  });

  final String searchQuery;

  /// When provided (tablet master–detail), tapping a note reports it here
  /// instead of pushing the full-screen editor route.
  final void Function(NoteWithDetails note)? onNoteSelected;

  /// The note open in the detail pane, highlighted in the list. Matched by
  /// uuid: the integer id is per note-type table, so a checklist and a text
  /// note can share one, and both cards lit up as selected.
  final String? selectedNoteUuid;

  @override
  State<RecentNotesSliver> createState() => _RecentNotesSliverState();
}

class _RecentNotesSliverState extends State<RecentNotesSliver> {
  // Last data, to avoid a loading flash when the query changes.
  List<NoteWithDetails>? _cached;
  Stream<List<NoteWithDetails>>? _stream;
  String? _streamQuery;
  bool? _streamArchived;

  Stream<List<NoteWithDetails>> _streamFor(String query, bool archived) {
    if (_stream == null ||
        query != _streamQuery ||
        archived != _streamArchived) {
      _streamQuery = query;
      _streamArchived = archived;
      _stream = DriftNoteService.watchNotesWithDetailsV2(
        searchQuery: query,
        includeArchived: archived,
      );
    }
    return _stream!;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final filters = context.watch<FilterService>();
    final options = filters.filterOptions;

    return StreamBuilder<List<NoteWithDetails>>(
      stream: _streamFor(widget.searchQuery, options.includeArchived),
      builder: (context, snapshot) {
        final raw = snapshot.data ?? _cached;
        if (snapshot.hasData) _cached = snapshot.data;

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.error_outline_rounded,
              title: l10n.foldersSomethingWrong,
              message: l10n.commonTryAgainLater,
            ),
          );
        }
        if (raw == null) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final notes = NoteQuery.apply(raw, options, sort: filters.sort);

        if (notes.isEmpty) {
          final Widget empty;
          if (widget.searchQuery.isNotEmpty) {
            empty = EmptyState(
              icon: Icons.search_off_rounded,
              title: l10n.homeNoMatches(widget.searchQuery),
            );
          } else if (raw.isNotEmpty && options.hasActiveFilters) {
            empty = EmptyState(
              icon: Icons.filter_alt_off_outlined,
              title: l10n.homeNoFilterMatches,
              actionLabel: l10n.homeClearFilters,
              onAction: () => filters.clearFilters(),
            );
          } else {
            empty = EmptyState(
              icon: Icons.edit_rounded,
              title: l10n.homeEmptyTitle,
              actionLabel: l10n.homeEmptyAction,
              onAction: () => NewNote.open(context),
            );
          }
          return SliverToBoxAdapter(child: empty);
        }

        final columns =
            widget.onNoteSelected != null ? 1 : context.noteGridColumns;
        Widget item(int i) => NoteListItem(
              note: notes[i],
              onOpen: widget.onNoteSelected,
              isSelected: widget.selectedNoteUuid == notes[i].note.uuid,
            );

        final padding = EdgeInsets.symmetric(
          horizontal: widget.onNoteSelected == null && context.isTablet
              ? PinpointSpacing.screenEdgeLarge
              : SketchSpace.screenX,
        );

        if (columns > 1) {
          return SliverPadding(
            padding: padding,
            sliver: SliverMasonryGrid.count(
              crossAxisCount: columns,
              mainAxisSpacing: SketchSpace.grid,
              crossAxisSpacing: SketchSpace.grid,
              childCount: notes.length,
              itemBuilder: (context, i) => item(i),
            ),
          );
        }
        return SliverPadding(
          padding: padding,
          sliver: SliverList.separated(
            itemCount: notes.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: SketchSpace.grid),
            itemBuilder: (context, i) => item(i),
          ),
        );
      },
    );
  }
}

/// A [NoteCard] for one note, wired to open it in the editor.
class NoteListItem extends StatelessWidget {
  final NoteWithDetails note;
  final bool isArchivedView;
  final bool isTrashView;
  final bool showActions;

  /// When provided, tapping the note calls this instead of pushing the
  /// full-screen editor route (used to drive a master–detail detail pane).
  final void Function(NoteWithDetails note)? onOpen;

  /// Whether this note is the one currently open in the detail pane.
  final bool isSelected;

  const NoteListItem({
    super.key,
    required this.note,
    this.isArchivedView = false,
    this.isTrashView = false,
    this.showActions = true,
    this.onOpen,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final n = note.note;
    final hasTitle = n.noteTitle != null && n.noteTitle!.trim().isNotEmpty;
    final isVoice = NoteQuery.typeKey(n.noteType) == 'voice';

    return NoteCard(
      title: getNoteTitleOrPreview(n.noteTitle, note.textContent),
      // Voice previews are a generated "Voice recording 1m 2s" line; the card
      // shows a waveform and the duration instead.
      excerpt: hasTitle && !isVoice ? note.textContent : null,
      lastModified: n.updatedAt,
      isPinned: n.isPinned,
      noteType: NoteQuery.typeKey(n.noteType),
      backgroundColor: PinpointColors.noteColor(note.color, Brightness.light),
      isSelected: isSelected,
      muted: isArchivedView || isTrashView || n.isArchived,
      voiceDuration: isVoice
          ? LocalizedDates.duration(context, note.voiceDurationSeconds ?? 0)
          : null,
      reminderLabel: note.reminderAt == null
          ? null
          : LocalizedDates.relativeDayTime(context, note.reminderAt!),
      checklist: n.noteType == 'todo'
          ? note.todoItems
              .map((item) => NoteChecklistItem(
                    label: item.todoTitle,
                    isDone: item.isDone,
                  ))
              .toList()
          : null,
      totalTasks: n.noteType == 'todo' ? note.todoItems.length : null,
      completedTasks: n.noteType == 'todo'
          ? note.todoItems.where((item) => item.isDone).length
          : null,
      onTap: () {
        PinpointHaptics.light();
        if (onOpen != null) {
          onOpen!(note);
        } else {
          context.push(
            CreateNoteScreenV2.kRouteName,
            extra: CreateNoteScreenArguments(
              noticeType: n.noteType,
              existingNote: note,
            ),
          );
        }
      },
      onPinToggle: () {
        PinpointHaptics.light();
        DriftNoteService.togglePinStatus(n.id, !n.isPinned);
      },
    );
  }
}
