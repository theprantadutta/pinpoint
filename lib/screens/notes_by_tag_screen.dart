import 'package:flutter/material.dart';
import 'package:pinpoint/components/home_screen/home_screen_recent_notes.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/models/note_with_details.dart';
import 'package:pinpoint/services/drift_note_service.dart';

class NotesByTagScreen extends StatelessWidget {
  static const String kRouteName = '/notes-by-tag';
  final NoteTag tag;

  const NotesByTagScreen({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tag: ${tag.tagTitle}'),
      ),
      body: StreamBuilder<List<NoteWithDetails>>(
        stream: DriftNoteService.watchNotesByTag(tag.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final notes = snapshot.data ?? [];
          if (notes.isEmpty) {
            return const Center(child: Text('No notes with this tag yet.'));
          }
          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, index) {
              return NoteListItem(note: notes[index]);
            },
          );
        },
      ),
    );
  }
}
