import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';
import '../services/api_service.dart';
import '../services/encryption_service.dart';
import 'sync_service.dart';
import 'folder_sync_service.dart';

/// Wrapper class for V2 notes (different note types are in separate tables)
class _V2NoteWrapper {
  final String type; // 'text', 'voice', 'todo', 'reminder'
  final dynamic note; // TextNoteEntity, VoiceNoteEntity, TodoListNoteEntity, or ReminderNoteEntity
  final List<TodoItemEntity>? todoItems; // Only for todo notes

  _V2NoteWrapper({
    required this.type,
    required this.note,
    this.todoItems,
  });

  String get uuid {
    switch (type) {
      case 'text':
        return (note as TextNoteEntity).uuid;
      case 'voice':
        return (note as VoiceNoteEntity).uuid;
      case 'todo':
        return (note as TodoListNoteEntity).uuid;
      case 'reminder':
        return (note as ReminderNoteEntity).uuid;
      default:
        throw Exception('Unknown note type: $type');
    }
  }

  bool get isDeleted {
    switch (type) {
      case 'text':
        return (note as TextNoteEntity).isDeleted;
      case 'voice':
        return (note as VoiceNoteEntity).isDeleted;
      case 'todo':
        return (note as TodoListNoteEntity).isDeleted;
      case 'reminder':
        return (note as ReminderNoteEntity).isDeleted;
      default:
        return false;
    }
  }
}

/// Cloud-based sync service using API backend
class ApiSyncService extends SyncService {
  static const String _lastSyncTimeKey = 'api_sync_last_sync_time';

  final ApiService _apiService;
  final AppDatabase _database;
  late final FolderSyncService _folderSyncService;

  int _lastSyncTime = 0;

  ApiSyncService({
    required ApiService apiService,
    required AppDatabase database,
  })  : _apiService = apiService,
        _database = database {
    // Initialize FolderSyncService
    _folderSyncService = FolderSyncService(
      apiService: apiService,
      database: database,
    );
  }

  @override
  Future<void> init() async {
    // Load last sync time from SharedPreferences
    await _loadLastSyncTime();
  }

