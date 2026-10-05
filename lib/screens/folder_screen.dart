import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/models/note_with_details.dart';
import 'package:pinpoint/services/drift_note_service.dart';
import 'package:provider/provider.dart';

import '../components/shared/folder_actions.dart';
import '../components/shared/note_grid.dart';
import '../design_system/design_system.dart';
import '../models/folder_summary.dart';
import '../navigation/new_note.dart';
import '../service_locators/init_service_locators.dart';
import '../services/analytics/analytics_facade.dart';
import '../services/crash_breadcrumbs.dart';
import '../services/drift_note_folder_service.dart';
import '../services/filter_service.dart';
import '../util/folder_palette.dart';
import '../util/note_query.dart';
import '../widgets/pinpoint_popup_menu_button.dart';
import 'my_folders_screen.dart';

/// One folder's notes: a [FolderTile] hero with the folder's name, colour
/// and counts, then the masonry grid filtered and sorted by the Filters
/// sheet.
class FolderScreen extends StatefulWidget {
  static const String kRouteName = '/folder';
  final int folderId;
  final String folderTitle;

  const FolderScreen({
    super.key,
    required this.folderId,
    required this.folderTitle,
  });

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  String _searchQuery = '';
  bool _isSearchActive = false;
  final _searchController = TextEditingController();
  Timer? _debounce;

  late final Stream<List<FolderSummary>> _folders =
      DriftNoteFolderService.watchFolderSummaries();
  Stream<List<NoteWithDetails>>? _notes;
  String? _notesQuery;
  List<NoteWithDetails>? _cached;

  @override
  void initState() {
    super.initState();
    getIt<AnalyticsFacade>().trackScreenView(screenName: 'Folder');
    _searchController.addListener(_onSearchInputChanged);
  }

  void _onSearchInputChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() => _searchQuery = _searchController.text);
    });
  }

  /// The folder's notes, cached per search query.
  Stream<List<NoteWithDetails>> _notesFor(String query) {
    if (_notes == null || query != _notesQuery) {
      _notesQuery = query;
      _notes = DriftNoteService.watchNotesWithDetailsByFolderV2(
        folderId: widget.folderId,
        searchQuery: query,
        sortType: 'updatedAt',
        sortDirection: 'desc',
      );
    }
    return _notes!;
  }

  void _toggleSearch() {
    PinpointHaptics.light();
    setState(() {
      _isSearchActive = !_isSearchActive;
      if (!_isSearchActive) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = context.sketch;
    final filters = context.watch<FilterService>();

    return SketchScaffold(
      doodleTop: DoodleBackground.foldersTop,
      actions: [
        CircleIconButton(
          icon: _isSearchActive ? Icons.close_rounded : Icons.search_rounded,
          semanticLabel: _isSearchActive
              ? MaterialLocalizations.of(context).closeButtonTooltip
              : l10n.commonSearch,
          onPressed: _toggleSearch,
        ),
        const SizedBox(width: 6),
        NoteFilterButton(count: filters.activeFilterCount),
      ],
      body: StreamBuilder<List<FolderSummary>>(
        stream: _folders,
        builder: (context, folderSnap) {
          final summary = folderSnap.data
              ?.where((f) => f.id == widget.folderId)
              .firstOrNull;
          final title = summary?.title ?? widget.folderTitle;

          return StreamBuilder<List<NoteWithDetails>>(
            stream: _notesFor(_searchQuery),
            builder: (context, snapshot) {
              if (snapshot.hasData) _cached = snapshot.data;
              final raw = snapshot.data ?? _cached;

              final slivers = <Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        SketchSpace.screenX, 18, SketchSpace.screenX, 0),
                    child: _Hero(
                      folderId: widget.folderId,
                      title: title,
                      summary: summary,
                    ),
                  ),
                ),
                if (_isSearchActive)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          SketchSpace.screenX, 16, SketchSpace.screenX, 0),
                      child: SketchSearchField(
                        controller: _searchController,
                        hint: l10n.folderSearchHint,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 18)),
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
                final notes = NoteQuery.apply(
                  raw,
                  // This screen IS the folder filter.
                  filters.filterOptions.copyWith(folderIds: const []),
                  sort: filters.sort,
                );
                if (notes.isEmpty) {
                  slivers.add(SliverToBoxAdapter(
                    child: _searchQuery.isNotEmpty
                        ? EmptyState(
                            icon: Icons.search_off_rounded,
                            title: l10n.homeNoMatches(_searchQuery),
                          )
                        : raw.isNotEmpty && filters.hasActiveFilters
                            ? EmptyState(
                                icon: Icons.filter_alt_off_outlined,
                                title: l10n.homeNoFilterMatches,
                                actionLabel: l10n.homeClearFilters,
                                onAction: filters.clearFilters,
                              )
                            : EmptyState(
                                icon: Icons.folder_open_rounded,
                                title: l10n.flEmptyTitle(title),
                                actionLabel: l10n.flEmptyAction,
                                onAction: () => NewNote.open(context),
                              ),
                  ));
                } else {
                  slivers.add(NoteGridSliver(notes: notes));
                }
              }

              slivers.add(SliverToBoxAdapter(
                child:
                    SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
              ));

              return CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: slivers,
              );
            },
          );
        },
      ),
      backgroundColor: s.bg,
    );
  }
}

/// The folder hero: a 120-tall [FolderTile] with the name, counts, the
/// colours of the notes inside, and the folder's menu.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.folderId,
    required this.title,
    required this.summary,
  });

  final int folderId;
  final String title;
  final FolderSummary? summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = context.sketch;
    final f = summary;
    final color = f?.color ?? FolderPalette.typePastel('text');

    return Semantics(
      header: true,
      child: FolderTile(
        title: title,
        subtitle: f == null ? '' : folderSubtitle(l10n, f),
        pastel: color,
        noteColors: [for (final n in f?.recent ?? const []) n.color],
        height: 120,
        menu: f == null
            ? null
            : PinpointPopupMenuButton<String>(
                tooltip: l10n.flMenuLabel(title),
                icon: Icon(Icons.more_horiz_rounded, color: s.muted),
                onOpened: () => CrashBreadcrumbs.popupMenuOpened('folder.hero'),
                onCanceled: () =>
                    CrashBreadcrumbs.popupMenuClosed('folder.hero'),
                onSelected: (value) async {
                  CrashBreadcrumbs.popupMenuClosed('folder.hero',
                      selected: value);
                  switch (value) {
                    case 'rename':
                      await FolderActions.rename(context, folderId, title);
                    case 'colour':
                      await FolderActions.changeColour(
                          context, folderId, color);
                    case 'delete':
                      final deleted =
                          await FolderActions.delete(context, folderId, title);
                      if (deleted && context.mounted) context.pop();
                  }
                },
                itemBuilder: (ctx) => [
                  PinpointPopupMenuButton.item(ctx,
                      value: 'rename',
                      label: l10n.foldersRename,
                      icon: Icons.drive_file_rename_outline_rounded),
                  PinpointPopupMenuButton.item(ctx,
                      value: 'colour',
                      label: l10n.flChangeColour,
                      icon: Icons.palette_outlined),
                  PinpointPopupMenuButton.item(ctx,
                      value: 'delete',
                      label: l10n.commonDelete,
                      icon: Icons.delete_outline_rounded,
                      destructive: true),
                ],
              ),
      ),
    );
  }
}
