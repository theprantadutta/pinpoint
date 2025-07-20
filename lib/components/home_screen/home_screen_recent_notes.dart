import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:pinpoint/components/home_screen/note_grid_item.dart';
import 'package:pinpoint/components/shared/empty_state_widget.dart';

import '../../models/note_with_details.dart';
import '../../services/drift_note_service.dart';

class HomeScreenRecentNotes extends StatelessWidget {
  final String searchQuery;
  const HomeScreenRecentNotes({super.key, required this.searchQuery});

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
                stream: DriftNoteService.watchNotesWithDetails(searchQuery),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Something went wrong'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return EmptyStateWidget(message: 'No notes found', iconData: Icons.note_add);
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
                        return NoteGridItem(
                          noteWithDetails: noteWithDetails,
                        );
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
