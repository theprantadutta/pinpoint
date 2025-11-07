import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/database/database.dart' as db;
import 'package:pinpoint/models/note_with_details.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';
import 'package:pinpoint/screens/create_note_screen.dart';
import 'package:pinpoint/services/drift_note_service.dart';
import '../design_system/design_system.dart';

class NotesByTagScreen extends StatelessWidget {
  static const String kRouteName = '/notes-by-tag';
  final db.NoteTag tag;

  const NotesByTagScreen({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagColor = TagColors.getPreset(tag.id % TagColors.presets.length);

    return GradientScaffold(
      appBar: GlassAppBar(
        title: Row(
          children: [
            Icon(Icons.label_rounded, color: tagColor.foreground, size: 20),
            const SizedBox(width: 8),
            Text(tag.tagTitle),
          ],
        ),
      ),
      body: StreamBuilder<List<NoteWithDetails>>(
        stream: DriftNoteService.watchNotesByTag(tag.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Error loading notes',
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
                    TagChip(
                      label: tag.tagTitle,
                      color: tagColor.foreground,
                    ),
                    const SizedBox(width: 8),
                    TagChip(
                      label: '${notes.length} notes',
                      color: theme.colorScheme.primary,
                      size: TagChipSize.small,
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: notes.isEmpty
                    ? EmptyState(
                        icon: Icons.label_outline_rounded,
                        title: 'No notes with this tag',
                        message: 'Add this tag to notes to see them here',
                      )
                    : AnimatedListStagger(
                        itemCount: notes.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final note = notes[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: NoteCard(
                              title: note.note.noteTitle ?? 'Untitled',
                              excerpt: note.note.contentPlainText,
                              lastModified: note.note.updatedAt,
                              isPinned: note.note.isPinned,
                              tags: note.tags
                                  .map((t) => CardNoteTag(
                                        label: t.tagTitle,
                                        color: TagColors.getPreset(
                                                t.id % TagColors.presets.length)
                                            .foreground,
                                      ))
                                  .toList(),
                              onTap: () {
                                PinpointHaptics.medium();
                                context.push(
                                  CreateNoteScreen.kRouteName,
                                  extra: CreateNoteScreenArguments(
                                    noticeType: note.note.defaultNoteType,
                                    existingNote: note,
                                  ),
                                );
                              },
                              onPinToggle: () {
                                PinpointHaptics.light();
                                DriftNoteService.togglePinStatus(
                                  note.note.id,
                                  !note.note.isPinned,
                                );
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
