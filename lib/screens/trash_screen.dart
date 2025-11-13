import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/models/note_with_details.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';
import 'package:pinpoint/screens/create_note_screen.dart';
import 'package:pinpoint/services/drift_note_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../design_system/design_system.dart';
import '../services/filter_service.dart';

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
                hint: 'Search trash...',
                onSearch: (query) {
                  setState(() => _searchQuery = query);
                },
                autoFocus: true,
              )
            : Row(
                children: [
                  Icon(Icons.delete_rounded, color: cs.error, size: 20),
                  const SizedBox(width: 8),
                  const Text('Trash'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: 'Search',
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
            stream: DriftNoteService.watchDeletedNotes(
              searchQuery: _searchQuery,
              filterOptions: filterService.filterOptions,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Error loading trash',
                  message: 'Please try again later',
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
                          'Trash',
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
                            title: 'Trash is empty',
                            message:
                                'Deleted notes will appear here temporarily',
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
                                      CreateNoteScreen.kRouteName,
                                      extra: CreateNoteScreenArguments(
                                        noticeType: n.noteType,
                                        existingNote: note,
                                      ),
                                    );
                                  },
                                  onRestore: () async {
                                    final confirmed = await ConfirmSheet.show(
                                      context: context,
                                      title: 'Restore note?',
                                      message:
                                          'This note will be moved back to your notes.',
                                      primaryLabel: 'Restore',
                                      secondaryLabel: 'Cancel',
                                      isDestructive: false,
                                      icon: Icons.restore_from_trash_rounded,
                                    );
                                    if (confirmed == true) {
                                      PinpointHaptics.light();
                                      await DriftNoteService.restoreNoteById(
                                          n.id);
                                    }
                                  },
                                  onDelete: () async {
                                    final confirmed = await ConfirmSheet.show(
                                      context: context,
                                      title: 'Delete permanently?',
                                      message:
                                          'This action cannot be undone. The note and its attachments will be removed forever.',
                                      primaryLabel: 'Delete forever',
                                      secondaryLabel: 'Cancel',
                                      isDestructive: true,
                                      icon: Icons.delete_forever_rounded,
                                    );
                                    if (confirmed == true) {
                                      PinpointHaptics.success();
                                      await DriftNoteService
                                          .permanentlyDeleteNoteById(n.id);
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
      case 'title_content':
        return Icons.description_rounded;
      case 'todo_list':
        return Icons.checklist_rounded;
      case 'voice_recording':
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

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.surfaceContainerHighest.withAlpha(dark ? 80 : 120),
                        cs.surfaceContainerHighest.withAlpha(dark ? 40 : 60),
                      ],
                    ),
                    border: Border.all(
                      color: (dark ? Colors.white : Colors.black).withAlpha(20),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _getNoteTypeIcon(n.noteType),
                      color: cs.onSurfaceVariant,
                      size: 22,
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
                                  'Deleted ${_getRelativeTime(n.updatedAt)}',
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
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                            child: GlassContainer(
                              padding: const EdgeInsets.all(10),
                              borderRadius: 12,
                              child: Icon(
                                Icons.restore_from_trash_rounded,
                                color: cs.primary,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
                            child: GlassContainer(
                              padding: const EdgeInsets.all(10),
                              borderRadius: 12,
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
