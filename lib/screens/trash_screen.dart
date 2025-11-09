import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/models/note_with_details.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';
import 'package:pinpoint/screens/create_note_screen.dart';
import 'package:pinpoint/services/drift_note_service.dart';
import '../design_system/design_system.dart';

class TrashScreen extends StatelessWidget {
  static const String kRouteName = '/trash';

  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GradientScaffold(
      appBar: GlassAppBar(
        title: Row(
          children: [
            Icon(Icons.delete_rounded, color: cs.error, size: 20),
            const SizedBox(width: 8),
            const Text('Trash'),
          ],
        ),
      ),
      body: StreamBuilder<List<NoteWithDetails>>(
        stream: DriftNoteService.watchDeletedNotes(),
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
                        message: 'Deleted notes will appear here temporarily',
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
                                PinpointHaptics.light();
                                await DriftNoteService.restoreNoteById(n.id);
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
      ),
    );
  }
}

class _TrashedNoteCard extends StatefulWidget {
  final NoteWithDetails note;
  final VoidCallback onTap;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final n = widget.note.note;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
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
                        cs.error.withAlpha(dark ? 56 : 40),
                        cs.error.withAlpha(dark ? 25 : 20),
                      ],
                    ),
                    border: Border.all(
                      color: (dark ? Colors.white : Colors.black).withAlpha(20),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.delete_rounded,
                      color: cs.error,
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
                      // TODO: Load and display content from TextNotes table
                      // if ((content ?? '').isNotEmpty)
                      //   Padding(
                      //     padding: const EdgeInsets.only(top: 4),
                      //     child: Text(
                      //       content!,
                      //       maxLines: 2,
                      //       overflow: TextOverflow.ellipsis,
                      //       style: theme.textTheme.bodyMedium?.copyWith(
                      //         color: cs.onSurface.withAlpha(200),
                      //       ),
                      //     ),
                      //   ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: widget.onRestore,
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
                      onTap: widget.onDelete,
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
