import 'package:flutter/material.dart';

import '../database/database.dart';
import '../design_system/colors.dart';

/// Folder colours and order for the Sketchbook folder UI.
///
/// A folder stores a pastel name (schema v12). Folders from before v12, or
/// written by an older client, have none: those resolve round-robin in
/// creation order — `createdAt`, then `uuid` — which is the same on every
/// device because both values sync. Nothing is written to resolve a colour,
/// so viewing never creates sync traffic.
class FolderPalette {
  FolderPalette._();

  /// Pastel per folder id, for every folder in [folders].
  static Map<int, Color> resolve(Iterable<NoteFolder> folders) {
    final byCreation = folders.toList()..sort(_creationOrder);
    final result = <int, Color>{};
    for (var i = 0; i < byCreation.length; i++) {
      final f = byCreation[i];
      result[f.noteFolderId] = SketchPastels.byName(f.color) ??
          SketchPastels.roundRobin[i % SketchPastels.roundRobin.length];
    }
    return result;
  }

  /// The colour name a newly created folder should take, given how many
  /// folders exist before it.
  static String nameForNewFolder(int existingCount) =>
      SketchPastels.names[existingCount % SketchPastels.names.length];

  /// Display order: manual [NoteFolder.sortOrder] first, then creation.
  static List<NoteFolder> ordered(Iterable<NoteFolder> folders) {
    return folders.toList()
      ..sort((a, b) {
        final ao = a.sortOrder, bo = b.sortOrder;
        if (ao != null && bo != null && ao != bo) return ao.compareTo(bo);
        if (ao != null && bo == null) return -1;
        if (ao == null && bo != null) return 1;
        return _creationOrder(a, b);
      });
  }

  static int _creationOrder(NoteFolder a, NoteFolder b) {
    final c = a.createdAt.compareTo(b.createdAt);
    return c != 0 ? c : a.uuid.compareTo(b.uuid);
  }

  /// The pastel a note shows as a bullet: its own colour, or — when it has
  /// none — the pastel of its type, matching the Filters sheet (Text yellow,
  /// Checklist mint, Voice sky, Reminder lavender).
  static Color forNote({String? colorName, required String type}) {
    final own = NoteSwatch.resolve(colorName)?.color;
    if (own != null) return own;
    return typePastel(type);
  }

  static Color typePastel(String type) => switch (type) {
        'todo' => SketchPastels.mint,
        'voice' || 'audio' => SketchPastels.sky,
        'reminder' => SketchPastels.lavender,
        _ => SketchPastels.yellow,
      };
}
