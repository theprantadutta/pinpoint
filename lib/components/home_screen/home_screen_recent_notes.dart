import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../components/home_screen/note_types/title_content_type.dart';
import '../../models/note_with_details.dart';
import '../../services/drift_note_service.dart';

class HomeScreenRecentNotes extends StatelessWidget {
  const HomeScreenRecentNotes({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Recent Notes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            Expanded(
              child: StreamBuilder<List<NoteWithDetails>>(
                // stream: DriftNoteService.getNoteViewData(),
                stream: DriftNoteService.watchNotesWithDetails(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    print(snapshot.error);
                    return Center(child: Text('Something went wrong'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('No notes found'));
                  }
                  final data = snapshot.data!;
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: MasonryGridView.builder(
                      gridDelegate:
                          SliverSimpleGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                      ),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        final noteWithDetails = data[index];
                        // switch (note.defaultNoteType) {
                        //   case 'Title Content':
                        return TitleContentType(
                          noteWithDetails: noteWithDetails,
                        );
                        // case 1:
                        //   return VoiceRecorderType ();
                        // case 2:
                        //   return TodoListType();
                        // default:
                        //   return SizedBox.shrink();
                        // }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
