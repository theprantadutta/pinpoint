import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../services/api_service.dart';
import '../services/encryption_service.dart';
import 'sync_service.dart';
import 'folder_sync_service.dart';

/// Cloud-based sync service using API backend
class ApiSyncService extends SyncService {
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
    // Load last sync time from preferences if needed
    _lastSyncTime = 0; // TODO: Load from SharedPreferences
  }

  @override
  Future<bool> isConfigured() async {
    // Check if user is authenticated
    try {
      await _apiService.getSubscriptionStatus();
      return true;
    } catch (e) {
      return false;
    }
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
      debugPrint('\n🔼 [ApiSync] ========== STARTING UPLOAD ==========');

      // Get all notes that need syncing (modified since last sync or never synced)
      final notesToSync = await _getNotesToUpload();
      debugPrint('🔼 [ApiSync] Found ${notesToSync.length} notes to upload');

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

      for (final note in notesToSync) {
        try {
          debugPrint(
              '🔼 [ApiSync] Encrypting note ${note.id} (${note.noteType}): "${note.noteTitle}"');
          final encryptedNote = await _serializeAndEncryptNote(note);
          encryptedNotes.add(encryptedNote);
          debugPrint('✅ [ApiSync] Note ${note.id} encrypted successfully');
        } catch (e) {
          debugPrint('❌ [ApiSync] Failed to encrypt note ${note.id}: $e');
          // Skip this note and continue with others
        }
      }

      if (encryptedNotes.isEmpty) {
        return SyncResult(
          success: false,
          message: 'Failed to encrypt notes',
          notesSynced: 0,
        );
      }

      // Get device ID
      final deviceId = await _getDeviceId();

      // Upload to backend
      final response = await _apiService.syncNotes(
        notes: encryptedNotes,
        deviceId: deviceId,
      );

      final syncedCount = response['synced_count'] ?? 0;
      debugPrint('✅ [ApiSync] Uploaded $syncedCount notes successfully');

      // Mark all uploaded notes as synced
      for (final note in notesToSync) {
        await (_database.update(_database.notes)
              ..where((tbl) => tbl.id.equals(note.id)))
            .write(const NotesCompanion(isSynced: Value(true)));
        debugPrint('  ✓ Marked note ${note.id} as synced');
      }

      debugPrint('🔼 [ApiSync] ========== UPLOAD COMPLETE ==========\n');

      return SyncResult(
        success: true,
        message: 'Uploaded $syncedCount notes',
        notesSynced: syncedCount,
      );
    } catch (e) {
      debugPrint('❌ [ApiSync] Upload failed: $e');
      return SyncResult(
        success: false,
        message: 'Upload failed: ${e.toString()}',
      );
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

      // Update last sync time
      _lastSyncTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

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

  /// Get all notes that need to be uploaded (not yet synced)
  Future<List<Note>> _getNotesToUpload() async {
    // Get ALL notes that haven't been synced yet (including deleted ones)
    // Deleted notes need to be uploaded so the server knows they were deleted
    final unsyncedNotes = await (_database.select(_database.notes)
          ..where((tbl) => tbl.isSynced.equals(false)))
        .get();

    debugPrint(
        '🔼 [ApiSync] Found ${unsyncedNotes.length} unsynced notes to upload (including ${unsyncedNotes.where((n) => n.isDeleted).length} deleted)');
    return unsyncedNotes;
  }

  /// Serialize note and encrypt for upload
  Future<Map<String, dynamic>> _serializeAndEncryptNote(Note note) async {
    // Build complete note data structure
    final noteData = await _buildNoteDataStructure(note);

    // Convert to JSON string
    final jsonString = jsonEncode(noteData);

    // Encrypt the JSON
    final encryptedData = SecureEncryptionService.encrypt(jsonString);

    // Build metadata (non-sensitive)
    final metadata = {
      'type': note.noteType,
      'updated_at': note.updatedAt.toIso8601String(),
      'has_audio': note.noteType == 'audio',
      'has_attachments': false, // TODO: Check if note has attachments
      'is_archived': note.isArchived,
      'is_deleted': note.isDeleted,
    };

    final payload = {
      'client_note_id': note.id,  // CRITICAL: Backend needs this for unique constraint
      'client_note_uuid': note.uuid,
      'encrypted_data': encryptedData,
      'metadata': metadata,
      'version': 1,
    };

    debugPrint('🔍 [ApiSync] Payload for note ${note.uuid}: client_note_id=${note.id}');

    return payload;
  }

  /// Build complete note data structure with all related data
  Future<Map<String, dynamic>> _buildNoteDataStructure(Note note) async {
    final data = <String, dynamic>{
      'uuid': note.uuid,
      'noteTitle': note.noteTitle,
      'noteType': note.noteType,
      'isPinned': note.isPinned,
      'isArchived': note.isArchived,
      'isDeleted': note.isDeleted,
      'createdAt': note.createdAt.toIso8601String(),
      'updatedAt': note.updatedAt.toIso8601String(),
    };

    // Add type-specific data
    switch (note.noteType) {
      case 'text':
        final textNote = await (_database.select(_database.textNotes)
              ..where((tbl) => tbl.noteId.equals(note.id)))
            .getSingleOrNull();
        if (textNote != null) {
          data['content'] = textNote.content;
        }
        break;

      case 'audio':
        final audioNote = await (_database.select(_database.audioNotes)
              ..where((tbl) => tbl.noteId.equals(note.id)))
            .getSingleOrNull();
        if (audioNote != null) {
          data['audioFilePath'] = audioNote.audioFilePath;
          data['audioDuration'] = audioNote.durationSeconds;
        }
        break;

      case 'todo':
        // Get todo items
        final todoItems = await (_database.select(_database.noteTodoItems)
              ..where((tbl) => tbl.noteId.equals(note.id))
              ..orderBy([(tbl) => OrderingTerm(expression: tbl.orderIndex)]))
            .get();

        data['todoItems'] = todoItems
            .map((item) => {
                  'uuid': item.uuid,
                  'text': item.todoTitle,
                  'isDone': item.isDone,
                  'orderIndex': item.orderIndex,
                })
            .toList();
        break;

      case 'reminder':
        final reminderNote = await (_database.select(_database.reminderNotes)
              ..where((tbl) => tbl.noteId.equals(note.id)))
            .getSingleOrNull();
        if (reminderNote != null) {
          data['reminderDescription'] = reminderNote.description;
          data['reminderTime'] = reminderNote.reminderTime.toIso8601String();
        }
        break;
    }

    // Add folder relationships (using folder UUIDs)
    final folderRelations =
        await (_database.select(_database.noteFolderRelations)
              ..where((tbl) => tbl.noteId.equals(note.id)))
            .get();

    if (folderRelations.isNotEmpty) {
      // Get folder UUIDs for each relation
      final folderUuids = <String>[];
      for (final rel in folderRelations) {
        final folder = await (_database.select(_database.noteFolders)
              ..where((tbl) => tbl.noteFolderId.equals(rel.noteFolderId)))
            .getSingleOrNull();
        if (folder != null) {
          folderUuids.add(folder.uuid);
        }
      }
      data['folderUuids'] = folderUuids;
    }

    return data;
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
    // Check if note exists by UUID
    final existingNote = await _getNoteByUuid(clientNoteUuid);

    if (existingNote != null) {
      // Update existing note
      await _updateExistingNote(clientNoteUuid, noteData, serverUpdatedAt);
    } else {
      // Create new note with the UUID
      await _createNoteFromData(clientNoteUuid, noteData);
    }
  }

  /// Update existing note with downloaded data
  Future<void> _updateExistingNote(
    String noteUuid,
    Map<String, dynamic> noteData,
    DateTime serverUpdatedAt,
  ) async {
    // Get note ID from UUID for updating related tables
    final note = await _getNoteByUuid(noteUuid);
    if (note == null) return;
    final noteId = note.id;

    // Update base note by UUID
    await (_database.update(_database.notes)
          ..where((tbl) => tbl.uuid.equals(noteUuid)))
        .write(
      NotesCompanion(
        noteTitle: Value(noteData['noteTitle'] as String?),
        noteType: Value(noteData['noteType'] as String),
        isPinned: Value(noteData['isPinned'] as bool),
        isArchived: Value(noteData['isArchived'] as bool),
        isDeleted: Value(noteData['isDeleted'] as bool),
        updatedAt: Value(serverUpdatedAt),
        isSynced: Value(true), // Mark as synced since we got it from server
      ),
    );

    // Update type-specific data
    final noteType = noteData['noteType'] as String;

    switch (noteType) {
      case 'text':
        if (noteData.containsKey('content')) {
          await (_database.update(_database.textNotes)
                ..where((tbl) => tbl.noteId.equals(noteId)))
              .write(
            TextNotesCompanion(
              content: Value(noteData['content'] as String),
            ),
          );
        }
        break;

      case 'todo':
        if (noteData.containsKey('todoItems')) {
          // Delete existing todo items
          await (_database.delete(_database.noteTodoItems)
                ..where((tbl) => tbl.noteId.equals(noteId)))
              .go();

          // Insert new todo items with UUIDs
          final items = noteData['todoItems'] as List;
          for (final item in items) {
            await _database.into(_database.noteTodoItems).insert(
                  NoteTodoItemsCompanion(
                    uuid: Value(item['uuid'] as String),
                    noteId: Value(noteId),
                    noteUuid: Value(noteUuid),
                    todoTitle: Value(item['text'] as String),
                    isDone: Value(item['isDone'] as bool),
                    orderIndex: Value(item['orderIndex'] as int),
                  ),
                );
          }
        }
        break;

      case 'reminder':
        if (noteData.containsKey('reminderDescription')) {
          await (_database.update(_database.reminderNotes)
                ..where((tbl) => tbl.noteId.equals(noteId)))
              .write(
            ReminderNotesCompanion(
              description: Value(noteData['reminderDescription'] as String),
              reminderTime:
                  Value(DateTime.parse(noteData['reminderTime'] as String)),
            ),
          );
        }
        break;
    }

    // Update folder relationships (using folder UUIDs)
    if (noteData.containsKey('folderUuids')) {
      final folderUuids = (noteData['folderUuids'] as List).cast<String>();

      // Delete existing folder relations
      await (_database.delete(_database.noteFolderRelations)
            ..where((tbl) => tbl.noteId.equals(noteId)))
          .go();

      // Create new folder relations by looking up folder IDs from UUIDs
      for (final folderUuid in folderUuids) {
        final folder = await (_database.select(_database.noteFolders)
              ..where((tbl) => tbl.uuid.equals(folderUuid)))
            .getSingleOrNull();

        if (folder != null) {
          await _database.into(_database.noteFolderRelations).insert(
                NoteFolderRelationsCompanion(
                  noteId: Value(noteId),
                  noteFolderId: Value(folder.noteFolderId),
                ),
              );
        }
      }
      debugPrint(
          '✅ [ApiSync] Updated ${folderUuids.length} folder relations for note $noteUuid');
    }

    debugPrint('✅ [ApiSync] Updated note $noteUuid');
  }

  /// Create new note from downloaded data
  Future<void> _createNoteFromData(
    String clientNoteUuid,
    Map<String, dynamic> noteData,
  ) async {
    try {
      debugPrint(
          '📝 [ApiSync] Creating new note from server data (uuid: $clientNoteUuid)');

      final noteType = noteData['noteType'] as String;

      // Create base note with the UUID from server
      final noteId = await _database.into(_database.notes).insert(
            NotesCompanion(
              uuid: Value(clientNoteUuid),
              noteTitle: Value(noteData['noteTitle'] as String?),
              noteType: Value(noteType),
              isPinned: Value(noteData['isPinned'] as bool? ?? false),
              isArchived: Value(noteData['isArchived'] as bool? ?? false),
              isDeleted: Value(noteData['isDeleted'] as bool? ?? false),
              createdAt: Value(DateTime.parse(noteData['createdAt'] as String)),
              updatedAt: Value(DateTime.parse(noteData['updatedAt'] as String)),
              isSynced:
                  Value(true), // Mark as synced since we got it from server
            ),
          );

      // Create type-specific data
      switch (noteType) {
        case 'text':
          if (noteData.containsKey('content')) {
            await _database.into(_database.textNotes).insert(
                  TextNotesCompanion(
                    noteId: Value(noteId),
                    content: Value(noteData['content'] as String?),
                  ),
                );
          }
          break;

        case 'audio':
          if (noteData.containsKey('audioFilePath')) {
            await _database.into(_database.audioNotes).insert(
                  AudioNotesCompanion(
                    noteId: Value(noteId),
                    audioFilePath: Value(noteData['audioFilePath'] as String),
                    durationSeconds: Value(noteData['audioDuration'] as int?),
                    recordedAt:
                        Value(DateTime.parse(noteData['createdAt'] as String)),
                  ),
                );
          }
          break;

        case 'todo':
          // Create todo note entry
          await _database.into(_database.todoNotes).insert(
                TodoNotesCompanion(
                  noteId: Value(noteId),
                  totalItems: Value(0),
                  completedItems: Value(0),
                ),
              );

          // Create todo items with UUIDs
          if (noteData.containsKey('todoItems')) {
            final items = noteData['todoItems'] as List;
            for (final item in items) {
              await _database.into(_database.noteTodoItems).insert(
                    NoteTodoItemsCompanion(
                      uuid: Value(item['uuid'] as String),
                      noteId: Value(noteId),
                      noteUuid: Value(clientNoteUuid),
                      todoTitle: Value(item['text'] as String),
                      isDone: Value(item['isDone'] as bool),
                      orderIndex: Value(item['orderIndex'] as int),
                    ),
                  );
            }
          }
          break;

        case 'reminder':
          if (noteData.containsKey('reminderTime')) {
            await _database.into(_database.reminderNotes).insert(
                  ReminderNotesCompanion(
                    noteId: Value(noteId),
                    description:
                        Value(noteData['reminderDescription'] as String?),
                    reminderTime: Value(
                        DateTime.parse(noteData['reminderTime'] as String)),
                  ),
                );
          }
          break;
      }

      // Create folder relationships (using folder UUIDs)
      if (noteData.containsKey('folderUuids')) {
        final folderUuids = (noteData['folderUuids'] as List).cast<String>();

        for (final folderUuid in folderUuids) {
          // Look up folder ID from UUID
          final folder = await (_database.select(_database.noteFolders)
                ..where((tbl) => tbl.uuid.equals(folderUuid)))
              .getSingleOrNull();

          if (folder != null) {
            await _database.into(_database.noteFolderRelations).insert(
                  NoteFolderRelationsCompanion(
                    noteId: Value(noteId),
                    noteFolderId: Value(folder.noteFolderId),
                  ),
                );
          }
        }
        debugPrint(
            '✅ [ApiSync] Created ${folderUuids.length} folder relations for note $clientNoteUuid');
      }

      debugPrint(
          '✅ [ApiSync] Created note $clientNoteUuid');
    } catch (e, stackTrace) {
      debugPrint('❌ [ApiSync] Failed to create note: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Get device ID for sync
  Future<String> _getDeviceId() async {
    // Try to get from subscription manager or generate one
    // For now, use a simple approach
    return 'flutter_device_${DateTime.now().millisecondsSinceEpoch}';
  }

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
          final description = reminderData['description'] as String?;
          final reminderTimeStr = reminderData['reminder_time'] as String;
          final reminderTime = DateTime.parse(reminderTimeStr);

          debugPrint('⏰ [ApiSync] Processing reminder for note: $noteUuid');

          // Check if reminder already exists locally
          final existing = await (_database.select(_database.reminderNotesV2)
                ..where((tbl) => tbl.uuid.equals(noteUuid)))
              .getSingleOrNull();

          if (existing != null) {
            // Update existing reminder if server version is different
            if (existing.reminderTime != reminderTime ||
                existing.title != title ||
                existing.description != description) {
              await (_database.update(_database.reminderNotesV2)
                    ..where((tbl) => tbl.uuid.equals(noteUuid)))
                  .write(ReminderNotesV2Companion(
                title: Value(title),
                description: Value(description),
                reminderTime: Value(reminderTime),
                isSynced: const Value(true),
                updatedAt: Value(DateTime.now()),
              ));
              debugPrint('✅ [ApiSync] Updated reminder for note $noteUuid');
              restoredCount++;
            } else {
              debugPrint('ℹ️ [ApiSync] Reminder $noteUuid already up to date');
            }
          } else {
            // Create new reminder from server data
            await _database.into(_database.reminderNotesV2).insert(
                  ReminderNotesV2Companion(
                    uuid: Value(noteUuid),
                    title: Value(title),
                    description: Value(description),
                    reminderTime: Value(reminderTime),
                    isTriggered: const Value(false),
                    isPinned: const Value(false),
                    isArchived: const Value(false),
                    isDeleted: const Value(false),
                    isSynced: const Value(true),
                    createdAt: Value(DateTime.now()),
                    updatedAt: Value(DateTime.now()),
                  ),
                );
            debugPrint('✅ [ApiSync] Created reminder for note $noteUuid');
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
