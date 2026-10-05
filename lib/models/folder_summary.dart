import 'package:flutter/material.dart';

import '../database/database.dart';

/// One note as listed inside a folder preview.
class FolderNotePreview {
  const FolderNotePreview({
    required this.noteId,
    required this.type,
    required this.title,
    required this.color,
  });

  final int noteId;

  /// 'text' | 'voice' | 'todo' | 'reminder'
  final String type;

  /// Title, or the start of the body when untitled. May be empty.
  final String title;

  /// Bullet colour: the note's pastel, or its type pastel.
  final Color color;
}

/// A folder with what the Sketchbook folder UI shows about it.
class FolderSummary {
  const FolderSummary({
    required this.folder,
    required this.color,
    required this.noteCount,
    required this.voiceCount,
    required this.recent,
  });

  final NoteFolder folder;

  /// The folder's pastel (stored, or resolved round-robin).
  final Color color;

  /// Live notes (not archived, not trashed) in the folder.
  final int noteCount;
  final int voiceCount;

  /// Most recently edited notes first; at most [FolderSummary.previewLimit].
  final List<FolderNotePreview> recent;

  int get id => folder.noteFolderId;
  String get title => folder.noteFolderTitle;

  static const int previewLimit = 4;
}
