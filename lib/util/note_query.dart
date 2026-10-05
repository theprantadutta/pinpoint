import '../models/filter_options.dart';
import '../models/note_with_details.dart';
import '../services/filter_service.dart';

/// Applies the Filters sheet to an in-memory note list.
///
/// The note streams are already decrypted, local and small, so filtering here
/// (rather than in SQL) keeps every list — home, all notes, a folder — and the
/// sheet's live "Show N notes" count on one definition of what matches.
class NoteQuery {
  NoteQuery._();

  /// Canonical type key: the streams say 'voice', legacy filters 'audio'.
  static String typeKey(String noteType) =>
      noteType == 'audio' ? 'voice' : noteType;

  /// Notes in [notes] matching [filters], ordered by [sort] with pinned
  /// notes first.
  static List<NoteWithDetails> apply(
    List<NoteWithDetails> notes,
    FilterOptions filters, {
    NoteSort sort = NoteSort.lastEdited,
    bool pinnedFirst = true,
  }) {
    final types = filters.noteTypes.map(typeKey).toSet();
    final folders = filters.folderIds.toSet();
    final start = filters.dateRangeStart;
    final end = filters.dateRangeEnd;

    final result = notes.where((n) {
      final note = n.note;
      if (note.isDeleted) return false;
      if (note.isArchived && !filters.includeArchived) return false;
      if (filters.pinsOnly && !note.isPinned) return false;
      if (types.isNotEmpty && !types.contains(typeKey(note.noteType))) {
        return false;
      }
      if (folders.isNotEmpty && !n.folders.any((f) => folders.contains(f.id))) {
        return false;
      }
      if (start != null && note.updatedAt.isBefore(start)) return false;
      if (end != null &&
          note.updatedAt.isAfter(end.add(const Duration(days: 1)))) {
        return false;
      }
      return true;
    }).toList();

    int byField(NoteWithDetails a, NoteWithDetails b) => switch (sort) {
          NoteSort.lastEdited => b.note.updatedAt.compareTo(a.note.updatedAt),
          NoteSort.dateCreated => b.note.createdAt.compareTo(a.note.createdAt),
          NoteSort.titleAz => _title(a).compareTo(_title(b)),
        };

    result.sort((a, b) {
      if (pinnedFirst && a.note.isPinned != b.note.isPinned) {
        return a.note.isPinned ? -1 : 1;
      }
      return byField(a, b);
    });
    return result;
  }

  static String _title(NoteWithDetails n) {
    final t = n.note.noteTitle?.trim();
    final s = (t == null || t.isEmpty) ? (n.textContent ?? '') : t;
    return s.trim().toLowerCase();
  }
}
