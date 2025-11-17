import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../dtos/note_folder_dto.dart';
import '../service_locators/init_service_locators.dart';
import '../sync/sync_manager.dart';

/// Service for managing text notes with markdown support
/// Part of Architecture V8: Independent note types
class TextNoteService {
  TextNoteService._();

  /// Trigger background sync (non-blocking)
  static void _triggerBackgroundSync() {
    // Add delay to ensure current database transaction completes
    Future.delayed(const Duration(seconds: 1), () async {
      try {
        final syncManager = getIt<SyncManager>();
        debugPrint('🔄 [TextNoteService] Triggering background sync...');
        await syncManager.upload();
        debugPrint('✅ [TextNoteService] Background sync completed');
      } catch (e) {
        debugPrint('⚠️ [TextNoteService] Background sync failed: $e');
        // Don't throw - sync failure shouldn't break note saving
      }
    });
  }

  /// Create a new text note
  ///
  /// IMPORTANT: folders parameter is REQUIRED (mandatory folders)
  /// If empty, defaults to "Random" folder
  static Future<int> createTextNote({
    required String title,
    required String content,
    required List<NoteFolderDto> folders,
    bool isPinned = false,
  }) async {
    try {
      final database = getIt<AppDatabase>();
      final now = DateTime.now();
      const uuid = Uuid();

      // Validate folders (must have at least one)
      if (folders.isEmpty) {
        throw Exception('Text note must belong to at least one folder');
      }

      // Create text note
      final textNoteId = await database.into(database.textNotesV2).insert(
        TextNotesV2Companion(
          uuid: Value(uuid.v4()),
          title: Value(title),
          content: Value(content),
          isPinned: Value(isPinned),
          isArchived: const Value(false),
          isDeleted: const Value(false),
          isSynced: const Value(false), // Needs cloud sync
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Link to folders
      await _linkToFolders(textNoteId, folders);

      debugPrint('✅ [TextNoteService] Created text note: $textNoteId with ${folders.length} folders');

      // Trigger background sync
      _triggerBackgroundSync();

      return textNoteId;
    } catch (e, st) {
      debugPrint('❌ [TextNoteService] Failed to create text note: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Update an existing text note
  static Future<void> updateTextNote({
    required int noteId,
    String? title,
    String? content,
    List<NoteFolderDto>? folders,
    bool? isPinned,
  }) async {
    try {
      final database = getIt<AppDatabase>();
      final now = DateTime.now();

      // Build update companion
      final companion = TextNotesV2Companion(
        title: title != null ? Value(title) : const Value.absent(),
        content: content != null ? Value(content) : const Value.absent(),
        isPinned: isPinned != null ? Value(isPinned) : const Value.absent(),
        isSynced: const Value(false), // Mark for sync
        updatedAt: Value(now),
      );

      // Update note
      await (database.update(database.textNotesV2)
            ..where((t) => t.id.equals(noteId)))
          .write(companion);

      // Update folder relations if provided
      if (folders != null) {
        if (folders.isEmpty) {
          throw Exception('Text note must belong to at least one folder');
        }
        await _updateFolderRelations(noteId, folders);
      }

      debugPrint('✅ [TextNoteService] Updated text note: $noteId');

      // Trigger background sync
      _triggerBackgroundSync();
    } catch (e, st) {
      debugPrint('❌ [TextNoteService] Failed to update text note: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Soft delete a text note
  static Future<void> deleteTextNote(int noteId) async {
    try {
      final database = getIt<AppDatabase>();
      final now = DateTime.now();

      await (database.update(database.textNotesV2)
            ..where((t) => t.id.equals(noteId)))
          .write(
        TextNotesV2Companion(
          isDeleted: const Value(true),
          isSynced: const Value(false), // Mark for sync
          updatedAt: Value(now),
        ),
      );

      debugPrint('✅ [TextNoteService] Soft deleted text note: $noteId');

      // Trigger background sync
      _triggerBackgroundSync();
    } catch (e, st) {
      debugPrint('❌ [TextNoteService] Failed to delete text note: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Permanently delete a text note (hard delete)
  static Future<void> permanentlyDeleteTextNote(int noteId) async {
    try {
      final database = getIt<AppDatabase>();

      // Delete folder relations (cascade)
      await (database.delete(database.textNoteFolderRelationsV2)
            ..where((t) => t.textNoteId.equals(noteId)))
          .go();

      // Delete note
      await (database.delete(database.textNotesV2)
            ..where((t) => t.id.equals(noteId)))
          .go();

      debugPrint('✅ [TextNoteService] Permanently deleted text note: $noteId');
    } catch (e, st) {
      debugPrint('❌ [TextNoteService] Failed to permanently delete text note: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Get a single text note by ID
  static Future<TextNoteEntity?> getTextNote(int noteId) async {
    try {
      final database = getIt<AppDatabase>();
      return await (database.select(database.textNotesV2)
            ..where((t) => t.id.equals(noteId)))
          .getSingleOrNull();
    } catch (e, st) {
      debugPrint('❌ [TextNoteService] Failed to get text note: $e');
      debugPrint('Stack trace: $st');
      return null;
    }
  }

  /// Watch all text notes (excluding deleted)
  static Stream<List<TextNoteEntity>> watchAllTextNotes() {
    final database = getIt<AppDatabase>();
    return (database.select(database.textNotesV2)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm(expression: t.isPinned, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Watch text notes by folder
  static Stream<List<TextNoteEntity>> watchTextNotesByFolder(int folderId) {
    final database = getIt<AppDatabase>();

    // Join with folder relations to filter by folder
    final query = database.select(database.textNotesV2).join([
      innerJoin(
        database.textNoteFolderRelationsV2,
        database.textNoteFolderRelationsV2.textNoteId.equalsExp(database.textNotesV2.id),
      ),
    ])
      ..where(database.textNoteFolderRelationsV2.folderId.equals(folderId))
      ..where(database.textNotesV2.isDeleted.equals(false))
      ..orderBy([
        OrderingTerm(expression: database.textNotesV2.isPinned, mode: OrderingMode.desc),
        OrderingTerm(expression: database.textNotesV2.updatedAt, mode: OrderingMode.desc),
      ]);

    return query.watch().map((rows) => rows.map((row) => row.readTable(database.textNotesV2)).toList());
  }

  /// Link text note to folders
  static Future<void> _linkToFolders(int textNoteId, List<NoteFolderDto> folders) async {
    final database = getIt<AppDatabase>();

    await database.batch((batch) {
      for (final folder in folders) {
        batch.insert(
          database.textNoteFolderRelationsV2,
          TextNoteFolderRelationsV2Companion(
            textNoteId: Value(textNoteId),
            folderId: Value(folder.id),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  /// Update folder relations for a text note
  static Future<void> _updateFolderRelations(int textNoteId, List<NoteFolderDto> folders) async {
    final database = getIt<AppDatabase>();

    await database.transaction(() async {
      // Delete existing relations
      await (database.delete(database.textNoteFolderRelationsV2)
            ..where((t) => t.textNoteId.equals(textNoteId)))
          .go();

      // Add new relations
      await _linkToFolders(textNoteId, folders);
    });
  }
}
