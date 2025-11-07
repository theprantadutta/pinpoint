import 'package:pinpoint/database/database.dart';

import '../models/note_with_details.dart';

class CreateNoteScreenArguments {
  final NoteWithDetails? existingNote;
  final String noticeType;

  const CreateNoteScreenArguments({
    this.existingNote,
    required this.noticeType,
  });
}
