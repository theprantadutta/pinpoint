import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/models/note_with_details.dart';
import 'package:pinpoint/services/drift_note_service.dart';
import 'package:provider/provider.dart';

import '../components/shared/note_grid.dart';
import '../design_system/design_system.dart';
import '../models/folder_summary.dart';
import '../navigation/new_note.dart';
import '../navigation/shell_menu_button.dart';
import '../service_locators/init_service_locators.dart';
import '../services/analytics/analytics_facade.dart';
import '../services/drift_note_folder_service.dart';
import '../services/filter_service.dart';
import '../util/note_query.dart';

/// Dock tab 2: every note, as the home masonry grid, with a folder chip row
/// and the Filters sheet.
///
/// The drawer links here with `?type=voice` or `?type=reminder` ([type]);
/// the list then shows only that type, titled "Voice notes" / "Reminders",
/// with a back button to all notes.
class NotesScreen extends StatefulWidget {
  static const String kRouteName = '/notes';

  const NotesScreen({super.key, this.type});

  /// 'voice' | 'reminder', or null for every note.
  final String? type;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isGridView = true;
  bool _isSearchActive = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  /// The folder chip selected in the row; null = "All".
  int? _folderId;

  /// Folders for the chip row, kept live.
  List<FolderSummary> _folders = const [];
  StreamSubscription<List<FolderSummary>>? _folderSub;

  // The note stream, recreated only when its inputs change.
  Stream<List<NoteWithDetails>>? _stream;
  String? _streamQuery;
  bool? _streamArchived;

  // Last data, to avoid a loading flash when the query changes.
  List<NoteWithDetails>? _cached;

  static const _types = {'voice', 'reminder'};

