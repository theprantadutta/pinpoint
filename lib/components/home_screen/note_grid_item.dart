import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/models/note_with_details.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';
import 'package:pinpoint/screens/create_note_screen.dart';
import 'package:pinpoint/services/drift_note_service.dart';

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
    final kPrimaryColor = Theme.of(context).primaryColor;
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
      child: Container(
        decoration: BoxDecoration(
          color: kPrimaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (noteWithDetails.note.noteTitle != null &&
                      noteWithDetails.note.noteTitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, right: 24.0),
                      child: Text(
                        noteWithDetails.note.noteTitle!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
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
                        color: colorScheme.onSurface.withAlpha(180),
                      ),
                      maxLines: 10,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (noteWithDetails.folders.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6.0,
                      runSpacing: 6.0,
                      children: noteWithDetails.folders.map((folder) {
                        return Chip(
                          label: Text(folder.title),
                          // backgroundColor: colorScheme.secondaryContainer,
                          labelStyle: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSecondaryContainer,
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
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6.0,
                      runSpacing: 6.0,
                      children: noteWithDetails.tags.map((tag) {
                        return Chip(
                          label: Text(tag.tagTitle),
                          labelStyle: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                          ),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                  if (isArchivedView) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(Icons.unarchive, color: colorScheme.onSurface.withAlpha(150)),
                          onPressed: () {
                            DriftNoteService.toggleArchiveStatus(noteWithDetails.note.id, false);
                          },
                          tooltip: 'Unarchive',
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_forever, color: colorScheme.error),
                          onPressed: () {
                            DriftNoteService.permanentlyDeleteNoteById(noteWithDetails.note.id);
                          },
                          tooltip: 'Delete permanently',
                        ),
                      ],
                    )
                  ],
                  if (isTrashView) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(Icons.restore_from_trash, color: colorScheme.primary),
                          onPressed: () {
                            DriftNoteService.restoreNoteById(noteWithDetails.note.id);
                          },
                          tooltip: 'Restore',
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_forever, color: colorScheme.error),
                          onPressed: () {
                            DriftNoteService.permanentlyDeleteNoteById(noteWithDetails.note.id);
                          },
                          tooltip: 'Delete permanently',
                        ),
                      ],
                    )
                  ]
                ],
              ),
            ),
            if (!isArchivedView)
              Positioned(
                top: 8,
                right: 40, // Adjusted right to make space for pin icon
                child: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'pin') {
                      DriftNoteService.togglePinStatus(noteWithDetails.note.id, !isPinned);
                    } else if (value == 'archive') {
                      DriftNoteService.toggleArchiveStatus(noteWithDetails.note.id, true);
                    } else if (value == 'trash') {
                      DriftNoteService.softDeleteNoteById(noteWithDetails.note.id);
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
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
                ),
              ),
            if (!isArchivedView && isPinned) // Only show pin icon if not archived and is pinned
              Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.push_pin,
                  size: 20,
                  color: colorScheme.primary, // Use primary color for visibility
                ),
              ),
          ],
        ),
      ),
    );
  }
}
