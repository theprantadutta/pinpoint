import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/constants/shared_preference_keys.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';
import 'package:pinpoint/screens/create_note_screen_v2.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design_system/design_system.dart';
import '../../models/note_with_details.dart';
import '../../services/drift_note_service.dart';
import '../../services/filter_service.dart';
import '../../util/note_utils.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

class HomeScreenRecentNotes extends StatefulWidget {
  final String searchQuery;
  final ScrollController? scrollController;

  /// When provided (tablet master–detail), tapping a note reports it here
  /// instead of pushing the full-screen editor route.
  final void Function(NoteWithDetails note)? onNoteSelected;

  /// The currently open note in the detail pane, for highlighting the list.
  final int? selectedNoteId;

  const HomeScreenRecentNotes({
    super.key,
    required this.searchQuery,
    this.scrollController,
    this.onNoteSelected,
    this.selectedNoteId,
  });

  @override
  State<HomeScreenRecentNotes> createState() => _HomeScreenRecentNotesState();
}

class _HomeScreenRecentNotesState extends State<HomeScreenRecentNotes>
    with AutomaticKeepAliveClientMixin {
  String _viewType = 'grid'; // Keep-style masonry by default
  String _sortType = 'updatedAt';
  String _sortDirection = 'desc';
  SharedPreferences? _preferences;

  // Cache for last loaded data to avoid loading flash
  List<NoteWithDetails>? _cachedNotes;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _preferences = await SharedPreferences.getInstance();
    setState(() {
      _viewType = _preferences?.getString(kHomeScreenViewTypeKey) ?? 'grid';
      _sortType =
          _preferences?.getString(kHomeScreenSortTypeKey) ?? 'updatedAt';
      _sortDirection =
          _preferences?.getString(kHomeScreenSortDirectionKey) ?? 'desc';
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // The master–detail list is a narrow pane, so keep its gutters tight; the
    // full-width grid gets the larger tablet edge padding.
    final horizontalPad = (widget.onNoteSelected == null && context.isTablet)
        ? PinpointSpacing.screenEdgeLarge
        : 16.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPad),
      child: Consumer<FilterService>(
        builder: (context, filterService, _) {
          return StreamBuilder<List<NoteWithDetails>>(
            stream: DriftNoteService.watchNotesWithDetailsV2(
              searchQuery: widget.searchQuery,
              sortType: _sortType,
              sortDirection: _sortDirection,
            ),
            builder: (context, snapshot) {
              // Use cached data while waiting to avoid loading flash
              if (snapshot.connectionState == ConnectionState.waiting) {
                if (_cachedNotes != null && _cachedNotes!.isNotEmpty) {
                  return _buildNotesList(_cachedNotes!);
                }
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: AppL10n.of(context).foldersSomethingWrong,
                  message: AppL10n.of(context).commonTryAgainLater,
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return EmptyState(
                  icon: Icons.note_add_rounded,
                  title: AppL10n.of(context).notesNoneFound,
                  message: AppL10n.of(context).notesCreateFirst,
                );
              }

              final data = snapshot.data!;
              _cachedNotes = data;

              return _buildNotesList(data);
            },
          );
        },
      ),
    );
  }

  /// Builds the notes view, split into PINNED / OTHERS sections (Keep-style).
  Widget _buildNotesList(List<NoteWithDetails> data) {
    final pinned = data.where((n) => n.note.isPinned).toList();
    final others = data.where((n) => !n.note.isPinned).toList();
    final hasPinned = pinned.isNotEmpty;

    final slivers = <Widget>[];

    if (hasPinned) {
      slivers.add(_sectionHeaderSliver(AppL10n.of(context).sectionPinned));
      slivers.add(_notesSliver(pinned));
      if (others.isNotEmpty) slivers.add(_sectionHeaderSliver(AppL10n.of(context).sectionOthers));
    }
    if (others.isNotEmpty) {
      slivers.add(_notesSliver(others));
    }

    return CustomScrollView(
      controller: widget.scrollController,
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _sectionHeaderSliver(String label) {
    return SliverToBoxAdapter(
      child: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: cs.onSurfaceVariant,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _notesSliver(List<NoteWithDetails> items) {
    // In master–detail mode the list is the narrow middle pane, so it reads
    // best as a single column (Apple Notes/Mail style).
    final columns = widget.onNoteSelected != null ? 1 : context.noteGridColumns;

    if (_viewType == 'grid' && columns > 1) {
      return SliverMasonryGrid.count(
        crossAxisCount: columns,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childCount: items.length,
        itemBuilder: (context, i) => _buildItem(items[i]),
      );
    }
    return SliverList.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _buildItem(items[i]),
    );
  }

  Widget _buildItem(NoteWithDetails note) {
    return NoteListItem(
      note: note,
      showActions: true,
      onOpen: widget.onNoteSelected,
      isSelected: widget.selectedNoteId != null &&
          widget.selectedNoteId == note.note.id,
    );
  }
}

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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final n = note.note;
    final hasTitle = n.noteTitle != null && n.noteTitle!.trim().isNotEmpty;
    final bgColor = PinpointColors.noteColor(note.color, theme.brightness);

    final card = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.98, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) => AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: 1.0,
        child: Transform.scale(scale: scale, child: child),
      ),
      child: NoteCard(
        title: getNoteTitleOrPreview(n.noteTitle, note.textContent),
        excerpt: hasTitle ? note.textContent : null,
        lastModified: n.updatedAt,
        isPinned: n.isPinned,
        noteType: n.noteType,
        backgroundColor: bgColor,
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
        tags: [
          if (note.folders.isNotEmpty)
            CardNoteTag(
              label: note.folders.first.title,
              color: cs.primary,
            ),
        ],
        onTap: () {
          PinpointHaptics.medium();
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
      ),
    );

    if (!isSelected) return card;

    // Ring the note that's currently open in the detail pane.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary, width: 2),
      ),
      child: card,
    );
  }
}

class _MiniActionPro extends StatefulWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MiniActionPro({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_MiniActionPro> createState() => _MiniActionProState();
}

class _MiniActionProState extends State<_MiniActionPro>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.color.withAlpha(dark ? 30 : 20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (dark ? Colors.white : Colors.black).withAlpha(25),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(dark ? 70 : 25),
                  blurRadius: _pressed ? 6 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(widget.icon, size: 18, color: widget.color),
          ),
        ),
      ),
    );
  }
}
