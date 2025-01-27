import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:pinpoint/components/home_screen/note_types/title_content_type.dart';
import 'package:pinpoint/components/home_screen/note_types/todo_list_type.dart';
import 'package:pinpoint/components/home_screen/note_types/voice_recorder_type.dart';

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
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: MasonryGridView.builder(
                  gridDelegate:
                      const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                  ),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  itemCount: 25,
                  itemBuilder: (context, index) {
                    switch (index) {
                      case 0:
                        return VoiceRecorderType();
                      case 1:
                        return TitleContentType();
                      case 2:
                        return TodoListType();
                      default:
                        return SizedBox.shrink();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
