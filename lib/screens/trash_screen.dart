import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:pinpoint/components/home_screen/note_grid_item.dart';
import 'package:pinpoint/components/shared/empty_state_widget.dart';
import 'package:pinpoint/models/note_with_details.dart';
import 'package:pinpoint/services/drift_note_service.dart';

class TrashScreen extends StatelessWidget {
  static const String kRouteName = '/trash';

  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<NoteWithDetails>>(
        stream: DriftNoteService.watchDeletedNotes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const EmptyStateWidget(
              message: 'Trash is empty.',
              iconData: Icons.delete_outline,
            );
          }
          final notes = snapshot.data!;
          return MasonryGridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
            ),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            itemCount: notes.length,
            itemBuilder: (context, index) {
              return NoteGridItem(
                noteWithDetails: notes[index],
                isArchivedView: true, // Reusing for now, will adjust later if needed
              );
            },
          );
        },
      ),
    );
  }
}
