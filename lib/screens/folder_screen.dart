import 'package:flutter/material.dart';
import 'package:pinpoint/components/home_screen/home_screen_recent_notes.dart';
import 'package:pinpoint/components/shared/empty_state_widget.dart';
import 'package:pinpoint/models/note_with_details.dart';
import 'package:pinpoint/services/drift_note_service.dart';

class FolderScreen extends StatelessWidget {
  static const String kRouteName = '/folder';
  final int folderId;
  final String folderTitle;

  const FolderScreen({
    super.key,
    required this.folderId,
    required this.folderTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(folderTitle),
        centerTitle: true,
      ),
      body: StreamBuilder<List<NoteWithDetails>>(
        stream: DriftNoteService.watchNotesWithDetailsByFolder(folderId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final notes = snapshot.data ?? const <NoteWithDetails>[];
          if (notes.isEmpty) {
            return const EmptyStateWidget(
              message: 'No notes in this folder yet.',
              iconData: Icons.folder_open,
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
              itemCount: notes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return NoteListItem(note: notes[index]);
              },
            ),
          );
        },
      ),
    );
  }
}
