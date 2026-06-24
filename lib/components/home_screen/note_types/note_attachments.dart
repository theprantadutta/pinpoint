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
        if (!file.existsSync()) {
          return const Placeholder();
        }

        // Decode the bitmap at (roughly) its on-screen size instead of full
        // camera resolution. Without cacheWidth/cacheHeight, Image.file decodes
        // the original (e.g. 12MP ≈ 48MB RGBA) into the image cache even though
        // it renders only ~150px tall — a handful of these across the note grid
        // exhausts the heap and triggers Out-Of-Memory crashes.
        final dpr = MediaQuery.devicePixelRatioOf(context);
        return LayoutBuilder(
          builder: (context, constraints) {
            final targetHeightPx =
                (NoteAttachments.kDefaultHeight * dpr).round();
            final targetWidthPx = constraints.maxWidth.isFinite
                ? (constraints.maxWidth * dpr).round()
                : null;
            return ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.file(
                file,
                height: NoteAttachments.kDefaultHeight.toDouble(),
                width: double.infinity,
                fit: BoxFit.cover,
                cacheHeight: targetHeightPx,
                cacheWidth: targetWidthPx,
                // Keep memory bounded even if a frame fails to decode.
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) =>
                    const Placeholder(),
              ),
            );
          },
        );
      },
    );
  }
}
