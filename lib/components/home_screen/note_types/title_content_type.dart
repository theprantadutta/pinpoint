import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/components/home_screen/note_types/note_attachments.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';
import 'package:pinpoint/screens/create_note_screen.dart';

import '../../../constants/constants.dart';
import '../../../models/note_with_details.dart';

class TitleContentType extends StatelessWidget {
  final NoteWithDetails noteWithDetails;

  const TitleContentType({
    super.key,
    required this.noteWithDetails,
  });

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final note = noteWithDetails.note;
    return GestureDetector(
      onTap: () => context.push(
        CreateNoteScreen.kRouteName,
        extra: CreateNoteScreenArguments(
          noticeType: kNoteTypes[0],
          existingNote: noteWithDetails,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: kPrimaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            NoteAttachments(noteId: note.id),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 10,
              ),
              child: Column(
                spacing: 5,
                children: [
                  if (note.noteTitle != null)
                    Text(
                      note.noteTitle!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (note.contentPlainText != null)
                    Text(
                      note.contentPlainText!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkTheme
                            ? Colors.grey.shade200
                            : Colors.grey.shade700,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
