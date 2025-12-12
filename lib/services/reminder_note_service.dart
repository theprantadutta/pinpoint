import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../dtos/note_folder_dto.dart';
import '../service_locators/init_service_locators.dart';
import '../sync/sync_manager.dart';
import 'api_service.dart';

/// Service for managing reminder notes with scheduled notifications
/// Part of Architecture V8: Independent note types
class ReminderNoteService {
  ReminderNoteService._();

  /// Trigger background sync (non-blocking)
  static void _triggerBackgroundSync() {
    // Add delay to ensure current database transaction completes
    Future.delayed(const Duration(seconds: 1), () async {
      try {
        final syncManager = getIt<SyncManager>();
        debugPrint('🔄 [ReminderNoteService] Triggering background sync...');
        await syncManager.upload();
        debugPrint('✅ [ReminderNoteService] Background sync completed');
      } catch (e) {
        debugPrint('⚠️ [ReminderNoteService] Background sync failed: $e');
        // Don't rethrow - sync failures shouldn't affect note operations
      }
    });
  }

  /// Generate occurrence times for recurring reminders
  static List<DateTime> _generateOccurrenceTimes({
    required DateTime startTime,
    required String recurrenceType,
    required int recurrenceInterval,
    required String recurrenceEndType,
    String? recurrenceEndValue,
    int maxOccurrences = 100,
  }) {
    if (recurrenceType == 'once') {
      return [startTime];
    }

    final occurrences = <DateTime>[startTime];
    DateTime currentTime = startTime;

    // Determine end condition
    int maxCount = maxOccurrences;
    DateTime? endDate;

    if (recurrenceEndType == 'after_occurrences' && recurrenceEndValue != null) {
      maxCount = int.tryParse(recurrenceEndValue) ?? maxOccurrences;
      if (maxCount > maxOccurrences) maxCount = maxOccurrences;
    } else if (recurrenceEndType == 'on_date' && recurrenceEndValue != null) {
      try {
        endDate = DateTime.parse(recurrenceEndValue);
      } catch (e) {
        debugPrint('⚠️ [ReminderNoteService] Invalid end date: $recurrenceEndValue');
      }
    }

    // Generate occurrences
    while (occurrences.length < maxCount) {
      // Calculate next occurrence
      switch (recurrenceType) {
        case 'hourly':
          currentTime = currentTime.add(Duration(hours: recurrenceInterval));
          break;
        case 'daily':
          currentTime = currentTime.add(Duration(days: recurrenceInterval));
          break;
        case 'weekly':
          currentTime = currentTime.add(Duration(days: 7 * recurrenceInterval));
          break;
        case 'monthly':
          currentTime = DateTime(
            currentTime.year,
            currentTime.month + recurrenceInterval,
            currentTime.day,
            currentTime.hour,
            currentTime.minute,
          );
          break;
        case 'yearly':
          currentTime = DateTime(
            currentTime.year + recurrenceInterval,
            currentTime.month,
            currentTime.day,
            currentTime.hour,
            currentTime.minute,
          );
          break;
        default:
          return occurrences; // Unknown recurrence type
      }

      // Check end date
      if (endDate != null && currentTime.isAfter(endDate)) {
        break;
      }

      // Don't generate occurrences more than 1 year in the future
      final oneYearAhead = DateTime.now().add(const Duration(days: 365));
      if (currentTime.isAfter(oneYearAhead)) {
        break;
      }

      occurrences.add(currentTime);
    }

    debugPrint('🔄 [ReminderNoteService] Generated ${occurrences.length} occurrences for $recurrenceType reminder');
    return occurrences;
  }

