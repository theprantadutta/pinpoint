import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/models/note_with_details.dart';
import 'package:pinpoint/services/drift_note_service.dart';
import 'package:pinpoint/util/note_utils.dart';

import '../components/shared/note_grid.dart';
import '../design_system/design_system.dart';
import '../service_locators/init_service_locators.dart';
import '../services/analytics/analytics_facade.dart';

/// Archived notes: the masonry grid with each card dimmed to 70% and two
/// small actions under it — unarchive and delete forever.
class ArchiveScreen extends StatefulWidget {
  static const String kRouteName = '/archive';

  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  String _searchQuery = '';
  bool _isSearchActive = false;
  final _searchController = TextEditingController();
  Timer? _debounce;

  Stream<List<NoteWithDetails>>? _stream;
  String? _streamQuery;
  List<NoteWithDetails>? _cached;

  @override
  void initState() {
    super.initState();
    getIt<AnalyticsFacade>().trackScreenView(screenName: 'Archive');
    _searchController.addListener(_onSearchInputChanged);
  }

  void _onSearchInputChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() => _searchQuery = _searchController.text);
    });
  }

  Stream<List<NoteWithDetails>> _streamFor(String query) {
    if (_stream == null || query != _streamQuery) {
      _streamQuery = query;
      _stream = DriftNoteService.watchArchivedNotesV2(
        searchQuery: query,
        sortType: 'updatedAt',
        sortDirection: 'desc',
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

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _unarchive(NoteWithDetails note) async {
    final n = note.note;
    PinpointHaptics.light();
    await DriftNoteService.toggleArchiveStatus(n.id, false);
    getIt<AnalyticsFacade>().trackNoteRestored(noteType: n.noteType);
  }

  Future<void> _deleteForever(NoteWithDetails note) async {
    final l10n = AppL10n.of(context);
    final n = note.note;
    final confirmed = await ConfirmSheet.show(
      context: context,
      title: l10n.trashDeleteForeverTitle,
      message: l10n.trashDeleteForeverBody,
      primaryLabel: l10n.trashDeleteForever,
      secondaryLabel: l10n.commonCancel,
      isDestructive: true,
      icon: Icons.delete_forever_rounded,
    );
    if (confirmed == true) {
      PinpointHaptics.success();
      await DriftNoteService.permanentlyDeleteNoteByIdV2(n.id, n.noteType);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return SketchScaffold(
      title: l10n.archiveTitle,
      // Swooshes behind the header only: they would show through the
      // dimmed cards.
      doodleTop: -60,
      actions: [
        CircleIconButton(
          icon: _isSearchActive ? Icons.close_rounded : Icons.search_rounded,
          semanticLabel: _isSearchActive
              ? MaterialLocalizations.of(context).closeButtonTooltip
              : l10n.commonSearch,
          onPressed: _toggleSearch,
        ),
      ],
      body: StreamBuilder<List<NoteWithDetails>>(
        stream: _streamFor(_searchQuery),
        builder: (context, snapshot) {
          if (snapshot.hasData) _cached = snapshot.data;
          final notes = snapshot.data ?? _cached;

          final slivers = <Widget>[
            if (_isSearchActive)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      SketchSpace.screenX, 16, SketchSpace.screenX, 0),
                  child: SketchSearchField(
                    controller: _searchController,
                    hint: l10n.archiveSearchHint,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
          ];

          if (snapshot.hasError) {
            slivers.add(SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.error_outline_rounded,
                title: l10n.archiveLoadError,
                message: l10n.commonTryAgainLater,
              ),
            ));
          } else if (notes == null) {
            slivers.add(const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
            ));
          } else if (notes.isEmpty) {
            slivers.add(SliverToBoxAdapter(
              child: _searchQuery.isNotEmpty
                  ? EmptyState(
                      icon: Icons.search_off_rounded,
                      title: l10n.homeNoMatches(_searchQuery),
                    )
                  : EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: l10n.archiveEmpty,
                      message: l10n.archiveEmptyHint,
                    ),
            ));
          } else {
            slivers.add(NoteGridSliver(
              notes: notes,
              itemBuilder: (context, note) {
                final title = getNoteTitleOrPreview(
                    note.note.noteTitle, note.textContent);
                return ManagedNoteItem(
                  note: note,
                  actions: [
                    NoteAction(
                      icon: Icons.unarchive_outlined,
                      label: l10n.lsUnarchive(title),
                      onTap: () => _unarchive(note),
                    ),
                    NoteAction(
                      icon: Icons.delete_forever_outlined,
                      label: l10n.lsDeleteNoteForever(title),
                      destructive: true,
                      onTap: () => _deleteForever(note),
                    ),
                  ],
                );
              },
            ));
          }

          slivers.add(SliverToBoxAdapter(
            child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
          ));
          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: slivers,
          );
        },
      ),
    );
  }
}
