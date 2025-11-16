import 'package:flutter/foundation.dart';

import '../database/database.dart';
import '../models/reminder_dto.dart';
import '../service_locators/init_service_locators.dart';
import 'api_service.dart';

/// Service for syncing local reminders to backend
/// Handles auto-migration and retry logic for failed syncs
class ReminderSyncService {
  ReminderSyncService._();

  static bool _isSyncing = false;
  static DateTime? _lastSyncTime;

  /// Sync all local reminders to backend
  /// This handles:
  /// 1. Initial migration of existing local reminders
  /// 2. Retry of failed syncs (isSynced = false)
  static Future<Map<String, int>> syncAllReminders() async {
    if (_isSyncing) {
      debugPrint('⏭️ [ReminderSyncService] Sync already in progress, skipping');
      return {'created': 0, 'failed': 0, 'skipped': 0};
    }

    try {
      _isSyncing = true;
      debugPrint('🔄 [ReminderSyncService] Starting reminder sync...');

      final database = getIt<AppDatabase>();

      // Get all non-deleted, non-synced reminders
      final unsyncedReminders = await (database.select(database.reminderNotesV2)
            ..where((t) => t.isDeleted.equals(false))
            ..where((t) => t.isSynced.equals(false)))
          .get();

      if (unsyncedReminders.isEmpty) {
        debugPrint('✅ [ReminderSyncService] No reminders to sync');
        _lastSyncTime = DateTime.now();
        return {'created': 0, 'failed': 0, 'skipped': 0};
      }

      debugPrint('📝 [ReminderSyncService] Found ${unsyncedReminders.length} reminders to sync');

      // Convert to DTOs for sync
      final reminderDtos = unsyncedReminders.map((note) {
        return ReminderDto.fromLocal(
          noteUuid: note.uuid,
          title: note.title,
          description: note.description,
          reminderTime: note.reminderTime,
        );
      }).toList();

      // Bulk sync to backend
      try {
        final result = await ApiService().syncReminders(
          reminderDtos.map((dto) => dto.toJsonSync()).toList(),
        );

        final created = result['created'] as int? ?? 0;
        final updated = result['updated'] as int? ?? 0;
        final total = created + updated;

        debugPrint('✅ [ReminderSyncService] Synced $total reminders (created: $created, updated: $updated)');

        // Mark all as synced
        await database.batch((batch) {
          for (final note in unsyncedReminders) {
            batch.update(
              database.reminderNotesV2,
              ReminderNotesV2Companion(
                isSynced: const Value(true),
              ),
              where: (t) => t.id.equals(note.id),
            );
          }
        });

        _lastSyncTime = DateTime.now();
        return {'created': created, 'failed': 0, 'skipped': 0};
      } catch (e) {
        debugPrint('❌ [ReminderSyncService] Bulk sync failed: $e');

        // Fall back to individual sync
        return await _syncIndividually(unsyncedReminders);
      }
    } catch (e, st) {
      debugPrint('❌ [ReminderSyncService] Sync failed: $e');
      debugPrint('Stack trace: $st');
      return {'created': 0, 'failed': unsyncedReminders?.length ?? 0, 'skipped': 0};
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync reminders individually (fallback when bulk sync fails)
  static Future<Map<String, int>> _syncIndividually(List<ReminderNoteEntity> reminders) async {
    final database = getIt<AppDatabase>();
    int created = 0;
    int failed = 0;

    for (final note in reminders) {
      try {
        await ApiService().createReminder(
          noteUuid: note.uuid,
          title: note.title,
          description: note.description,
          reminderTime: note.reminderTime,
        );

        // Mark as synced
        await (database.update(database.reminderNotesV2)
              ..where((t) => t.id.equals(note.id)))
            .write(const ReminderNotesV2Companion(isSynced: Value(true)));

        created++;
        debugPrint('✅ [ReminderSyncService] Synced reminder: ${note.uuid}');
      } catch (e) {
        failed++;
        debugPrint('❌ [ReminderSyncService] Failed to sync reminder ${note.uuid}: $e');
      }
    }

    debugPrint('📊 [ReminderSyncService] Individual sync complete: $created created, $failed failed');
    _lastSyncTime = DateTime.now();
    return {'created': created, 'failed': failed, 'skipped': 0};
  }

  /// Check if sync is needed (has unsynced reminders)
  static Future<bool> needsSync() async {
    try {
      final database = getIt<AppDatabase>();

      final count = await (database.selectOnly(database.reminderNotesV2)
            ..addColumns([database.reminderNotesV2.id.count()])
            ..where(database.reminderNotesV2.isDeleted.equals(false))
            ..where(database.reminderNotesV2.isSynced.equals(false)))
          .getSingle();

      final unsyncedCount = count.read(database.reminderNotesV2.id.count()) ?? 0;
      return unsyncedCount > 0;
    } catch (e) {
      debugPrint('❌ [ReminderSyncService] Failed to check sync status: $e');
      return false;
    }
  }

  /// Get sync status
  static Map<String, dynamic> getSyncStatus() {
    return {
      'is_syncing': _isSyncing,
      'last_sync_time': _lastSyncTime?.toIso8601String(),
    };
  }

  /// Force sync (ignores sync-in-progress check)
  static Future<Map<String, int>> forceSyncAllReminders() async {
    _isSyncing = false; // Reset flag
    return await syncAllReminders();
  }
}
