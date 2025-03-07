import 'package:flutter/material.dart';
import 'package:pinpoint/components/home_screen/note_types/note_attachments.dart';
import 'package:pinpoint/database/database.dart';

class TitleContentType extends StatelessWidget {
  final Note note;
  const TitleContentType({
    super.key,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    // print('path: ${note.}');
    return Container(
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
                if (note.title != null)
                  Text(
                    note.title!,
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
    );
  }
}
