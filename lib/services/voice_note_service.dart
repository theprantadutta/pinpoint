import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../dtos/note_folder_dto.dart';
import '../service_locators/init_service_locators.dart';

/// Service for managing voice/audio notes
/// Part of Architecture V8: Independent note types
class VoiceNoteService {
  VoiceNoteService._();

  /// Create a new voice note
  ///
  /// IMPORTANT: folders parameter is REQUIRED (mandatory folders)
  /// If empty, defaults to "Random" folder
  static Future<int> createVoiceNote({
    required String title,
    required String audioFilePath,
    required List<NoteFolderDto> folders,
    int? durationSeconds,
    String? transcription,
    DateTime? recordedAt,
    bool isPinned = false,
  }) async {
    try {
      final database = getIt<AppDatabase>();
      final now = DateTime.now();
      const uuid = Uuid();

      // Validate folders (must have at least one)
      if (folders.isEmpty) {
        throw Exception('Voice note must belong to at least one folder');
      }

      // Create voice note
      final voiceNoteId = await database.into(database.voiceNotesV2).insert(
        VoiceNotesV2Companion(
          uuid: Value(uuid.v4()),
          title: Value(title),
          audioFilePath: Value(audioFilePath),
          durationSeconds: Value(durationSeconds),
          transcription: Value(transcription),
          recordedAt: Value(recordedAt ?? now),
          isPinned: Value(isPinned),
          isArchived: const Value(false),
          isDeleted: const Value(false),
          isSynced: const Value(false), // Needs cloud sync
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Link to folders
      await _linkToFolders(voiceNoteId, folders);

      debugPrint('✅ [VoiceNoteService] Created voice note: $voiceNoteId with ${folders.length} folders');
      return voiceNoteId;
    } catch (e, st) {
      debugPrint('❌ [VoiceNoteService] Failed to create voice note: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Update an existing voice note
  static Future<void> updateVoiceNote({
    required int noteId,
    String? title,
    String? audioFilePath,
    int? durationSeconds,
    String? transcription,
    List<NoteFolderDto>? folders,
    bool? isPinned,
  }) async {
    try {
      final database = getIt<AppDatabase>();
      final now = DateTime.now();

      // Build update companion
      final companion = VoiceNotesV2Companion(
        title: title != null ? Value(title) : const Value.absent(),
        audioFilePath: audioFilePath != null ? Value(audioFilePath) : const Value.absent(),
        durationSeconds: durationSeconds != null ? Value(durationSeconds) : const Value.absent(),
        transcription: transcription != null ? Value(transcription) : const Value.absent(),
        isPinned: isPinned != null ? Value(isPinned) : const Value.absent(),
        isSynced: const Value(false), // Mark for sync
        updatedAt: Value(now),
      );

      // Update note
      await (database.update(database.voiceNotesV2)
            ..where((t) => t.id.equals(noteId)))
          .write(companion);

      // Update folder relations if provided
      if (folders != null) {
        if (folders.isEmpty) {
          throw Exception('Voice note must belong to at least one folder');
        }
        await _updateFolderRelations(noteId, folders);
      }

      debugPrint('✅ [VoiceNoteService] Updated voice note: $noteId');
    } catch (e, st) {
      debugPrint('❌ [VoiceNoteService] Failed to update voice note: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Soft delete a voice note
  static Future<void> deleteVoiceNote(int noteId) async {
    try {
      final database = getIt<AppDatabase>();
      final now = DateTime.now();

      await (database.update(database.voiceNotesV2)
            ..where((t) => t.id.equals(noteId)))
          .write(
        VoiceNotesV2Companion(
          isDeleted: const Value(true),
          isSynced: const Value(false), // Mark for sync
          updatedAt: Value(now),
        ),
      );

      debugPrint('✅ [VoiceNoteService] Soft deleted voice note: $noteId');
    } catch (e, st) {
      debugPrint('❌ [VoiceNoteService] Failed to delete voice note: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Permanently delete a voice note (hard delete)
  static Future<void> permanentlyDeleteVoiceNote(int noteId) async {
    try {
      final database = getIt<AppDatabase>();

      // Delete folder relations (cascade)
      await (database.delete(database.voiceNoteFolderRelationsV2)
            ..where((t) => t.voiceNoteId.equals(noteId)))
          .go();

      // Delete note
      await (database.delete(database.voiceNotesV2)
            ..where((t) => t.id.equals(noteId)))
          .go();

      debugPrint('✅ [VoiceNoteService] Permanently deleted voice note: $noteId');
    } catch (e, st) {
      debugPrint('❌ [VoiceNoteService] Failed to permanently delete voice note: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Get a single voice note by ID
  static Future<VoiceNoteEntity?> getVoiceNote(int noteId) async {
    try {
      final database = getIt<AppDatabase>();
      return await (database.select(database.voiceNotesV2)
            ..where((t) => t.id.equals(noteId)))
          .getSingleOrNull();
    } catch (e, st) {
      debugPrint('❌ [VoiceNoteService] Failed to get voice note: $e');
      debugPrint('Stack trace: $st');
      return null;
    }
  }

  /// Watch all voice notes (excluding deleted)
  static Stream<List<VoiceNoteEntity>> watchAllVoiceNotes() {
    final database = getIt<AppDatabase>();
    return (database.select(database.voiceNotesV2)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm(expression: t.isPinned, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Watch voice notes by folder
  static Stream<List<VoiceNoteEntity>> watchVoiceNotesByFolder(int folderId) {
    final database = getIt<AppDatabase>();

    // Join with folder relations to filter by folder
    final query = database.select(database.voiceNotesV2).join([
      innerJoin(
        database.voiceNoteFolderRelationsV2,
        database.voiceNoteFolderRelationsV2.voiceNoteId.equalsExp(database.voiceNotesV2.id),
      ),
    ])
      ..where(database.voiceNoteFolderRelationsV2.folderId.equals(folderId))
      ..where(database.voiceNotesV2.isDeleted.equals(false))
      ..orderBy([
        OrderingTerm(expression: database.voiceNotesV2.isPinned, mode: OrderingMode.desc),
        OrderingTerm(expression: database.voiceNotesV2.updatedAt, mode: OrderingMode.desc),
      ]);

    return query.watch().map((rows) => rows.map((row) => row.readTable(database.voiceNotesV2)).toList());
  }

  /// Link voice note to folders
  static Future<void> _linkToFolders(int voiceNoteId, List<NoteFolderDto> folders) async {
    final database = getIt<AppDatabase>();

    await database.batch((batch) {
      for (final folder in folders) {
        batch.insert(
          database.voiceNoteFolderRelationsV2,
          VoiceNoteFolderRelationsV2Companion(
            voiceNoteId: Value(voiceNoteId),
            folderId: Value(folder.id),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  /// Update folder relations for a voice note
  static Future<void> _updateFolderRelations(int voiceNoteId, List<NoteFolderDto> folders) async {
    final database = getIt<AppDatabase>();

    await database.transaction(() async {
      // Delete existing relations
      await (database.delete(database.voiceNoteFolderRelationsV2)
            ..where((t) => t.voiceNoteId.equals(voiceNoteId)))
          .go();

      // Add new relations
      await _linkToFolders(voiceNoteId, folders);
    });
  }
}
