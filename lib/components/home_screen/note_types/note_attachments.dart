import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pinpoint/services/drift_note_service.dart';

class NoteAttachments extends StatelessWidget {
  static const kDefaultHeight = 150;
  final int noteId;

  const NoteAttachments({
    super.key,
    required this.noteId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: DriftNoteService.watchNoteAttachmentsById(noteId),
      builder: (context, snapshot) {
        final data = snapshot.data ?? []; // Ensure data is not null

        // ❌ REMOVE this check (it prevents the UI from updating)
        // if (snapshot.connectionState != ConnectionState.done) {
        //   return SizedBox.shrink();
        // }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator(); // Show a loader if waiting
        }

        if (data.isEmpty) {
          return SizedBox.shrink();
        }

        final file = File(data[0].attachmentPath);
        return file.existsSync()
            ? ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.file(
                  file,
                  height: NoteAttachments.kDefaultHeight.toDouble(),
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            : const Placeholder();
      },
    );
  }
}
