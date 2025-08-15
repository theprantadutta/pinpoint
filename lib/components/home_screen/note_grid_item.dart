import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/models/note_with_details.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';
import 'package:pinpoint/screens/create_note_screen.dart';
import 'package:pinpoint/services/drift_note_service.dart';
import 'package:pinpoint/design/app_theme.dart';

class NoteGridItem extends StatelessWidget {
  final NoteWithDetails noteWithDetails;
  final bool isArchivedView;
  final bool isTrashView;

  const NoteGridItem({
    super.key,
    required this.noteWithDetails,
    this.isArchivedView = false,
    this.isTrashView = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPinned = noteWithDetails.note.isPinned;

    return GestureDetector(
      onTap: () {
        context.push(
          CreateNoteScreen.kRouteName,
          extra: CreateNoteScreenArguments(
            existingNote: noteWithDetails,
            noticeType: noteWithDetails.note.defaultNoteType,
          ),
        );
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        scale: 1.0,
        child: GlassCard(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (noteWithDetails.note.noteTitle != null &&
                        noteWithDetails.note.noteTitle!.isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: 6.0, right: 24.0),
                        child: Text(
                          noteWithDetails.note.noteTitle!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                            letterSpacing: -0.1,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (noteWithDetails.note.contentPlainText != null &&
                        noteWithDetails.note.contentPlainText!.isNotEmpty)
                      Text(
                        noteWithDetails.note.contentPlainText!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.82),
                          height: 1.28,
                        ),
                        maxLines: 8,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (noteWithDetails.folders.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6.0,
                        runSpacing: 6.0,
                        children: noteWithDetails.folders.map((folder) {
                          return Chip(
                            label: Text(folder.title),
                            labelStyle: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ],
                    if (noteWithDetails.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6.0,
                        runSpacing: 6.0,
                        children: noteWithDetails.tags.map((tag) {
                          return Chip(
                            label: Text(tag.tagTitle),
                            labelStyle: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ],
                    if (isArchivedView || isTrashView) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isArchivedView) ...[
                            _MiniIconChip(
                              icon: Icons.unarchive,
                              tooltip: 'Unarchive',
                              color: colorScheme.primary,
                              onTap: () async {
                                await DriftNoteService.toggleArchiveStatus(
                                    noteWithDetails.note.id, false);
                              },
                            ),
                            const SizedBox(width: 6),
                            _MiniIconChip(
                              icon: Icons.delete_forever,
                              tooltip: 'Delete forever',
                              color: colorScheme.error,
                              destructive: true,
                              onTap: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => _ConfirmDestructiveDialog(
                                    title: 'Delete permanently?',
                                    message:
                                        'This action cannot be undone. The note and its attachments will be removed forever.',
                                    confirmLabel: 'Delete forever',
                                  ),
                                );
                                if (confirmed == true) {
                                  await DriftNoteService
                                      .permanentlyDeleteNoteById(
                                          noteWithDetails.note.id);
                                }
                              },
                            ),
                          ],
                          if (isTrashView) ...[
                            _MiniIconChip(
                              icon: Icons.restore_from_trash,
                              tooltip: 'Restore',
                              color: colorScheme.primary,
                              onTap: () async {
                                await DriftNoteService.restoreNoteById(
                                    noteWithDetails.note.id);
                              },
                            ),
                            const SizedBox(width: 6),
                            _MiniIconChip(
                              icon: Icons.delete_forever,
                              tooltip: 'Delete forever',
                              color: colorScheme.error,
                              destructive: true,
                              onTap: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => _ConfirmDestructiveDialog(
                                    title: 'Delete permanently?',
                                    message:
                                        'This action cannot be undone. The note and its attachments will be removed forever.',
                                    confirmLabel: 'Delete forever',
                                  ),
                                );
                                if (confirmed == true) {
                                  await DriftNoteService
                                      .permanentlyDeleteNoteById(
                                          noteWithDetails.note.id);
                                }
                              },
                            ),
                          ],
                        ],
                      )
                    ]
                  ],
                ),
              ),
              if (!isArchivedView)
                Positioned(
                  top: 8,
                  right: 40,
                  child: PopupMenuButton<String>(
                    tooltip: 'Quick actions',
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (value) {
                      if (value == 'pin') {
                        DriftNoteService.togglePinStatus(
                            noteWithDetails.note.id, !isPinned);
                      } else if (value == 'archive') {
                        DriftNoteService.toggleArchiveStatus(
                            noteWithDetails.note.id, true);
                      } else if (value == 'trash') {
                        DriftNoteService.softDeleteNoteById(
                            noteWithDetails.note.id);
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'pin',
                        child: Text(isPinned ? 'Unpin note' : 'Pin note'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'archive',
                        child: Text('Archive'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'trash',
                        child: Text('Move to trash'),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.more_vert, size: 18),
                    ),
                  ),
                ),
              if (!isArchivedView && isPinned)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.push_pin,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  const GlassCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Glass(
        padding: const EdgeInsets.all(0),
        borderRadius: AppTheme.radiusL,
        child: Container(
          decoration: const BoxDecoration(
            borderRadius: AppTheme.radiusL,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0x1A7C3AED),
                Color(0x1110B981),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _MiniIconChip extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final bool destructive;
  final VoidCallback onTap;

  const _MiniIconChip({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = destructive
        ? color.withValues(alpha: dark ? 0.14 : 0.10)
        : color.withValues(alpha: dark ? 0.12 : 0.08);
    final border = (destructive ? color : Colors.black)
        .withValues(alpha: dark ? 0.20 : 0.10);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.22 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 5),
              )
            ],
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _ConfirmDestructiveDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;

  const _ConfirmDestructiveDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return AlertDialog(
      title: Text(title),
      content: Text(
        message,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: cs.onSurface.withValues(alpha: 0.86)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          style: FilledButton.styleFrom(
            backgroundColor: cs.error.withValues(alpha: 0.14),
            foregroundColor: cs.error,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
