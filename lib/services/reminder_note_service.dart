import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../dtos/note_folder_dto.dart';
import '../models/reminder_dto.dart';
import '../service_locators/init_service_locators.dart';
import 'api_service.dart';

/// Service for managing reminder notes with scheduled notifications
/// Part of Architecture V8: Independent note types
class ReminderNoteService {
  ReminderNoteService._();

  /// Create a new reminder note
  ///
  /// IMPORTANT: folders parameter is REQUIRED (mandatory folders)
  /// If empty, defaults to "Random" folder
  static Future<int> createReminderNote({
    required String title,
    required DateTime reminderTime,
    required List<NoteFolderDto> folders,
    String? description,
    bool isPinned = false,
  }) async {
    try {
      final database = getIt<AppDatabase>();
      final now = DateTime.now();
      const uuid = Uuid();

      // Validate folders (must have at least one)
      if (folders.isEmpty) {
        throw Exception('Reminder note must belong to at least one folder');
      }

      // Generate UUID for the note
      final noteUuid = uuid.v4();

      // Create reminder note
      final reminderNoteId = await database.into(database.reminderNotesV2).insert(
        ReminderNotesV2Companion(
          uuid: Value(noteUuid),
          title: Value(title),
          description: Value(description),
          reminderTime: Value(reminderTime),
          isTriggered: const Value(false),
          isPinned: Value(isPinned),
          isArchived: const Value(false),
          isDeleted: const Value(false),
          isSynced: const Value(false), // Needs cloud sync
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Link to folders
      await _linkToFolders(reminderNoteId, folders);

      // Schedule reminder on backend
      try {
        await ApiService().createReminder(
          noteUuid: noteUuid,
          title: title,
          description: description,
          reminderTime: reminderTime,
        );
        debugPrint('✅ [ReminderNoteService] Scheduled backend reminder for: $noteUuid');

        // Mark as synced
        await (database.update(database.reminderNotesV2)
              ..where((t) => t.id.equals(reminderNoteId)))
            .write(const ReminderNotesV2Companion(isSynced: Value(true)));
      } catch (e) {
        debugPrint('⚠️ [ReminderNoteService] Failed to schedule backend reminder: $e');
        // Don't fail the whole operation - local reminder still works
        // Sync service will retry later
      }

      debugPrint('✅ [ReminderNoteService] Created reminder note: $reminderNoteId with ${folders.length} folders, scheduled for ${reminderTime.toIso8601String()}');
      return reminderNoteId;
    } catch (e, st) {
      debugPrint('❌ [ReminderNoteService] Failed to create reminder note: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Update an existing reminder note
  static Future<void> updateReminderNote({
    required int noteId,
    String? title,
    String? description,
    DateTime? reminderTime,
    List<NoteFolderDto>? folders,
    bool? isPinned,
    bool? isTriggered,
  }) async {
    try {
      final database = getIt<AppDatabase>();
      final now = DateTime.now();

      // Get current note for UUID and backend sync
      final currentNote = await getReminderNote(noteId);
      if (currentNote == null) {
        throw Exception('Reminder note not found: $noteId');
      }

      // Build update companion
      final companion = ReminderNotesV2Companion(
        title: title != null ? Value(title) : const Value.absent(),
        description: description != null ? Value(description) : const Value.absent(),
        reminderTime: reminderTime != null ? Value(reminderTime) : const Value.absent(),
        isTriggered: isTriggered != null ? Value(isTriggered) : const Value.absent(),
        isPinned: isPinned != null ? Value(isPinned) : const Value.absent(),
        isSynced: const Value(false), // Mark for sync
        updatedAt: Value(now),
      );

      // Update note
      await (database.update(database.reminderNotesV2)
            ..where((t) => t.id.equals(noteId)))
          .write(companion);

      // Update folder relations if provided
      if (folders != null) {
        if (folders.isEmpty) {
          throw Exception('Reminder note must belong to at least one folder');
        }
        await _updateFolderRelations(noteId, folders);
      }

      // Update backend reminder if any field changed
      if (title != null || description != null || reminderTime != null) {
        try {
          // Get reminders from backend for this note
          final reminders = await ApiService().getReminders(includeTriggered: false);
          final backendReminder = reminders.firstWhere(
            (r) => r['note_uuid'] == currentNote.uuid,
            orElse: () => <String, dynamic>{},
          );

          if (backendReminder.isNotEmpty && backendReminder['id'] != null) {
            // Update existing backend reminder
            await ApiService().updateReminder(
              reminderId: backendReminder['id'] as String,
              title: title,
              description: description,
              reminderTime: reminderTime,
            );
            debugPrint('✅ [ReminderNoteService] Updated backend reminder: ${backendReminder['id']}');

            // Mark as synced
            await (database.update(database.reminderNotesV2)
                  ..where((t) => t.id.equals(noteId)))
                .write(const ReminderNotesV2Companion(isSynced: Value(true)));
          } else {
            // Create new backend reminder if it doesn't exist
            await ApiService().createReminder(
              noteUuid: currentNote.uuid,
              title: title ?? currentNote.title,
              description: description ?? currentNote.description,
              reminderTime: reminderTime ?? currentNote.reminderTime,
            );
            debugPrint('✅ [ReminderNoteService] Created backend reminder for: ${currentNote.uuid}');

            // Mark as synced
            await (database.update(database.reminderNotesV2)
                  ..where((t) => t.id.equals(noteId)))
                .write(const ReminderNotesV2Companion(isSynced: Value(true)));
          }
        } catch (e) {
          debugPrint('⚠️ [ReminderNoteService] Failed to update backend reminder: $e');
          // Don't fail the whole operation
        }
      }

      debugPrint('✅ [ReminderNoteService] Updated reminder note: $noteId');
    } catch (e, st) {
      debugPrint('❌ [ReminderNoteService] Failed to update reminder note: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Mark a reminder as triggered (notification was sent)
  static Future<void> markReminderAsTriggered(int noteId) async {
    try {
      final database = getIt<AppDatabase>();
      final now = DateTime.now();

      await (database.update(database.reminderNotesV2)
            ..where((t) => t.id.equals(noteId)))
          .write(
        ReminderNotesV2Companion(
          isTriggered: const Value(true),
          isSynced: const Value(false), // Mark for sync
          updatedAt: Value(now),
        ),
      );

      debugPrint('✅ [ReminderNoteService] Marked reminder as triggered: $noteId');
    } catch (e, st) {
      debugPrint('❌ [ReminderNoteService] Failed to mark reminder as triggered: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Soft delete a reminder note
  static Future<void> deleteReminderNote(int noteId) async {
    try {
      final database = getIt<AppDatabase>();
      final now = DateTime.now();

      // Get note for UUID
      final note = await getReminderNote(noteId);
      if (note == null) {
        throw Exception('Reminder note not found: $noteId');
      }

      // Delete from backend first
      try {
        final reminders = await ApiService().getReminders(includeTriggered: false);
        final backendReminder = reminders.firstWhere(
          (r) => r['note_uuid'] == note.uuid,
          orElse: () => <String, dynamic>{},
        );

        if (backendReminder.isNotEmpty && backendReminder['id'] != null) {
          await ApiService().deleteReminder(backendReminder['id'] as String);
          debugPrint('✅ [ReminderNoteService] Deleted backend reminder: ${backendReminder['id']}');
        }
      } catch (e) {
        debugPrint('⚠️ [ReminderNoteService] Failed to delete backend reminder: $e');
        // Continue with local deletion
      }

      // Soft delete locally
      await (database.update(database.reminderNotesV2)
            ..where((t) => t.id.equals(noteId)))
          .write(
        ReminderNotesV2Companion(
          isDeleted: const Value(true),
          isSynced: const Value(true), // Synced (deleted on backend)
          updatedAt: Value(now),
        ),
      );

      debugPrint('✅ [ReminderNoteService] Soft deleted reminder note: $noteId');
    } catch (e, st) {
      debugPrint('❌ [ReminderNoteService] Failed to delete reminder note: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Permanently delete a reminder note (hard delete)
  static Future<void> permanentlyDeleteReminderNote(int noteId) async {
    try {
      final database = getIt<AppDatabase>();

      // Get note for UUID before deletion
      final note = await getReminderNote(noteId);

      // Delete from backend if note exists
      if (note != null) {
        try {
          final reminders = await ApiService().getReminders(includeTriggered: true);
          final backendReminder = reminders.firstWhere(
            (r) => r['note_uuid'] == note.uuid,
            orElse: () => <String, dynamic>{},
          );

          if (backendReminder.isNotEmpty && backendReminder['id'] != null) {
            await ApiService().deleteReminder(backendReminder['id'] as String);
            debugPrint('✅ [ReminderNoteService] Permanently deleted backend reminder: ${backendReminder['id']}');
          }
        } catch (e) {
          debugPrint('⚠️ [ReminderNoteService] Failed to delete backend reminder: $e');
          // Continue with local deletion
        }
      }

      // Delete folder relations (cascade)
      await (database.delete(database.reminderNoteFolderRelationsV2)
            ..where((t) => t.reminderNoteId.equals(noteId)))
          .go();

      // Delete note
      await (database.delete(database.reminderNotesV2)
            ..where((t) => t.id.equals(noteId)))
          .go();

      debugPrint('✅ [ReminderNoteService] Permanently deleted reminder note: $noteId');
    } catch (e, st) {
      debugPrint('❌ [ReminderNoteService] Failed to permanently delete reminder note: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Get a single reminder note by ID
  static Future<ReminderNoteEntity?> getReminderNote(int noteId) async {
    try {
      final database = getIt<AppDatabase>();
      return await (database.select(database.reminderNotesV2)
            ..where((t) => t.id.equals(noteId)))
          .getSingleOrNull();
    } catch (e, st) {
      debugPrint('❌ [ReminderNoteService] Failed to get reminder note: $e');
      debugPrint('Stack trace: $st');
      return null;
    }
  }

  /// Watch all reminder notes (excluding deleted)
  static Stream<List<ReminderNoteEntity>> watchAllReminderNotes() {
    final database = getIt<AppDatabase>();
    return (database.select(database.reminderNotesV2)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm(expression: t.isPinned, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.reminderTime, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  /// Watch pending reminder notes (not triggered, not deleted, reminder time in future)
  static Stream<List<ReminderNoteEntity>> watchPendingReminders() {
    final database = getIt<AppDatabase>();
    final now = DateTime.now();

    return (database.select(database.reminderNotesV2)
          ..where((t) => t.isDeleted.equals(false))
          ..where((t) => t.isTriggered.equals(false))
          ..where((t) => t.reminderTime.isBiggerThanValue(now))
          ..orderBy([
            (t) => OrderingTerm(expression: t.reminderTime, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  /// Watch triggered reminder notes
  static Stream<List<ReminderNoteEntity>> watchTriggeredReminders() {
    final database = getIt<AppDatabase>();

    return (database.select(database.reminderNotesV2)
          ..where((t) => t.isDeleted.equals(false))
          ..where((t) => t.isTriggered.equals(true))
          ..orderBy([
            (t) => OrderingTerm(expression: t.reminderTime, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Watch reminder notes by folder
  static Stream<List<ReminderNoteEntity>> watchReminderNotesByFolder(int folderId) {
    final database = getIt<AppDatabase>();

    // Join with folder relations to filter by folder
    final query = database.select(database.reminderNotesV2).join([
      innerJoin(
        database.reminderNoteFolderRelationsV2,
        database.reminderNoteFolderRelationsV2.reminderNoteId.equalsExp(database.reminderNotesV2.id),
      ),
    ])
      ..where(database.reminderNoteFolderRelationsV2.folderId.equals(folderId))
      ..where(database.reminderNotesV2.isDeleted.equals(false))
      ..orderBy([
        OrderingTerm(expression: database.reminderNotesV2.isPinned, mode: OrderingMode.desc),
        OrderingTerm(expression: database.reminderNotesV2.reminderTime, mode: OrderingMode.asc),
      ]);

    return query.watch().map((rows) => rows.map((row) => row.readTable(database.reminderNotesV2)).toList());
  }

  /// Get reminders that need to be triggered (reminder time has passed and not triggered yet)
  static Future<List<ReminderNoteEntity>> getRemindersToTrigger() async {
    try {
      final database = getIt<AppDatabase>();
      final now = DateTime.now();

      return await (database.select(database.reminderNotesV2)
            ..where((t) => t.isDeleted.equals(false))
            ..where((t) => t.isTriggered.equals(false))
            ..where((t) => t.reminderTime.isSmallerOrEqualValue(now))
            ..orderBy([
              (t) => OrderingTerm(expression: t.reminderTime, mode: OrderingMode.asc),
            ]))
          .get();
    } catch (e, st) {
      debugPrint('❌ [ReminderNoteService] Failed to get reminders to trigger: $e');
      debugPrint('Stack trace: $st');
      return [];
    }
  }

  // ==================== PRIVATE HELPER METHODS ====================

  /// Link reminder note to folders
  static Future<void> _linkToFolders(int reminderNoteId, List<NoteFolderDto> folders) async {
    final database = getIt<AppDatabase>();

    await database.batch((batch) {
      for (final folder in folders) {
        batch.insert(
          database.reminderNoteFolderRelationsV2,
          ReminderNoteFolderRelationsV2Companion(
            reminderNoteId: Value(reminderNoteId),
            folderId: Value(folder.id),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  /// Update folder relations for a reminder note
  static Future<void> _updateFolderRelations(int reminderNoteId, List<NoteFolderDto> folders) async {
    final database = getIt<AppDatabase>();

    await database.transaction(() async {
      // Delete existing relations
      await (database.delete(database.reminderNoteFolderRelationsV2)
            ..where((t) => t.reminderNoteId.equals(reminderNoteId)))
          .go();

      // Add new relations
      await _linkToFolders(reminderNoteId, folders);
    });
  }
}
