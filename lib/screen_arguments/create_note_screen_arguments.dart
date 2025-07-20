import 'package:pinpoint/entities/note_tags.dart';

import '../models/note_with_details.dart';

class CreateNoteScreenArguments {
  final NoteWithDetails? existingNote;
  final String noticeType;
  final List<NoteTag> existingTags;

  const CreateNoteScreenArguments({
    this.existingNote,
    required this.noticeType,
    this.existingTags = const [],
  });
}
