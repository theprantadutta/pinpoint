import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/models/note_with_details.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';
import 'package:pinpoint/screens/create_note_screen_v2.dart';
import 'package:pinpoint/services/drift_note_service.dart';
import 'package:provider/provider.dart';
import '../design_system/design_system.dart';
import '../service_locators/init_service_locators.dart';
import '../services/analytics/analytics_facade.dart';
import '../services/filter_service.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/util/localized_dates.dart';

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

  @override
  void initState() {
    super.initState();
    getIt<AnalyticsFacade>().trackScreenView(screenName: 'Trash');
    _searchController.addListener(_onSearchInputChanged);
  }

  void _onSearchInputChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      setState(() {
        _searchQuery = _searchController.text;
      });
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GradientScaffold(
      appBar: GlassAppBar(
        title: _isSearchActive
            ? SearchBarSticky(
                controller: _searchController,
                hint: AppL10n.of(context).trashSearchHint,
                onSearch: (query) {
                  setState(() => _searchQuery = query);
                },
                autoFocus: true,
              )
            : Row(
                children: [
                  Icon(Icons.delete_rounded, color: cs.error, size: 20),
                  const SizedBox(width: 8),
                  Text(AppL10n.of(context).trashTitle),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: AppL10n.of(context).commonSearch,
                    onPressed: () {
                      setState(() => _isSearchActive = !_isSearchActive);
                    },
                  ),
                ],
              ),
      ),
      body: Consumer<FilterService>(
        builder: (context, filterService, _) {
          return StreamBuilder<List<NoteWithDetails>>(
            stream: DriftNoteService.watchDeletedNotesV2(
              searchQuery: _searchQuery,
              sortType: 'updatedAt',
              sortDirection: 'desc',
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: AppL10n.of(context).trashLoadError,
                  message: AppL10n.of(context).commonTryAgainLater,
                );
              }

              final notes = snapshot.data ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text(
                          AppL10n.of(context).trashTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TagChip(
                          label: '${notes.length}',
                          color: cs.error,
                          size: TagChipSize.small,
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: notes.isEmpty
                        ? EmptyState(
                            icon: Icons.delete_outline_rounded,
                            title: AppL10n.of(context).trashEmpty,
                            message:
                                AppL10n.of(context).trashEmptyHint,
                          )
                        : AnimatedListStagger(
                            itemCount: notes.length,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemBuilder: (context, index) {
                              final note = notes[index];
                              final n = note.note;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _TrashedNoteCard(
                                  note: note,
                                  onTap: () {
                                    PinpointHaptics.medium();
                                    context.push(
                                      CreateNoteScreenV2.kRouteName,
                                      extra: CreateNoteScreenArguments(
                                        noticeType: n.noteType,
                                        existingNote: note,
                                      ),
                                    );
                                  },
                                  onRestore: () async {
                                    final confirmed = await ConfirmSheet.show(
                                      context: context,
                                      title: AppL10n.of(context).trashRestoreTitle,
                                      message:
                                          AppL10n.of(context).trashRestoreBody,
                                      primaryLabel: AppL10n.of(context).trashRestore,
                                      secondaryLabel: AppL10n.of(context).commonCancel,
                                      isDestructive: false,
                                      icon: Icons.restore_from_trash_rounded,
                                    );
                                    if (confirmed == true) {
                                      PinpointHaptics.light();
                                      await DriftNoteService.restoreNoteByIdV2(
                                          n.id, n.noteType);
                                      getIt<AnalyticsFacade>().trackNoteRestoredFromTrash();
                                    }
                                  },
                                  onDelete: () async {
                                    final confirmed = await ConfirmSheet.show(
                                      context: context,
                                      title: AppL10n.of(context).trashDeleteForeverTitle,
                                      message:
                                          AppL10n.of(context).trashDeleteForeverBody,
                                      primaryLabel: AppL10n.of(context).trashDeleteForever,
                                      secondaryLabel: AppL10n.of(context).commonCancel,
                                      isDestructive: true,
                                      icon: Icons.delete_forever_rounded,
                                    );
                                    if (confirmed == true) {
                                      PinpointHaptics.success();
                                      await DriftNoteService
                                          .permanentlyDeleteNoteByIdV2(
                                              n.id, n.noteType);
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TrashedNoteCard extends StatefulWidget {
  final NoteWithDetails note;
  final VoidCallback onTap;
  final Future<void> Function() onRestore;
  final Future<void> Function() onDelete;

  const _TrashedNoteCard({
    required this.note,
    required this.onTap,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  State<_TrashedNoteCard> createState() => _TrashedNoteCardState();
}

class _TrashedNoteCardState extends State<_TrashedNoteCard> {
  bool _pressed = false;
  bool _isLoading = false;

  IconData _getNoteTypeIcon(String noteType) {
    switch (noteType) {
      case 'text':
      case 'title_content':
        return Icons.description_rounded;
      case 'todo':
      case 'todo_list':
        return Icons.checklist_rounded;
      case 'voice':
      case 'voice_recording':
      case 'audio':
        return Icons.mic_rounded;
      case 'reminder':
        return Icons.alarm_rounded;
      case 'drawing':
        return Icons.brush_rounded;
      default:
        return Icons.note_rounded;
    }
  }

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    final l10n = AppL10n.of(context);
    if (difference.inSeconds < 60) {
      return l10n.relativeTimeJustNow;
    } else if (difference.inMinutes < 60) {
      return l10n.relativeTimeMinutesAgo(difference.inMinutes);
    } else if (difference.inHours < 24) {
      return l10n.relativeTimeHoursAgo(difference.inHours);
    } else if (difference.inDays < 7) {
      return l10n.relativeTimeDaysAgo(difference.inDays);
    } else if (difference.inDays < 30) {
      return l10n.relativeTimeWeeksAgo((difference.inDays / 7).floor());
    } else {
      return LocalizedDates.monthDay(context, dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final n = widget.note.note;

    return GestureDetector(
      onTapDown: _isLoading ? null : (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: _isLoading
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onTap();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: PinpointAnimations.durationFast,
        curve: PinpointAnimations.emphasized,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: PinpointElevations.lg(theme.brightness),
          ),
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 20,
            child: Row(
              children: [
                // Leading icon
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.error.withAlpha(dark ? 45 : 35),
                        cs.error.withAlpha(dark ? 25 : 20),
                      ],
                    ),
                    border: Border.all(
                      color: cs.error.withAlpha(dark ? 60 : 50),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cs.error.withAlpha(dark ? 25 : 15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _getNoteTypeIcon(n.noteType),
                      color: cs.error,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      if ((n.noteTitle ?? '').isNotEmpty)
                        Text(
                          n.noteTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.1,
                          ),
                        ),

                      // Content preview
                      if ((widget.note.textContent ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            widget.note.textContent!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface.withAlpha(180),
                              height: 1.4,
                            ),
                          ),
                        ),

                      // Metadata row
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Deletion timestamp
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 13,
                                  color: cs.error.withAlpha(180),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  AppL10n.of(context).trashDeletedAgo(_getRelativeTime(n.updatedAt)),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.error.withAlpha(180),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),

                            // Todo items count
                            if (widget.note.todoItems.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.checklist_rounded,
                                    size: 13,
                                    color: cs.onSurface.withAlpha(120),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.note.todoItems.length}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurface.withAlpha(120),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),

                            // Attachments count
                            if (widget.note.attachments.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.attach_file_rounded,
                                    size: 13,
                                    color: cs.onSurface.withAlpha(120),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.note.attachments.length}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurface.withAlpha(120),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Actions
                _isLoading
                    ? SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Restore button
                          GestureDetector(
                            onTap: () async {
                              setState(() => _isLoading = true);
                              try {
                                await widget.onRestore();
                              } finally {
                                if (mounted) {
                                  setState(() => _isLoading = false);
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: cs.primary.withAlpha(dark ? 40 : 30),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: cs.primary.withAlpha(dark ? 80 : 60),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                Icons.restore_from_trash_rounded,
                                color: cs.primary,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Delete button
                          GestureDetector(
                            onTap: () async {
                              setState(() => _isLoading = true);
                              try {
                                await widget.onDelete();
                              } finally {
                                if (mounted) {
                                  setState(() => _isLoading = false);
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: cs.error.withAlpha(dark ? 40 : 30),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: cs.error.withAlpha(dark ? 80 : 60),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                Icons.delete_forever_rounded,
                                color: cs.error,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
