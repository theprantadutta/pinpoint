import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/models/note_with_details.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';
import 'package:pinpoint/screens/create_note_screen.dart';
import 'package:pinpoint/services/drift_note_service.dart';
import '../design_system/design_system.dart';

class ArchiveScreen extends StatelessWidget {
  static const String kRouteName = '/archive';

  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GradientScaffold(
      appBar: GlassAppBar(
        title: Row(
          children: [
            Icon(Icons.archive_rounded, color: cs.primary, size: 20),
            const SizedBox(width: 8),
            const Text('Archive'),
          ],
        ),
      ),
      body: StreamBuilder<List<NoteWithDetails>>(
        stream: DriftNoteService.watchArchivedNotes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Error loading archived notes',
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
                      'Archive',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TagChip(
                      label: '${notes.length}',
                      color: cs.primary,
                      size: TagChipSize.small,
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: notes.isEmpty
                    ? EmptyState(
                        icon: Icons.archive_outlined,
                        title: 'No archived notes',
                        message:
                            'Notes you archive will appear here for safekeeping',
                      )
                    : AnimatedListStagger(
                        itemCount: notes.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final note = notes[index];
                          final n = note.note;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ArchivedNoteCard(
                              note: note,
                              onTap: () {
                                PinpointHaptics.medium();
                                context.push(
                                  CreateNoteScreen.kRouteName,
                                  extra: CreateNoteScreenArguments(
                                    noticeType: n.defaultNoteType,
                                    existingNote: note,
                                  ),
                                );
                              },
                              onUnarchive: () async {
                                PinpointHaptics.light();
                                await DriftNoteService.toggleArchiveStatus(
                                    n.id, false);
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

class _ArchivedNoteCard extends StatefulWidget {
  final NoteWithDetails note;
  final VoidCallback onTap;
  final VoidCallback onUnarchive;
  final VoidCallback onDelete;

  const _ArchivedNoteCard({
    required this.note,
    required this.onTap,
    required this.onUnarchive,
    required this.onDelete,
  });

  @override
  State<_ArchivedNoteCard> createState() => _ArchivedNoteCardState();
}

class _ArchivedNoteCardState extends State<_ArchivedNoteCard> {
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
                        cs.primary.withAlpha(dark ? 56 : 40),
                        cs.primary.withAlpha(dark ? 25 : 20),
                      ],
                    ),
                    border: Border.all(
                      color: (dark ? Colors.white : Colors.black).withAlpha(20),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.archive_rounded,
                      color: cs.primary,
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
                      if ((n.contentPlainText ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            n.contentPlainText!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface.withAlpha(200),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: widget.onUnarchive,
                      child: GlassContainer(
                        padding: const EdgeInsets.all(10),
                        borderRadius: 12,
                        child: Icon(
                          Icons.unarchive_rounded,
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
