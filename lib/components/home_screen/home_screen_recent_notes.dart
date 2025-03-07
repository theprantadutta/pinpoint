import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../components/home_screen/note_types/title_content_type.dart';
import '../../database/database.dart';
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
            // StreamBuilder(
            //   stream: () => DriftNoteService.watchRecentNotes(),
            //   builder: (context, snapshot) {
            //     if (snapshot.connectionState == ConnectionState.waiting) {
            //       return Expanded(
            //           child: Center(
            //         child: CircularProgressIndicator(),
            //       ));
            //     }
            //     if (snapshot.hasError) {
            //       return Expanded(child: Text('Something Went wrong'));
            //     }
            //     return Expanded(
            //       child: Padding(
            //         padding: const EdgeInsets.symmetric(vertical: 8.0),
            //         child: MasonryGridView.builder(
            //           gridDelegate:
            //               const SliverSimpleGridDelegateWithFixedCrossAxisCount(
            //             crossAxisCount: 2,
            //           ),
            //           crossAxisSpacing: 10,
            //           mainAxisSpacing: 10,
            //           itemCount: 25,
            //           itemBuilder: (context, index) {
            //             switch (index) {
            //               case 0:
            //                 return VoiceRecorderType();
            //               case 1:
            //                 return TitleContentType();
            //               case 2:
            //                 return TodoListType();
            //               default:
            //                 return SizedBox.shrink();
            //             }
            //           },
            //         ),
            //       ),
            //     );
            //   },
            // ),
            Expanded(
              child: StreamBuilder<List<Note>>(
                stream: DriftNoteService.watchRecentNotes(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Something went wrong'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('No notes found'));
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: MasonryGridView.builder(
                      gridDelegate:
                          const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                      ),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final note = snapshot.data![index];
                        switch (note.defaultNoteType) {
                          case 'Title Content':
                            return TitleContentType(
                              note: note,
                            );
                          // case 1:
                          //   return VoiceRecorderType ();
                          // case 2:
                          //   return TodoListType();
                          default:
                            return SizedBox.shrink();
                        }
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
