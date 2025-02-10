import 'package:flutter/material.dart';
import 'package:pinpoint/components/create_note_screen/title_content_type/content_quill.dart';

class MakeTitleContentNote extends StatefulWidget {
  const MakeTitleContentNote({super.key});

  @override
  State<MakeTitleContentNote> createState() => _MakeTitleContentNoteState();
}

class _MakeTitleContentNoteState extends State<MakeTitleContentNote> {
  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(
          left: 10,
          right: 10,
        ),
        child: ContentQuill(),
      ),
    );
  }
}
