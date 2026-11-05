import '../models/note_with_details.dart';

class CreateNoteScreenArguments {
  final NoteWithDetails? existingNote;
  final String noticeType;

  /// Voice notes only: start recording as soon as the editor opens (the
  /// microphone button in the text editor opens a new voice note this way).
  final bool autoStartRecording;

  /// A new note's starting body, from the share sheet.
  final String? initialText;

  /// Files to attach to a new note, from the share sheet.
  final List<({String path, String name})> initialFiles;

  const CreateNoteScreenArguments({
    this.existingNote,
    required this.noticeType,
    this.autoStartRecording = false,
    this.initialText,
    this.initialFiles = const [],
  });
}