  /// Load last sync time from SharedPreferences
  Future<void> _loadLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastSyncTime = prefs.getInt(_lastSyncTimeKey) ?? 0;
      debugPrint('📅 [ApiSync] Loaded last sync time: $_lastSyncTime');
    } catch (e) {
      debugPrint('⚠️ [ApiSync] Failed to load last sync time: $e');
      _lastSyncTime = 0;
    }
  }

  /// Save last sync time to SharedPreferences
  Future<void> _saveLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncTimeKey, _lastSyncTime);
      debugPrint('💾 [ApiSync] Saved last sync time: $_lastSyncTime');
    } catch (e) {
      debugPrint('⚠️ [ApiSync] Failed to save last sync time: $e');
    }
  }

  /// Reset last sync time (forces full re-sync on next sync)
  /// Call this when user logs out or needs to force a complete re-sync
  Future<void> resetSyncTimestamp() async {
    _lastSyncTime = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastSyncTimeKey);
      debugPrint('🔄 [ApiSync] Reset sync timestamp - next sync will be full sync');
    } catch (e) {
      debugPrint('⚠️ [ApiSync] Failed to reset sync timestamp: $e');
    }
  }

  @override
  Future<bool> isConfigured() async {
    // Check if auth token exists locally (no API call needed)
    // Token validity is checked when actually used for sync operations
    return await _apiService.hasToken();
  }

  @override
  Future<SyncResult> sync({
    SyncDirection direction = SyncDirection.both,
  }) async {
    try {
      debugPrint('\n🚀 [ApiSync] ========== STARTING SYNC ==========');
      debugPrint('🚀 [ApiSync] Direction: $direction');

      // CRITICAL: ALWAYS sync folders FIRST to prevent race conditions
      debugPrint('\n📁 [ApiSync] Phase 1/3: Syncing folders...');
      final folderResult = await _folderSyncService.syncFolders();

      if (!folderResult.success) {
        debugPrint('❌ [ApiSync] Folder sync failed: ${folderResult.message}');
        return SyncResult(
          success: false,
          message: 'Folder sync failed: ${folderResult.message}',
        );
      }

      debugPrint('✅ [ApiSync] Folders synced: ${folderResult.foldersSynced}');

      // THEN sync notes using parent class logic
      debugPrint('\n📝 [ApiSync] Phase 2/3: Syncing notes...');
      final noteResult = await super.sync(direction: direction);

      // FINALLY sync reminders (independent note type in V2 architecture)
      debugPrint('\n⏰ [ApiSync] Phase 3/3: Syncing reminders...');
      int remindersSynced = 0;
      if (direction == SyncDirection.download || direction == SyncDirection.both) {
        try {
          remindersSynced = await _downloadReminders();
          debugPrint('✅ [ApiSync] Reminders synced: $remindersSynced');
        } catch (e) {
          debugPrint('⚠️ [ApiSync] Reminder sync failed (non-critical): $e');
          // Don't fail the entire sync if reminders fail
        }
      }

      debugPrint('\n🚀 [ApiSync] ========== SYNC COMPLETE ==========');
      debugPrint('📊 [ApiSync] Folders: ${folderResult.foldersSynced}, Notes: ${noteResult.notesSynced}, Reminders: $remindersSynced');

      return SyncResult(
        success: noteResult.success,
        message: noteResult.message,
        notesSynced: noteResult.notesSynced,
        foldersSynced: folderResult.foldersSynced,
        tagsSynced: noteResult.tagsSynced,
        remindersSynced: remindersSynced,
        notesFailed: noteResult.notesFailed,
        errors: noteResult.errors,
        decryptionErrors: noteResult.decryptionErrors,
      );
    } catch (e, st) {
      debugPrint('❌ [ApiSync] Sync failed: $e');
      debugPrint('Stack trace: $st');
      return SyncResult(
        success: false,
        message: 'Sync failed: ${e.toString()}',
      );
    }
  }

  @override
  Future<SyncResult> uploadChanges() async {
    try {
      debugPrint('\n🔼 [ApiSync] ========== STARTING V2 UPLOAD ==========');

      // Get all V2 notes that need syncing
      final notesToSync = await _getNotesToUpload();

      if (notesToSync.isEmpty) {
        debugPrint('✅ [ApiSync] No notes to upload\n');
        return SyncResult(
          success: true,
          message: 'No changes to upload',
          notesSynced: 0,
        );
      }

      // Convert notes to encrypted format
      final encryptedNotes = <Map<String, dynamic>>[];
      int failedCount = 0;

      for (final noteWrapper in notesToSync) {
        try {
          final noteId = (noteWrapper.note as dynamic).id;
          final noteTitle = noteWrapper.type == 'text'
              ? (noteWrapper.note as TextNoteEntity).title ?? 'Untitled'
              : noteWrapper.type == 'voice'
                  ? (noteWrapper.note as VoiceNoteEntity).title ?? 'Voice note'
                  : noteWrapper.type == 'todo'
                      ? (noteWrapper.note as TodoListNoteEntity).title ?? 'Todo list'
                      : (noteWrapper.note as ReminderNoteEntity).title ?? 'Reminder';

          debugPrint(
              '🔼 [ApiSync] Encrypting note $noteId (${noteWrapper.type}): "$noteTitle"');
          final encryptedNote = await _serializeAndEncryptNoteV2(noteWrapper);
          encryptedNotes.add(encryptedNote);
          debugPrint('✅ [ApiSync] Note $noteId encrypted successfully');
        } catch (e) {
          failedCount++;
          debugPrint('❌ [ApiSync] Failed to encrypt note: $e');
          // Skip this note and continue with others
        }
      }

      if (encryptedNotes.isEmpty) {
        return SyncResult(
          success: false,
          message: 'Failed to encrypt notes',
          notesSynced: 0,
          notesFailed: failedCount,
        );
      }

      // Get device ID
      final deviceId = await _getDeviceId();

      // Upload to backend
      debugPrint('🔼 [ApiSync] Uploading ${encryptedNotes.length} notes to backend...');
      final response = await _apiService.syncNotes(
        notes: encryptedNotes,
        deviceId: deviceId,
      );

      final syncedCount = response['synced_count'] ?? 0;
      debugPrint('✅ [ApiSync] Uploaded $syncedCount notes successfully');

      // Mark all uploaded notes as synced in their respective V2 tables
      for (final noteWrapper in notesToSync) {
        try {
          await _markNoteAsSyncedV2(noteWrapper);
        } catch (e) {
          debugPrint('⚠️ [ApiSync] Failed to mark note as synced: $e');
        }
      }

      debugPrint('🔼 [ApiSync] ========== UPLOAD COMPLETE ==========\n');

      return SyncResult(
        success: true,
        message: 'Uploaded $syncedCount notes',
        notesSynced: syncedCount,
        notesFailed: failedCount,
      );
    } catch (e) {
      debugPrint('❌ [ApiSync] Upload failed: $e');
      return SyncResult(
        success: false,
        message: 'Upload failed: ${e.toString()}',
      );
    }
  }

  /// Mark a V2 note as synced in the appropriate table
  Future<void> _markNoteAsSyncedV2(_V2NoteWrapper noteWrapper) async {
    final noteId = (noteWrapper.note as dynamic).id;

    switch (noteWrapper.type) {
      case 'text':
        await (_database.update(_database.textNotesV2)
              ..where((tbl) => tbl.id.equals(noteId)))
            .write(const TextNotesV2Companion(isSynced: Value(true)));
        debugPrint('  ✓ Marked text note $noteId as synced');
        break;

      case 'voice':
        await (_database.update(_database.voiceNotesV2)
              ..where((tbl) => tbl.id.equals(noteId)))
            .write(const VoiceNotesV2Companion(isSynced: Value(true)));
        debugPrint('  ✓ Marked voice note $noteId as synced');
        break;

      case 'todo':
        await (_database.update(_database.todoListNotesV2)
              ..where((tbl) => tbl.id.equals(noteId)))
            .write(const TodoListNotesV2Companion(isSynced: Value(true)));

        // Also mark all todo items as synced
        final noteUuid = (noteWrapper.note as TodoListNoteEntity).uuid;
        await (_database.update(_database.todoItemsV2)
              ..where((tbl) => tbl.todoListNoteUuid.equals(noteUuid)))
            .write(const TodoItemsV2Companion(isSynced: Value(true)));
        debugPrint('  ✓ Marked todo note $noteId and its items as synced');
        break;

      case 'reminder':
        await (_database.update(_database.reminderNotesV2)
              ..where((tbl) => tbl.id.equals(noteId)))
            .write(const ReminderNotesV2Companion(isSynced: Value(true)));
        debugPrint('  ✓ Marked reminder note $noteId as synced');
        break;
    }
  }

  @override
  Future<SyncResult> downloadChanges() async {
    try {
      debugPrint('\n🔽 [ApiSync] ========== STARTING DOWNLOAD ==========');
      debugPrint('🔽 [ApiSync] Last sync time: $_lastSyncTime');

      // Fetch notes from backend (only those updated since last sync)
      final response = await _apiService.getNotes(
        since: _lastSyncTime,
        includeDeleted: true,
      );

      if (response.isEmpty) {
        debugPrint('✅ [ApiSync] No new notes to download');
        debugPrint('🔽 [ApiSync] ========== DOWNLOAD COMPLETE ==========\n');
        return SyncResult(
          success: true,
          message: 'No new changes',
          notesSynced: 0,
        );
      }

      debugPrint(
          '📥 [ApiSync] Downloaded ${response.length} notes from server');

      int successCount = 0;
      int conflictCount = 0;
      int failedCount = 0;
      int decryptionErrorCount = 0;
      final List<String> errors = [];

      // Process each note
      for (final encryptedNote in response) {
        try {
          final clientNoteUuid = encryptedNote['client_note_uuid'] as String;
          final encryptedData = encryptedNote['encrypted_data'] as String;
          final isDeleted = encryptedNote['is_deleted'] as bool? ?? false;
          final serverUpdatedAt = DateTime.parse(encryptedNote['updated_at']);

          debugPrint(
              '\n🔽 [ApiSync] Processing note $clientNoteUuid (deleted: $isDeleted)');
          debugPrint('🔽 [ApiSync] Server updated_at: $serverUpdatedAt');

          // Check if note exists locally by UUID
          final existingNote = await _getNoteByUuid(clientNoteUuid);
          debugPrint(
              '🔽 [ApiSync] Local note ${existingNote != null ? "EXISTS" : "NOT FOUND"} (local updated: ${existingNote?.updatedAt})');

          if (existingNote != null) {
            // Conflict detection: compare timestamps
            // Only skip if local was modified AFTER the server version
            // AND local is more than 1 second newer (to account for clock skew)
            final timeDiff =
                existingNote.updatedAt.difference(serverUpdatedAt).inSeconds;
            if (timeDiff > 1) {
              debugPrint(
                  '⚠️ [ApiSync] CONFLICT: local is ${timeDiff}s newer - keeping local version');
              conflictCount++;
              // Keep local version (local wins)
              continue;
            } else {
              debugPrint(
                  '✅ [ApiSync] Server version is newer or same - will update local');
            }
          } else {
            debugPrint(
                '📝 [ApiSync] Note does not exist locally - will create new');
          }

          // Decrypt and deserialize note
          debugPrint('🔓 [ApiSync] Decrypting note data...');
          final noteData = await _decryptAndDeserializeNote(encryptedData);
          debugPrint('✅ [ApiSync] Decryption successful');

          if (isDeleted) {
            // Soft-delete the note locally (mark as deleted but keep record)
            if (existingNote != null) {
              debugPrint(
                  '🗑️ [ApiSync] Soft-deleting note $clientNoteUuid locally');
              await (_database.update(_database.notes)
                    ..where((tbl) => tbl.uuid.equals(clientNoteUuid)))
                  .write(NotesCompanion(
                isDeleted: Value(true),
                updatedAt: Value(serverUpdatedAt),
                isSynced:
                    Value(true), // Mark as synced since we got it from server
              ));
              successCount++;
            } else {
              // Note doesn't exist locally, nothing to delete
              debugPrint(
                  'ℹ️ [ApiSync] Note $clientNoteUuid doesn\'t exist locally, skipping deletion');
            }
          } else {
            // Update or create the note
            await _applyNoteToDatabase(clientNoteUuid, noteData, serverUpdatedAt);
            successCount++;
          }
        } catch (e) {
          failedCount++;
          final errorMsg = e.toString();

          // Check if it's a decryption error
          if (errorMsg.contains('decrypt') || errorMsg.contains('Decryption') ||
              errorMsg.contains('Invalid') || errorMsg.contains('cipher')) {
            decryptionErrorCount++;
            debugPrint('❌ [ApiSync] DECRYPTION FAILED for note: $e');
            errors.add('Decryption failed: ${errorMsg.length > 100 ? '${errorMsg.substring(0, 100)}...' : errorMsg}');
          } else {
            debugPrint('❌ [ApiSync] Failed to process note: $e');
            errors.add('Processing failed: ${errorMsg.length > 100 ? '${errorMsg.substring(0, 100)}...' : errorMsg}');
          }
        }
      }

      // Update last sync time and persist to SharedPreferences
      _lastSyncTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _saveLastSyncTime();

      final messageParts = <String>[];
      if (successCount > 0) messageParts.add('$successCount notes restored');
      if (conflictCount > 0) messageParts.add('$conflictCount conflicts (kept local)');
      if (failedCount > 0) messageParts.add('$failedCount failed');

      final message = messageParts.isEmpty ? 'No changes' : messageParts.join(', ');

      debugPrint('✅ [ApiSync] $message');
      if (decryptionErrorCount > 0) {
        debugPrint('⚠️ [ApiSync] CRITICAL: $decryptionErrorCount decryption errors detected!');
        debugPrint('⚠️ [ApiSync] This usually means the encryption key is incorrect.');
      }
      debugPrint('🔽 [ApiSync] ========== DOWNLOAD COMPLETE ==========\n');

      return SyncResult(
        success: failedCount == 0 || successCount > 0, // Success if at least some notes worked
        message: message,
        notesSynced: successCount,
        notesFailed: failedCount,
        errors: errors,
        decryptionErrors: decryptionErrorCount,
      );
    } catch (e) {
      debugPrint('❌ [ApiSync] Download failed: $e');
      return SyncResult(
        success: false,
        message: 'Download failed: ${e.toString()}',
      );
    }
  }

  /// Get all V2 notes that need to be uploaded (not yet synced)
  Future<List<_V2NoteWrapper>> _getNotesToUpload() async {
    final notesToUpload = <_V2NoteWrapper>[];

    // Get unsynced text notes
    final textNotes = await (_database.select(_database.textNotesV2)
          ..where((tbl) => tbl.isSynced.equals(false)))
        .get();
    for (final textNote in textNotes) {
      notesToUpload.add(_V2NoteWrapper(type: 'text', note: textNote));
    }

    // Get unsynced voice notes
    final voiceNotes = await (_database.select(_database.voiceNotesV2)
          ..where((tbl) => tbl.isSynced.equals(false)))
        .get();
    for (final voiceNote in voiceNotes) {
      notesToUpload.add(_V2NoteWrapper(type: 'voice', note: voiceNote));
    }

    // Get unsynced todo notes (with their items)
    final todoNotes = await (_database.select(_database.todoListNotesV2)
          ..where((tbl) => tbl.isSynced.equals(false)))
        .get();
    for (final todoNote in todoNotes) {
      // Get todo items for this note
      final todoItems = await (_database.select(_database.todoItemsV2)
            ..where((tbl) => tbl.todoListNoteUuid.equals(todoNote.uuid))
            ..orderBy([(tbl) => OrderingTerm(expression: tbl.orderIndex)]))
          .get();
      notesToUpload.add(_V2NoteWrapper(
        type: 'todo',
        note: todoNote,
        todoItems: todoItems,
      ));
    }

    // Get unsynced reminder notes
    final reminderNotes = await (_database.select(_database.reminderNotesV2)
          ..where((tbl) => tbl.isSynced.equals(false)))
        .get();
    for (final reminderNote in reminderNotes) {
      notesToUpload.add(_V2NoteWrapper(type: 'reminder', note: reminderNote));
    }

    final deletedCount = notesToUpload.where((n) => n.isDeleted).length;
    debugPrint(
        '🔼 [ApiSync] Found ${notesToUpload.length} unsynced notes to upload (including $deletedCount deleted)');
    debugPrint(
        '🔼 [ApiSync] Breakdown: ${textNotes.length} text, ${voiceNotes.length} voice, ${todoNotes.length} todo, ${reminderNotes.length} reminder');

    return notesToUpload;
  }

  /// Serialize V2 note and encrypt for upload
  Future<Map<String, dynamic>> _serializeAndEncryptNoteV2(_V2NoteWrapper noteWrapper) async {
    // Build complete note data structure based on type
    final Map<String, dynamic> noteData;

    switch (noteWrapper.type) {
      case 'text':
        noteData = _serializeTextNoteV2(noteWrapper.note as TextNoteEntity);
        break;
      case 'voice':
        noteData = _serializeVoiceNoteV2(noteWrapper.note as VoiceNoteEntity);
        break;
      case 'todo':
        noteData = _serializeTodoNoteV2(
          noteWrapper.note as TodoListNoteEntity,
          noteWrapper.todoItems!,
        );
        break;
      case 'reminder':
        noteData = _serializeReminderNoteV2(noteWrapper.note as ReminderNoteEntity);
        break;
      default:
        throw Exception('Unknown note type: ${noteWrapper.type}');
    }

    // Add folder UUIDs for all note types
    await _addFolderUuidsToNoteData(noteData, noteWrapper);

    // Convert to JSON string
    final jsonString = jsonEncode(noteData);

    // Encrypt the JSON
    final encryptedData = SecureEncryptionService.encrypt(jsonString);

    // Build metadata (non-sensitive)
    final metadata = {
      'type': noteWrapper.type,
      'updated_at': noteData['updatedAt'],
      'has_audio': noteWrapper.type == 'voice',
      'has_attachments': false,
      'is_archived': noteData['isArchived'] ?? false,
      'is_deleted': noteData['isDeleted'] ?? false,
    };

    final payload = {
      'client_note_id': (noteWrapper.note as dynamic).id,
      'client_note_uuid': noteWrapper.uuid,
      'encrypted_data': encryptedData,
      'metadata': metadata,
      'version': 1,
    };

    return payload;
  }

  /// Serialize text note V2
  Map<String, dynamic> _serializeTextNoteV2(TextNoteEntity note) {
    return {
      'uuid': note.uuid,
      'noteTitle': note.title ?? '',
      'noteType': 'text',
      'content': note.content,
      'isPinned': note.isPinned,
      'isArchived': note.isArchived,
      'isDeleted': note.isDeleted,
      'createdAt': note.createdAt.toIso8601String(),
      'updatedAt': note.updatedAt.toIso8601String(),
    };
  }

  /// Serialize voice note V2
  Map<String, dynamic> _serializeVoiceNoteV2(VoiceNoteEntity note) {
    return {
      'uuid': note.uuid,
      'noteTitle': note.title ?? '',
      'noteType': 'audio', // Backend expects 'audio'
      'audioFilePath': note.audioFilePath,
      'audioDuration': note.durationSeconds,
      'transcription': note.transcription,
      'recordedAt': note.recordedAt?.toIso8601String(),
      'isPinned': note.isPinned,
      'isArchived': note.isArchived,
      'isDeleted': note.isDeleted,
      'createdAt': note.createdAt.toIso8601String(),
      'updatedAt': note.updatedAt.toIso8601String(),
    };
  }

  /// Serialize todo note V2
  Map<String, dynamic> _serializeTodoNoteV2(
    TodoListNoteEntity note,
    List<TodoItemEntity> items,
  ) {
    return {
      'uuid': note.uuid,
      'noteTitle': note.title ?? '',
      'noteType': 'todo',
      'todoItems': items
          .map((item) => {
                'uuid': item.uuid,
                'text': item.content,
                'isDone': item.isCompleted,
                'orderIndex': item.orderIndex,
              })
          .toList(),
      'isPinned': note.isPinned,
      'isArchived': note.isArchived,
      'isDeleted': note.isDeleted,
      'createdAt': note.createdAt.toIso8601String(),
      'updatedAt': note.updatedAt.toIso8601String(),
    };
  }

  /// Serialize reminder note V2
  Map<String, dynamic> _serializeReminderNoteV2(ReminderNoteEntity note) {
    return {
      'uuid': note.uuid,
      'noteTitle': note.title ?? '',
      'noteType': 'reminder',
      'notificationTitle': note.notificationTitle ?? note.title ?? '',
      'notificationContent': note.notificationContent,
      'reminderDescription': note.description, // For backward compatibility
      'reminderTime': note.reminderTime.toIso8601String(),
      'recurrenceType': note.recurrenceType,
      'recurrenceInterval': note.recurrenceInterval,
      'recurrenceEndType': note.recurrenceEndType,
      'recurrenceEndValue': note.recurrenceEndValue,
      'parentReminderId': note.parentReminderId,
      'occurrenceNumber': note.occurrenceNumber,
      'seriesId': note.seriesId,
      'isTriggered': note.isTriggered,
      'isPinned': note.isPinned,
      'isArchived': note.isArchived,
      'isDeleted': note.isDeleted,
      'createdAt': note.createdAt.toIso8601String(),
      'updatedAt': note.updatedAt.toIso8601String(),
    };
  }

  /// Add folder UUIDs to note data for V2 notes
  Future<void> _addFolderUuidsToNoteData(
    Map<String, dynamic> noteData,
    _V2NoteWrapper noteWrapper,
  ) async {
    final folderUuids = <String>[];

    // Fetch folder relations based on note type
    switch (noteWrapper.type) {
      case 'text':
        final textNote = noteWrapper.note as TextNoteEntity;
        final relations = await (_database.select(_database.textNoteFolderRelationsV2)
              ..where((r) => r.textNoteId.equals(textNote.id)))
            .get();

        for (final rel in relations) {
          final folder = await (_database.select(_database.noteFolders)
                ..where((f) => f.noteFolderId.equals(rel.folderId)))
              .getSingleOrNull();
          if (folder != null) {
            folderUuids.add(folder.uuid);
          }
        }
        break;

      case 'voice':
        final voiceNote = noteWrapper.note as VoiceNoteEntity;
        final relations = await (_database.select(_database.voiceNoteFolderRelationsV2)
              ..where((r) => r.voiceNoteId.equals(voiceNote.id)))
            .get();

        for (final rel in relations) {
          final folder = await (_database.select(_database.noteFolders)
                ..where((f) => f.noteFolderId.equals(rel.folderId)))
              .getSingleOrNull();
          if (folder != null) {
            folderUuids.add(folder.uuid);
          }
        }
        break;

      case 'todo':
        final todoNote = noteWrapper.note as TodoListNoteEntity;
        final relations = await (_database.select(_database.todoListNoteFolderRelationsV2)
              ..where((r) => r.todoListNoteId.equals(todoNote.id)))
            .get();

        for (final rel in relations) {
          final folder = await (_database.select(_database.noteFolders)
                ..where((f) => f.noteFolderId.equals(rel.folderId)))
              .getSingleOrNull();
          if (folder != null) {
            folderUuids.add(folder.uuid);
          }
        }
        break;

      case 'reminder':
        final reminderNote = noteWrapper.note as ReminderNoteEntity;
        final relations = await (_database.select(_database.reminderNoteFolderRelationsV2)
              ..where((r) => r.reminderNoteId.equals(reminderNote.id)))
            .get();

        for (final rel in relations) {
          final folder = await (_database.select(_database.noteFolders)
                ..where((f) => f.noteFolderId.equals(rel.folderId)))
              .getSingleOrNull();
          if (folder != null) {
            folderUuids.add(folder.uuid);
          }
        }
        break;
    }

    // Add folder UUIDs to note data
    noteData['folderUuids'] = folderUuids;
    debugPrint('📁 [ApiSync] Added ${folderUuids.length} folder UUIDs to ${noteWrapper.type} note ${noteData['uuid']}');
  }

  /// Restore folder relations from server data for V2 notes
  Future<void> _restoreFolderRelationsV2(
    String noteUuid,
    Map<String, dynamic> noteData,
    String noteType,
  ) async {
    if (!noteData.containsKey('folderUuids')) {
      debugPrint('⚠️ [ApiSync] No folder UUIDs in note data for $noteUuid, skipping folder restore');
      return;
    }

    final folderUuids = (noteData['folderUuids'] as List).cast<String>();
    if (folderUuids.isEmpty) {
      debugPrint('⚠️ [ApiSync] Empty folder UUIDs for $noteUuid, skipping folder restore');
      return;
    }

    try {
      // Get note ID from UUID
      int noteId;
      switch (noteType) {
        case 'text':
          final note = await (_database.select(_database.textNotesV2)
                ..where((t) => t.uuid.equals(noteUuid)))
              .getSingleOrNull();
          if (note == null) return;
          noteId = note.id;

          // Delete existing folder relations
          await (_database.delete(_database.textNoteFolderRelationsV2)
                ..where((r) => r.textNoteId.equals(noteId)))
              .go();
          break;

        case 'voice':
          final note = await (_database.select(_database.voiceNotesV2)
                ..where((t) => t.uuid.equals(noteUuid)))
              .getSingleOrNull();
          if (note == null) return;
          noteId = note.id;

          // Delete existing folder relations
          await (_database.delete(_database.voiceNoteFolderRelationsV2)
                ..where((r) => r.voiceNoteId.equals(noteId)))
              .go();
          break;

        case 'todo':
          final note = await (_database.select(_database.todoListNotesV2)
                ..where((t) => t.uuid.equals(noteUuid)))
              .getSingleOrNull();
          if (note == null) return;
          noteId = note.id;

          // Delete existing folder relations
          await (_database.delete(_database.todoListNoteFolderRelationsV2)
                ..where((r) => r.todoListNoteId.equals(noteId)))
              .go();
          break;

        case 'reminder':
          final note = await (_database.select(_database.reminderNotesV2)
                ..where((t) => t.uuid.equals(noteUuid)))
              .getSingleOrNull();
          if (note == null) return;
          noteId = note.id;

          // Delete existing folder relations
          await (_database.delete(_database.reminderNoteFolderRelationsV2)
                ..where((r) => r.reminderNoteId.equals(noteId)))
              .go();
          break;

        default:
          debugPrint('⚠️ [ApiSync] Unknown note type for folder restore: $noteType');
          return;
      }

      // Create new folder relations
      for (final folderUuid in folderUuids) {
        // Find folder by UUID
        final folder = await (_database.select(_database.noteFolders)
              ..where((f) => f.uuid.equals(folderUuid)))
            .getSingleOrNull();

        if (folder == null) {
          debugPrint('⚠️ [ApiSync] Folder not found for UUID: $folderUuid (will be synced later)');
          continue;
        }

        // Insert folder relation
        switch (noteType) {
          case 'text':
            await _database.into(_database.textNoteFolderRelationsV2).insert(
              TextNoteFolderRelationsV2Companion(
                textNoteId: Value(noteId),
                folderId: Value(folder.noteFolderId),
              ),
              mode: InsertMode.insertOrIgnore,
            );
            break;

          case 'voice':
            await _database.into(_database.voiceNoteFolderRelationsV2).insert(
              VoiceNoteFolderRelationsV2Companion(
                voiceNoteId: Value(noteId),
                folderId: Value(folder.noteFolderId),
              ),
              mode: InsertMode.insertOrIgnore,
            );
            break;

          case 'todo':
            await _database.into(_database.todoListNoteFolderRelationsV2).insert(
              TodoListNoteFolderRelationsV2Companion(
                todoListNoteId: Value(noteId),
                folderId: Value(folder.noteFolderId),
              ),
              mode: InsertMode.insertOrIgnore,
            );
            break;

          case 'reminder':
            await _database.into(_database.reminderNoteFolderRelationsV2).insert(
              ReminderNoteFolderRelationsV2Companion(
                reminderNoteId: Value(noteId),
                folderId: Value(folder.noteFolderId),
              ),
              mode: InsertMode.insertOrIgnore,
            );
            break;
        }
      }

      debugPrint('📁 [ApiSync] Restored ${folderUuids.length} folder relations for $noteType note $noteUuid');
    } catch (e, st) {
      debugPrint('❌ [ApiSync] Failed to restore folder relations: $e');
      debugPrint('Stack trace: $st');
    }
  }

  /// Decrypt and deserialize note from encrypted data
  Future<Map<String, dynamic>> _decryptAndDeserializeNote(
      String encryptedData) async {
    // Decrypt the data
    final jsonString = SecureEncryptionService.decrypt(encryptedData);

    // Parse JSON
    final noteData = jsonDecode(jsonString) as Map<String, dynamic>;

    return noteData;
  }

  /// Apply downloaded note to local database
  Future<void> _applyNoteToDatabase(
    String clientNoteUuid,
    Map<String, dynamic> noteData,
    DateTime serverUpdatedAt,
  ) async {
    // Check if note exists by UUID in V2 tables
    final existingNote = await _getNoteByUuidV2(clientNoteUuid);

    if (existingNote != null) {
      // Update existing V2 note
      await _updateExistingNoteV2(existingNote, noteData, serverUpdatedAt);
    } else {
      // Create new V2 note with the UUID
      await _createNoteFromData(clientNoteUuid, noteData);
    }
  }

  /// Update existing V2 note with downloaded data
  Future<void> _updateExistingNoteV2(
    _V2NoteWrapper existingNote,
    Map<String, dynamic> noteData,
    DateTime serverUpdatedAt,
  ) async {
    final uuid = existingNote.uuid;
    final title = noteData['noteTitle'] as String?;
    final isPinned = noteData['isPinned'] as bool? ?? false;
    final isArchived = noteData['isArchived'] as bool? ?? false;
    final isDeleted = noteData['isDeleted'] as bool? ?? false;

    debugPrint('🔄 [ApiSync] Updating existing V2 ${existingNote.type} note: $uuid');

    switch (existingNote.type) {
      case 'text':
        await (_database.update(_database.textNotesV2)
              ..where((tbl) => tbl.uuid.equals(uuid)))
            .write(
          TextNotesV2Companion(
            title: Value(title),
            content: Value(noteData['content'] as String? ?? ''),
            isPinned: Value(isPinned),
            isArchived: Value(isArchived),
            isDeleted: Value(isDeleted),
            updatedAt: Value(serverUpdatedAt),
            isSynced: const Value(true),
          ),
        );

        // Restore folder relations
        await _restoreFolderRelationsV2(uuid, noteData, 'text');
        break;

      case 'voice':
        final serverAudioPath = noteData['audioFilePath'] as String? ?? '';

        await (_database.update(_database.voiceNotesV2)
              ..where((tbl) => tbl.uuid.equals(uuid)))
            .write(
          VoiceNotesV2Companion(
            title: Value(title),
            audioFilePath: Value(serverAudioPath),
            durationSeconds: Value(noteData['audioDuration'] as int?),
            transcription: Value(noteData['transcription'] as String?),
            isPinned: Value(isPinned),
            isArchived: Value(isArchived),
            isDeleted: Value(isDeleted),
            updatedAt: Value(serverUpdatedAt),
            isSynced: const Value(true),
          ),
        );

        // Download audio file if it's a server path
        if (serverAudioPath.isNotEmpty && !serverAudioPath.startsWith('/data/')) {
          await _downloadAudioFile(serverAudioPath, uuid);
        }

        // Restore folder relations
        await _restoreFolderRelationsV2(uuid, noteData, 'voice');
        break;

      case 'todo':
        await (_database.update(_database.todoListNotesV2)
              ..where((tbl) => tbl.uuid.equals(uuid)))
            .write(
          TodoListNotesV2Companion(
            title: Value(title),
            isPinned: Value(isPinned),
            isArchived: Value(isArchived),
            isDeleted: Value(isDeleted),
            updatedAt: Value(serverUpdatedAt),
            isSynced: const Value(true),
          ),
        );

        // Update todo items
        if (noteData.containsKey('todoItems')) {
          // Get the note ID
          final todoNote = await (_database.select(_database.todoListNotesV2)
                ..where((tbl) => tbl.uuid.equals(uuid)))
              .getSingleOrNull();

          if (todoNote != null) {
            // Delete existing items
            await (_database.delete(_database.todoItemsV2)
                  ..where((tbl) => tbl.todoListNoteId.equals(todoNote.id)))
                .go();

            // Insert new items with the note ID
            final items = noteData['todoItems'] as List;
            for (final item in items) {
              await _database.into(_database.todoItemsV2).insert(
                TodoItemsV2Companion(
                  uuid: Value(item['uuid'] as String),
                  todoListNoteId: Value(todoNote.id),
                  todoListNoteUuid: Value(uuid),
                  content: Value(item['text'] as String),
                  isCompleted: Value(item['isDone'] as bool),
                  orderIndex: Value(item['orderIndex'] as int),
                  createdAt: Value(serverUpdatedAt),
                  updatedAt: Value(serverUpdatedAt),
                  isSynced: const Value(true),
                ),
              );
            }
          }
        }

        // Restore folder relations
        await _restoreFolderRelationsV2(uuid, noteData, 'todo');
        break;

      case 'reminder':
        await (_database.update(_database.reminderNotesV2)
              ..where((tbl) => tbl.uuid.equals(uuid)))
            .write(
          ReminderNotesV2Companion(
            title: Value(title),
            description: Value(noteData['reminderDescription'] as String?),
            reminderTime: Value(DateTime.parse(noteData['reminderTime'] as String)),
            isTriggered: Value(noteData['isTriggered'] as bool? ?? false),
            isPinned: Value(isPinned),
            isArchived: Value(isArchived),
            isDeleted: Value(isDeleted),
            updatedAt: Value(serverUpdatedAt),
            isSynced: const Value(true),
          ),
        );

        // Restore folder relations
        await _restoreFolderRelationsV2(uuid, noteData, 'reminder');
        break;
    }

    debugPrint('✅ [ApiSync] Updated V2 note: $uuid');
  }

  /// Create new V2 note from downloaded data
  Future<void> _createNoteFromData(
    String clientNoteUuid,
    Map<String, dynamic> noteData,
  ) async {
    try {
      debugPrint(
          '📝 [ApiSync] Creating new V2 note from server data (uuid: $clientNoteUuid)');

      final noteType = noteData['noteType'] as String;
      final createdAt = DateTime.parse(noteData['createdAt'] as String);
      final updatedAt = DateTime.parse(noteData['updatedAt'] as String);
      final title = noteData['noteTitle'] as String?;
      final isPinned = noteData['isPinned'] as bool? ?? false;
      final isArchived = noteData['isArchived'] as bool? ?? false;
      final isDeleted = noteData['isDeleted'] as bool? ?? false;

      // Create type-specific note in V2 tables
      switch (noteType) {
        case 'text':
          await _database.into(_database.textNotesV2).insert(
            TextNotesV2Companion(
              uuid: Value(clientNoteUuid),
              title: Value(title),
              content: Value(noteData['content'] as String? ?? ''),
              isPinned: Value(isPinned),
              isArchived: Value(isArchived),
              isDeleted: Value(isDeleted),
              createdAt: Value(createdAt),
              updatedAt: Value(updatedAt),
              isSynced: const Value(true), // Mark as synced
            ),
          );
          debugPrint('✅ [ApiSync] Created text note V2: $clientNoteUuid');

          // Restore folder relations
          await _restoreFolderRelationsV2(clientNoteUuid, noteData, 'text');
          break;

        case 'audio':
          final serverAudioPath = noteData['audioFilePath'] as String? ?? '';

          await _database.into(_database.voiceNotesV2).insert(
            VoiceNotesV2Companion(
              uuid: Value(clientNoteUuid),
              title: Value(title),
              audioFilePath: Value(serverAudioPath),
              durationSeconds: Value(noteData['audioDuration'] as int?),
              transcription: Value(noteData['transcription'] as String?),
              recordedAt: Value(noteData['recordedAt'] != null
                  ? DateTime.parse(noteData['recordedAt'] as String)
                  : createdAt),
              isPinned: Value(isPinned),
              isArchived: Value(isArchived),
              isDeleted: Value(isDeleted),
              createdAt: Value(createdAt),
              updatedAt: Value(updatedAt),
              isSynced: const Value(true), // Mark as synced
            ),
          );
          debugPrint('✅ [ApiSync] Created voice note V2: $clientNoteUuid');

          // Download audio file if it's a server path
          if (serverAudioPath.isNotEmpty && !serverAudioPath.startsWith('/data/')) {
            await _downloadAudioFile(serverAudioPath, clientNoteUuid);
          }

          // Restore folder relations
          await _restoreFolderRelationsV2(clientNoteUuid, noteData, 'voice');
          break;

        case 'todo':
          // Create todo list note
          final todoNoteId = await _database.into(_database.todoListNotesV2).insert(
            TodoListNotesV2Companion(
              uuid: Value(clientNoteUuid),
              title: Value(title),
              isPinned: Value(isPinned),
              isArchived: Value(isArchived),
              isDeleted: Value(isDeleted),
              createdAt: Value(createdAt),
              updatedAt: Value(updatedAt),
              isSynced: const Value(true), // Mark as synced
            ),
          );

          // Create todo items with the note ID
          if (noteData.containsKey('todoItems')) {
            final items = noteData['todoItems'] as List;
            for (final item in items) {
              await _database.into(_database.todoItemsV2).insert(
                TodoItemsV2Companion(
                  uuid: Value(item['uuid'] as String),
                  todoListNoteId: Value(todoNoteId),
                  todoListNoteUuid: Value(clientNoteUuid),
                  content: Value(item['text'] as String),
                  isCompleted: Value(item['isDone'] as bool),
                  orderIndex: Value(item['orderIndex'] as int),
                  createdAt: Value(createdAt),
                  updatedAt: Value(updatedAt),
                  isSynced: const Value(true),
                ),
              );
            }
            debugPrint('✅ [ApiSync] Created todo note V2 with ${items.length} items: $clientNoteUuid');
          }

          // Restore folder relations
          await _restoreFolderRelationsV2(clientNoteUuid, noteData, 'todo');
          break;

        case 'reminder':
          await _database.into(_database.reminderNotesV2).insert(
            ReminderNotesV2Companion(
              uuid: Value(clientNoteUuid),
              title: Value(title),
              description: Value(noteData['reminderDescription'] as String?),
              reminderTime: Value(DateTime.parse(noteData['reminderTime'] as String)),
              isTriggered: Value(noteData['isTriggered'] as bool? ?? false),
              isPinned: Value(isPinned),
              isArchived: Value(isArchived),
              isDeleted: Value(isDeleted),
              createdAt: Value(createdAt),
              updatedAt: Value(updatedAt),
              isSynced: const Value(true), // Mark as synced
            ),
          );
          debugPrint('✅ [ApiSync] Created reminder note V2: $clientNoteUuid');

          // Restore folder relations
          await _restoreFolderRelationsV2(clientNoteUuid, noteData, 'reminder');
          break;

        default:
          debugPrint('⚠️ [ApiSync] Unknown note type: $noteType');
          return;
      }

      debugPrint('✅ [ApiSync] Successfully created V2 note $clientNoteUuid');
    } catch (e, stackTrace) {
      debugPrint('❌ [ApiSync] Failed to create V2 note: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Download audio file from backend to local storage
  Future<void> _downloadAudioFile(String serverFilePath, String noteUuid) async {
    try {
      debugPrint('📥 [ApiSync] Downloading audio file: $serverFilePath');

      // Get app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${appDir.path}/audio');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      // Generate local filename using note UUID
      final extension = serverFilePath.split('.').last;
      final localFileName = '$noteUuid.$extension';
      final localFilePath = '${audioDir.path}/$localFileName';

      // Check if file already exists
      final localFile = File(localFilePath);
      if (await localFile.exists()) {
        debugPrint('ℹ️ [ApiSync] Audio file already exists locally: $localFilePath');

        // Update voice note with local path
        await (_database.update(_database.voiceNotesV2)
              ..where((tbl) => tbl.uuid.equals(noteUuid)))
            .write(VoiceNotesV2Companion(
          audioFilePath: Value(localFilePath),
        ));
        return;
      }

      // Download audio file
      await _apiService.downloadAudioFile(serverFilePath, localFilePath);
      debugPrint('✅ [ApiSync] Audio downloaded to: $localFilePath');

      // Update voice note with local path
      await (_database.update(_database.voiceNotesV2)
            ..where((tbl) => tbl.uuid.equals(noteUuid)))
          .write(VoiceNotesV2Companion(
        audioFilePath: Value(localFilePath),
      ));

      debugPrint('✅ [ApiSync] Updated voice note with local path');
    } catch (e) {
      debugPrint('❌ [ApiSync] Failed to download audio: $e');
      // Don't throw - audio download failure shouldn't break sync
    }
  }

  /// Get device ID for sync
  Future<String> _getDeviceId() async {
    // Try to get from subscription manager or generate one
    // For now, use a simple approach
    return 'flutter_device_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Get note by UUID from V2 tables
  /// Returns a wrapper object indicating which table the note was found in
  Future<_V2NoteWrapper?> _getNoteByUuidV2(String uuid) async {
    // Check text notes
    final textNote = await (_database.select(_database.textNotesV2)
          ..where((tbl) => tbl.uuid.equals(uuid)))
        .getSingleOrNull();
    if (textNote != null) {
      return _V2NoteWrapper(type: 'text', note: textNote);
    }

    // Check voice notes
    final voiceNote = await (_database.select(_database.voiceNotesV2)
          ..where((tbl) => tbl.uuid.equals(uuid)))
        .getSingleOrNull();
    if (voiceNote != null) {
      return _V2NoteWrapper(type: 'voice', note: voiceNote);
    }

    // Check todo notes
    final todoNote = await (_database.select(_database.todoListNotesV2)
          ..where((tbl) => tbl.uuid.equals(uuid)))
        .getSingleOrNull();
    if (todoNote != null) {
      // Also get todo items
      final todoItems = await (_database.select(_database.todoItemsV2)
            ..where((tbl) => tbl.todoListNoteUuid.equals(uuid)))
          .get();
      return _V2NoteWrapper(type: 'todo', note: todoNote, todoItems: todoItems);
    }

    // Check reminder notes
    final reminderNote = await (_database.select(_database.reminderNotesV2)
          ..where((tbl) => tbl.uuid.equals(uuid)))
        .getSingleOrNull();
    if (reminderNote != null) {
      return _V2NoteWrapper(type: 'reminder', note: reminderNote);
    }

    return null;
  }

  /// OLD METHOD - Keep for reference
  /// Get note by UUID
  Future<Note?> _getNoteByUuid(String uuid) async {
    return await (_database.select(_database.notes)
          ..where((tbl) => tbl.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  /// Download and restore reminders from backend
  Future<int> _downloadReminders() async {
    try {
      debugPrint('⏰ [ApiSync] Fetching reminders from backend...');

      // Fetch all active reminders from backend
      final backendReminders = await _apiService.getReminders(
        includeTriggered: false, // Only get active reminders
      );

      debugPrint('⏰ [ApiSync] Downloaded ${backendReminders.length} reminders from server');

      if (backendReminders.isEmpty) {
        return 0;
      }

      int restoredCount = 0;

      for (final reminderData in backendReminders) {
        try {
          final noteUuid = reminderData['note_uuid'] as String;
          final title = reminderData['title'] as String?;
          final notificationTitle = reminderData['notification_title'] as String?;
          final notificationContent = reminderData['notification_content'] as String?;
          final description = reminderData['description'] as String?;
          final reminderTimeStr = reminderData['reminder_time'] as String;
          final reminderTime = DateTime.parse(reminderTimeStr);
          final recurrenceType = reminderData['recurrence_type'] as String? ?? 'once';
          final recurrenceInterval = reminderData['recurrence_interval'] as int? ?? 1;
          final recurrenceEndType = reminderData['recurrence_end_type'] as String? ?? 'never';
          final recurrenceEndValue = reminderData['recurrence_end_value'] as String?;
          final parentReminderId = reminderData['parent_reminder_id'] as String?;
          final occurrenceNumber = reminderData['occurrence_number'] as int? ?? 1;
          final seriesId = reminderData['series_id'] as String?;

          debugPrint('⏰ [ApiSync] Processing reminder for note: $noteUuid (occurrence $occurrenceNumber)');

          // Check if reminder already exists locally (by UUID AND occurrence number for recurring reminders)
          final existing = await (_database.select(_database.reminderNotesV2)
                ..where((tbl) => tbl.uuid.equals(noteUuid))
                ..where((tbl) => tbl.occurrenceNumber.equals(occurrenceNumber)))
              .getSingleOrNull();

          if (existing != null) {
            // Update existing reminder if server version is different
            if (existing.reminderTime != reminderTime ||
                existing.title != title ||
                existing.notificationTitle != notificationTitle ||
                existing.notificationContent != notificationContent ||
                existing.recurrenceType != recurrenceType) {
              await (_database.update(_database.reminderNotesV2)
                    ..where((tbl) => tbl.uuid.equals(noteUuid))
                    ..where((tbl) => tbl.occurrenceNumber.equals(occurrenceNumber)))
                  .write(ReminderNotesV2Companion(
                title: Value(title),
                notificationTitle: Value(notificationTitle),
                notificationContent: Value(notificationContent),
                description: Value(description),
                reminderTime: Value(reminderTime),
                recurrenceType: Value(recurrenceType),
                recurrenceInterval: Value(recurrenceInterval),
                recurrenceEndType: Value(recurrenceEndType),
                recurrenceEndValue: Value(recurrenceEndValue),
                parentReminderId: Value(parentReminderId),
                occurrenceNumber: Value(occurrenceNumber),
                seriesId: Value(seriesId),
                isSynced: const Value(true),
                updatedAt: Value(DateTime.now()),
              ));
              debugPrint('✅ [ApiSync] Updated reminder for note $noteUuid occurrence $occurrenceNumber');
              restoredCount++;
            } else {
              debugPrint('ℹ️ [ApiSync] Reminder $noteUuid occurrence $occurrenceNumber already up to date');
            }
          } else {
            // Create new reminder from server data
            await _database.into(_database.reminderNotesV2).insert(
                  ReminderNotesV2Companion(
                    uuid: Value(noteUuid),
                    title: Value(title),
                    notificationTitle: Value(notificationTitle),
                    notificationContent: Value(notificationContent),
                    description: Value(description),
                    reminderTime: Value(reminderTime),
                    recurrenceType: Value(recurrenceType),
                    recurrenceInterval: Value(recurrenceInterval),
                    recurrenceEndType: Value(recurrenceEndType),
                    recurrenceEndValue: Value(recurrenceEndValue),
                    parentReminderId: Value(parentReminderId),
                    occurrenceNumber: Value(occurrenceNumber),
                    seriesId: Value(seriesId),
                    isTriggered: const Value(false),
                    isPinned: const Value(false),
                    isArchived: const Value(false),
                    isDeleted: const Value(false),
                    isSynced: const Value(true),
                    createdAt: Value(DateTime.now()),
                    updatedAt: Value(DateTime.now()),
                  ),
                );
            debugPrint('✅ [ApiSync] Created reminder for note $noteUuid occurrence $occurrenceNumber');
            restoredCount++;
          }
        } catch (e) {
          debugPrint('❌ [ApiSync] Failed to process reminder: $e');
          // Continue with other reminders
        }
      }

      debugPrint('⏰ [ApiSync] Restored $restoredCount reminders');
      return restoredCount;
    } catch (e) {
      debugPrint('❌ [ApiSync] Failed to download reminders: $e');
      rethrow;
    }
  }
}