  /// Create new reminder note(s)
  /// For recurring reminders, generates and creates all occurrences
  ///
  /// IMPORTANT: folders parameter is REQUIRED (mandatory folders)
  /// If empty, defaults to "Random" folder
  ///
  /// Returns: List of created reminder note IDs (single for one-time, multiple for recurring)
  static Future<List<int>> createReminderNote({
    required String title,
    required String notificationTitle,
    String? notificationContent,
    required DateTime reminderTime,
    required List<NoteFolderDto> folders,
    String recurrenceType = 'once',
    int recurrenceInterval = 1,
    String recurrenceEndType = 'never',
    String? recurrenceEndValue,
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

      // Generate occurrence times
      final occurrenceTimes = _generateOccurrenceTimes(
        startTime: reminderTime,
        recurrenceType: recurrenceType,
        recurrenceInterval: recurrenceInterval,
        recurrenceEndType: recurrenceEndType,
        recurrenceEndValue: recurrenceEndValue,
      );

      // Generate series ID for recurring reminders
      final seriesId = recurrenceType != 'once' ? uuid.v4() : null;
      final reminderNoteIds = <int>[];
      int? parentId;

      for (int i = 0; i < occurrenceTimes.length; i++) {
        final occurrenceTime = occurrenceTimes[i];

        // Generate unique UUID for each occurrence
        final noteUuid = uuid.v4();

        // Create reminder note for this occurrence
        final reminderNoteId = await database.into(database.reminderNotesV2).insert(
          ReminderNotesV2Companion(
            uuid: Value(noteUuid),
            title: Value(title),
            notificationTitle: Value(notificationTitle),
            notificationContent: Value(notificationContent),
            description: Value(notificationContent), // For backward compatibility
            reminderTime: Value(occurrenceTime),
            recurrenceType: Value(recurrenceType),
            recurrenceInterval: Value(recurrenceInterval),
            recurrenceEndType: Value(recurrenceEndType),
            recurrenceEndValue: Value(recurrenceEndValue),
            occurrenceNumber: Value(i + 1),
            seriesId: Value(seriesId),
            parentReminderId: Value(i == 0 ? null : parentId.toString()),
            isTriggered: const Value(false),
            isPinned: Value(isPinned),
            isArchived: const Value(false),
            isDeleted: const Value(false),
            isSynced: const Value(false), // Needs cloud sync
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

        // First occurrence is the parent
        if (i == 0) {
          parentId = reminderNoteId;
        }

        // Link to folders (all occurrences share same folders)
        await _linkToFolders(reminderNoteId, folders);

        reminderNoteIds.add(reminderNoteId);

        debugPrint('✅ [ReminderNoteService] Created reminder occurrence ${i + 1}/${occurrenceTimes.length}: $reminderNoteId, scheduled for ${occurrenceTime.toIso8601String()}');
      }

      debugPrint('✅ [ReminderNoteService] Created ${reminderNoteIds.length} reminder note(s) with ${folders.length} folders');

      // Schedule all reminders on backend (this is what actually triggers notifications!)
      debugPrint('🔔 [ReminderNoteService] Scheduling ${reminderNoteIds.length} reminder(s) on backend...');
      for (final noteId in reminderNoteIds) {
        try {
          await scheduleReminderOnBackend(noteId);
        } catch (e) {
          debugPrint('⚠️ [ReminderNoteService] Failed to schedule reminder $noteId on backend: $e');
          // Continue with other reminders even if one fails
        }
      }

      // Trigger background sync for encrypted note storage
      _triggerBackgroundSync();

      return reminderNoteIds;
    } catch (e, st) {
      debugPrint('❌ [ReminderNoteService] Failed to create reminder note: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Update an existing reminder note or series
  static Future<void> updateReminderNote({
    required int noteId,
    String? title,
    String? notificationTitle,
    String? notificationContent,
    DateTime? reminderTime,
    List<NoteFolderDto>? folders,
    bool? isPinned,
    bool? isTriggered,
    String? recurrenceType,
    int? recurrenceInterval,
    String? recurrenceEndType,
    String? recurrenceEndValue,
    bool updateSeries = false,
  }) async {
    try {
      final database = getIt<AppDatabase>();
      final now = DateTime.now();

      // Get current note
      final currentNote = await getReminderNote(noteId);
      if (currentNote == null) {
        throw Exception('Reminder note not found: $noteId');
      }

      // Determine which notes to update
      List<ReminderNoteEntity> notesToUpdate;
      if (updateSeries && currentNote.seriesId != null) {
        // Update all future occurrences in the series
        notesToUpdate = await (database.select(database.reminderNotesV2)
              ..where((t) => t.seriesId.equals(currentNote.seriesId!))
              ..where((t) => t.isTriggered.equals(false))) // Only future occurrences
            .get();
        debugPrint('🔄 [ReminderNoteService] Updating ${notesToUpdate.length} occurrences in series');
      } else {
        // Update only this note
        notesToUpdate = [currentNote];
      }

      // Build update companion
      final companion = ReminderNotesV2Companion(
        title: title != null ? Value(title) : const Value.absent(),
        notificationTitle: notificationTitle != null ? Value(notificationTitle) : const Value.absent(),
        notificationContent: notificationContent != null ? Value(notificationContent) : const Value.absent(),
        description: notificationContent != null ? Value(notificationContent) : const Value.absent(), // Backward compat
        reminderTime: reminderTime != null ? Value(reminderTime) : const Value.absent(),
        recurrenceType: recurrenceType != null ? Value(recurrenceType) : const Value.absent(),
        recurrenceInterval: recurrenceInterval != null ? Value(recurrenceInterval) : const Value.absent(),
        recurrenceEndType: recurrenceEndType != null ? Value(recurrenceEndType) : const Value.absent(),
        recurrenceEndValue: recurrenceEndValue != null ? Value(recurrenceEndValue) : const Value.absent(),
        isTriggered: isTriggered != null ? Value(isTriggered) : const Value.absent(),
        isPinned: isPinned != null ? Value(isPinned) : const Value.absent(),
        isSynced: const Value(false), // Mark for sync
        updatedAt: Value(now),
      );

      // Update all notes
      for (final note in notesToUpdate) {
        await (database.update(database.reminderNotesV2)
              ..where((t) => t.id.equals(note.id)))
            .write(companion);

        // Update folder relations if provided
        if (folders != null) {
          if (folders.isEmpty) {
            throw Exception('Reminder note must belong to at least one folder');
          }
          await _updateFolderRelations(note.id, folders);
        }
      }

      debugPrint('✅ [ReminderNoteService] Updated ${notesToUpdate.length} reminder note(s)');

      // Trigger background sync
      _triggerBackgroundSync();
    } catch (e, st) {
      debugPrint('❌ [ReminderNoteService] Failed to update reminder note: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Schedule reminder notification on backend
  /// This is called automatically when creating/updating reminders
  static Future<void> scheduleReminderOnBackend(int noteId) async {
    try {
      final database = getIt<AppDatabase>();

      // Get the reminder note
      final note = await getReminderNote(noteId);
      if (note == null) {
        throw Exception('Reminder note not found: $noteId');
      }

      // Check if already synced to backend
      if (note.isSynced) {
        debugPrint('⏭️ [ReminderNoteService] Reminder already scheduled on backend: $noteId');
        return;
      }

      // Schedule on backend
      try {
        // Create new backend reminder with all recurrence fields
        final response = await ApiService().createReminder(
          noteUuid: note.uuid,
          title: note.title!,
          notificationTitle: note.notificationTitle ?? note.title!,
          notificationContent: note.notificationContent,
          reminderTime: note.reminderTime,
          recurrenceType: note.recurrenceType,
          recurrenceInterval: note.recurrenceInterval,
          recurrenceEndType: note.recurrenceEndType,
          recurrenceEndValue: note.recurrenceEndValue,
        );

        debugPrint('✅ [ReminderNoteService] Created backend reminder for: ${note.uuid}');
        debugPrint('   Backend response: $response');

        // Mark as synced
        await (database.update(database.reminderNotesV2)
              ..where((t) => t.id.equals(noteId)))
            .write(const ReminderNotesV2Companion(isSynced: Value(true)));

        debugPrint('✅ [ReminderNoteService] Reminder scheduled on backend: $noteId');
      } catch (e) {
        debugPrint('❌ [ReminderNoteService] Failed to schedule backend reminder: $e');
        rethrow;
      }
    } catch (e, st) {
      debugPrint('❌ [ReminderNoteService] Failed to schedule reminder on backend: $e');
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

  /// Soft delete a reminder note or entire series
  static Future<int> deleteReminderNote(int noteId, {bool deleteSeries = false}) async {
    try {
      final database = getIt<AppDatabase>();
      final now = DateTime.now();

      // Get note
      final note = await getReminderNote(noteId);
      if (note == null) {
        throw Exception('Reminder note not found: $noteId');
      }

      // Determine which notes to delete
      List<ReminderNoteEntity> notesToDelete;
      if (deleteSeries && note.seriesId != null) {
        // Delete all occurrences in the series
        notesToDelete = await (database.select(database.reminderNotesV2)
              ..where((t) => t.seriesId.equals(note.seriesId!)))
            .get();
        debugPrint('🔄 [ReminderNoteService] Deleting ${notesToDelete.length} occurrences in series');
      } else {
        // Delete only this note
        notesToDelete = [note];
      }

      int deletedCount = 0;

      for (final noteToDelete in notesToDelete) {
        // Delete from backend first
        try {
          final reminders = await ApiService().getReminders(includeTriggered: false);
          final backendReminder = reminders.firstWhere(
            (r) => r['note_uuid'] == noteToDelete.uuid,
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
              ..where((t) => t.id.equals(noteToDelete.id)))
            .write(
          ReminderNotesV2Companion(
            isDeleted: const Value(true),
            isSynced: const Value(false), // Mark for sync
            updatedAt: Value(now),
          ),
        );

        deletedCount++;
      }

      debugPrint('✅ [ReminderNoteService] Soft deleted $deletedCount reminder note(s)');

      // Trigger background sync
      _triggerBackgroundSync();

      return deletedCount;
    } catch (e, st) {
      debugPrint('❌ [ReminderNoteService] Failed to delete reminder note: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Restore a soft-deleted reminder note
  static Future<void> restoreReminderNote(int noteId) async {
    try {
      final database = getIt<AppDatabase>();
      final now = DateTime.now();

      // Get note for recreation on backend
      final note = await getReminderNote(noteId);
      if (note == null) {
        throw Exception('Reminder note not found: $noteId');
      }

      // Restore locally first
      await (database.update(database.reminderNotesV2)
            ..where((t) => t.id.equals(noteId)))
          .write(
        ReminderNotesV2Companion(
          isDeleted: const Value(false),
          isSynced: const Value(false), // Mark for sync
          updatedAt: Value(now),
        ),
      );

      debugPrint('✅ [ReminderNoteService] Restored reminder note: $noteId');

      // Trigger background sync to recreate reminder on backend
      _triggerBackgroundSync();
    } catch (e, st) {
      debugPrint('❌ [ReminderNoteService] Failed to restore reminder note: $e');
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
