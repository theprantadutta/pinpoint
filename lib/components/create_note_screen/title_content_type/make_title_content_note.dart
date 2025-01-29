import 'package:flutter/material.dart';
import 'package:pinpoint/components/create_note_screen/title_content_type/content_quill.dart';
import 'package:pinpoint/components/create_note_screen/title_content_type/note_input_field.dart';

class MakeTitleContentNote extends StatefulWidget {
  const MakeTitleContentNote({super.key});

  @override
  State<MakeTitleContentNote> createState() => _MakeTitleContentNoteState();
}

class _MakeTitleContentNoteState extends State<MakeTitleContentNote> {
  late TextEditingController _titleEditingController;

  @override
  void initState() {
    _titleEditingController = TextEditingController(text: '');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(
          top: 10,
          left: 10,
          right: 10,
        ),
        child: Column(
          children: [
            NoteInputField(
              title: 'Title',
              textEditingController: _titleEditingController,
            ),
            ContentQuill(),
          ],
        ),
      ),
    );
  }
}
