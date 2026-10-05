import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/models/note_with_details.dart';
import 'package:pinpoint/services/drift_note_service.dart';
import 'package:pinpoint/util/localized_dates.dart';
import 'package:pinpoint/util/note_utils.dart';

import '../components/shared/note_grid.dart';
import '../design_system/design_system.dart';
import '../service_locators/init_service_locators.dart';
import '../services/analytics/analytics_facade.dart';

/// Trashed notes: a banner explaining how long notes stay (with Empty
/// trash), then the masonry grid with each card dimmed to 70% and restore /
/// delete-forever actions under it.
///
/// Pinpoint never purges the trash on its own — there is no retention job on
/// the device or the server — so the banner says notes stay until emptied.
class TrashScreen extends StatefulWidget {
  static const String kRouteName = '/trash';

  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  String _searchQuery = '';
  bool _isSearchActive = false;
  final _searchController = TextEditingController();
  Timer? _debounce;

  Stream<List<NoteWithDetails>>? _stream;
  String? _streamQuery;
  List<NoteWithDetails>? _cached;
  bool _emptying = false;

  @override
  void initState() {
    super.initState();
    getIt<AnalyticsFacade>().trackScreenView(screenName: 'Trash');
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
      _stream = DriftNoteService.watchDeletedNotesV2(
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

  Future<void> _restore(NoteWithDetails note) async {
    final l10n = AppL10n.of(context);
    final n = note.note;
    final confirmed = await ConfirmSheet.show(
      context: context,
      title: l10n.trashRestoreTitle,
      message: l10n.trashRestoreBody,
      primaryLabel: l10n.trashRestore,
      secondaryLabel: l10n.commonCancel,
      isDestructive: false,
      icon: Icons.restore_from_trash_rounded,
    );
    if (confirmed == true) {
      PinpointHaptics.light();
      await DriftNoteService.restoreNoteByIdV2(n.id, n.noteType);
      getIt<AnalyticsFacade>().trackNoteRestoredFromTrash();
    }
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

  /// Permanently deletes every trashed note (the whole trash, not just the
  /// current search results).
  Future<void> _emptyTrash() async {
    if (_emptying) return;
    final l10n = AppL10n.of(context);
    final all = await DriftNoteService.watchDeletedNotesV2().first;
    if (!mounted || all.isEmpty) return;
    final confirmed = await ConfirmSheet.show(
      context: context,
      title: l10n.lsEmptyTrashTitle,
      message: l10n.lsEmptyTrashBody(all.length),
      primaryLabel: l10n.lsEmptyTrash,
      secondaryLabel: l10n.commonCancel,
      isDestructive: true,
      icon: Icons.delete_sweep_rounded,
    );
    if (confirmed != true) return;
    setState(() => _emptying = true);
    try {
      for (final note in all) {
        await DriftNoteService.permanentlyDeleteNoteByIdV2(
            note.note.id, note.note.noteType);
      }
      PinpointHaptics.success();
    } finally {
      if (mounted) setState(() => _emptying = false);
    }
  }

  String _deletedAgo(DateTime dateTime) {
    final l10n = AppL10n.of(context);
    final difference = DateTime.now().difference(dateTime);
    final String when;
    if (difference.inSeconds < 60) {
      when = l10n.relativeTimeJustNow;
    } else if (difference.inMinutes < 60) {
      when = l10n.relativeTimeMinutesAgo(difference.inMinutes);
    } else if (difference.inHours < 24) {
      when = l10n.relativeTimeHoursAgo(difference.inHours);
    } else if (difference.inDays < 7) {
      when = l10n.relativeTimeDaysAgo(difference.inDays);
    } else if (difference.inDays < 30) {
      when = l10n.relativeTimeWeeksAgo((difference.inDays / 7).floor());
    } else {
      when = LocalizedDates.monthDay(context, dateTime);
    }
    return l10n.trashDeletedAgo(when);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return SketchScaffold(
      title: l10n.trashTitle,
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    SketchSpace.screenX, 18, SketchSpace.screenX, 0),
                child: TrashBanner(
                  message: l10n.lsTrashKeep,
                  actionLabel: l10n.lsEmptyTrash,
                  busy: _emptying,
                  onAction: (notes == null || notes.isEmpty) &&
                          _searchQuery.isEmpty
                      ? null
                      : _emptyTrash,
                ),
              ),
            ),
            if (_isSearchActive)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      SketchSpace.screenX, 14, SketchSpace.screenX, 0),
                  child: SketchSearchField(
                    controller: _searchController,
                    hint: l10n.trashSearchHint,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
          ];

          if (snapshot.hasError) {
            slivers.add(SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.error_outline_rounded,
                title: l10n.trashLoadError,
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
                      icon: Icons.delete_outline_rounded,
                      title: l10n.trashEmpty,
                      message: l10n.trashEmptyHint,
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
                  isTrashView: true,
                  caption: _deletedAgo(note.note.updatedAt),
                  actions: [
                    NoteAction(
                      icon: Icons.restore_from_trash_outlined,
                      label: l10n.lsRestoreNote(title),
                      onTap: () => _restore(note),
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
            child:
                SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
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

/// The soft-fill, outlined banner at the top of Trash: how long notes stay,
/// and an "Empty trash" text action in the error colour.
class TrashBanner extends StatelessWidget {
  const TrashBanner({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.busy = false,
  });

  final String message;
  final String actionLabel;

  /// Null hides the action (nothing to empty).
  final VoidCallback? onAction;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 10, 6),
      decoration: BoxDecoration(
        color: s.soft,
        borderRadius: BorderRadius.circular(SketchRadius.group),
        border: Border.all(color: s.outline, width: SketchStroke.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: s.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(message,
                  style: t.bodyRegular.copyWith(fontSize: 13, height: 1.35)),
            ),
          ),
          if (busy)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: s.ink),
              ),
            )
          else if (onAction != null) ...[
            const SizedBox(width: 8),
            SketchTextAction(
              label: actionLabel,
              color: SketchFunctional.error,
              underline: false,
              style: t.chip.copyWith(fontWeight: FontWeight.w700),
              onTap: onAction,
            ),
          ],
        ],
      ),
    );
  }
}