  String? get _type => _types.contains(widget.type) ? widget.type : null;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchInputChanged);
    getIt<AnalyticsFacade>().trackScreenView(screenName: 'Notes');
    _folderSub = DriftNoteFolderService.watchFolderSummaries().listen((v) {
      if (mounted) setState(() => _folders = v);
    });
  }

  void _onSearchInputChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      final query = _searchController.text;
      if (query == _searchQuery) return;
      setState(() => _searchQuery = query);
      // Search text is note content — only its length ever leaves the device.
      // Count runes, not UTF-16 units, so bn/th/ar/fa bucket sensibly.
      final queryLength = query.trim().runes.length;
      if (queryLength > 0) {
        getIt<AnalyticsFacade>().trackSearchPerformed(queryLength: queryLength);
      }
    });
  }

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

  void _toggleSearch() {
    PinpointHaptics.light();
    setState(() {
      _isSearchActive = !_isSearchActive;
      if (!_isSearchActive) _searchController.clear();
    });
  }

  void _toggleView() {
    PinpointHaptics.light();
    setState(() => _isGridView = !_isGridView);
    getIt<AnalyticsFacade>()
        .trackViewModeChanged(viewMode: _isGridView ? 'grid' : 'list');
  }

  @override
  void dispose() {
    _folderSub?.cancel();
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _title(AppL10n l10n) => switch (_type) {
        'voice' => l10n.drawerVoiceNotes,
        'reminder' => l10n.drawerReminders,
        _ => l10n.drawerAllNotes,
      };

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final l10n = AppL10n.of(context);
    final filters = context.watch<FilterService>();
    final options = filters.filterOptions;
    final type = _type;

    return SketchScaffold(
      largeTitle: true,
      title: _title(l10n),
      doodleTop: DoodleBackground.homeTop,
      showBack: type != null,
      leading: type == null
          ? shellMenuButton(context)
          : CircleIconButton(
              icon: Icons.arrow_back_rounded,
              semanticLabel: l10n.lsShowAllNotes,
              onPressed: () => context.go(NotesScreen.kRouteName),
            ),
      actions: [
        CircleIconButton(
          icon: _isSearchActive ? Icons.close_rounded : Icons.search_rounded,
          semanticLabel: _isSearchActive
              ? MaterialLocalizations.of(context).closeButtonTooltip
              : l10n.commonSearch,
          onPressed: _toggleSearch,
        ),
        const SizedBox(width: 6),
        CircleIconButton(
          icon: _isGridView
              ? Icons.view_agenda_outlined
              : Icons.dashboard_outlined,
          semanticLabel: _isGridView ? l10n.notesListView : l10n.notesGridView,
          onPressed: _toggleView,
        ),
        const SizedBox(width: 6),
        NoteFilterButton(count: filters.activeFilterCount),
      ],
      body: StreamBuilder<List<NoteWithDetails>>(
        stream: _streamFor(_searchQuery, options.includeArchived),
        builder: (context, snapshot) {
          if (snapshot.hasData) _cached = snapshot.data;
          final raw = snapshot.data ?? _cached;

          final slivers = <Widget>[
            if (_isSearchActive)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      SketchSpace.screenX, 16, SketchSpace.screenX, 0),
                  child: SketchSearchField(
                    controller: _searchController,
                    hint: l10n.notesSearchHint,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: _FolderChips(
                folders: _folders,
                selectedId: _selectedFolder?.id,
                onSelected: (id) => setState(() => _folderId = id),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ];

          if (snapshot.hasError) {
            slivers.add(SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.error_outline_rounded,
                title: l10n.notesLoadError,
                message: l10n.commonTryAgainLater,
              ),
            ));
          } else if (raw == null) {
            slivers.add(const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
            ));
          } else {
            var notes = NoteQuery.apply(raw, options, sort: filters.sort);
            if (type != null) {
              notes = notes
                  .where((n) => NoteQuery.typeKey(n.note.noteType) == type)
                  .toList();
            }
            final folderId = _selectedFolder?.id;
            if (folderId != null) {
              notes = notes
                  .where((n) => n.folders.any((f) => f.id == folderId))
                  .toList();
            }

            if (notes.isEmpty) {
              slivers.add(SliverToBoxAdapter(
                child: _empty(context, raw: raw, filters: filters),
              ));
            } else {
              slivers.add(NoteGridSliver(
                notes: notes,
                columns: _isGridView ? null : 1,
              ));
            }
          }

          slivers.add(SliverToBoxAdapter(
            child: SizedBox(height: dockAwareBottomPadding(context)),
          ));

          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: slivers,
          );
        },
      ),
    );
  }

  Widget _empty(
    BuildContext context, {
    required List<NoteWithDetails> raw,
    required FilterService filters,
  }) {
    final l10n = AppL10n.of(context);
    if (_searchQuery.isNotEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: l10n.homeNoMatches(_searchQuery),
      );
    }
    if (raw.isNotEmpty && filters.hasActiveFilters) {
      return EmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: l10n.homeNoFilterMatches,
        actionLabel: l10n.homeClearFilters,
        onAction: filters.clearFilters,
      );
    }
    switch (_type) {
      case 'voice':
        return EmptyState(
          icon: Icons.mic_none_rounded,
          title: l10n.lsEmptyVoice,
          actionLabel: l10n.dockNewNote,
          onAction: () => NewNote.open(context, NewNote.voice),
        );
      case 'reminder':
        return EmptyState(
          icon: Icons.alarm_rounded,
          title: l10n.lsEmptyReminders,
          actionLabel: l10n.dockNewNote,
          onAction: () => NewNote.open(context, NewNote.reminder),
        );
    }
    final folder = _selectedFolder;
    if (folder != null) {
      return EmptyState(
        icon: Icons.folder_open_rounded,
        title: l10n.flEmptyTitle(folder.title),
        actionLabel: l10n.flEmptyAction,
        onAction: () => NewNote.open(context),
      );
    }
    return EmptyState(
      icon: Icons.edit_rounded,
      title: l10n.homeEmptyTitle,
      actionLabel: l10n.homeEmptyAction,
      onAction: () => NewNote.open(context),
    );
  }

  /// The selected chip's folder; null for "All" or a folder since deleted.
  FolderSummary? get _selectedFolder =>
      _folders.where((f) => f.id == _folderId).firstOrNull;
}

/// "All" plus one chip per folder ("Work (4)"). Single-select, inverse when
/// selected; scrolls horizontally.
class _FolderChips extends StatelessWidget {
  const _FolderChips({
    required this.folders,
    required this.selectedId,
    required this.onSelected,
  });

  final List<FolderSummary> folders;
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    if (folders.isEmpty) return const SizedBox(height: 4);

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: SketchSpace.screenX),
          itemCount: folders.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: SketchSpace.chip),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Center(
                child: SketchChip(
                  label: l10n.lsChipAll,
                  selected: selectedId == null,
                  onTap: () => onSelected(null),
                ),
              );
            }
            final f = folders[i - 1];
            return Center(
              child: SketchChip(
                label: l10n.homeFolderChip(f.title, f.noteCount),
                selected: f.id == selectedId,
                onTap: () => onSelected(f.id == selectedId ? null : f.id),
              ),
            );
          },
        ),
      ),
    );
  }
}
