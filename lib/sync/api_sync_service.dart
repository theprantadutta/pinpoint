import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../services/api_service.dart';
import '../services/encryption_service.dart';
import '../services/drift_note_service.dart';
import 'sync_service.dart';

/// Cloud-based sync service using API backend
class ApiSyncService extends SyncService {
  final ApiService _apiService;
  final AppDatabase _database;

  int _lastSyncTime = 0;

  ApiSyncService({
    required ApiService apiService,
    required AppDatabase database,
  })  : _apiService = apiService,
        _database = database;

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
          debugPrint('🔼 [ApiSync] Encrypting note ${note.id} (${note.noteType}): "${note.noteTitle}"');
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

      debugPrint('📥 [ApiSync] Downloaded ${response.length} notes from server');

      int successCount = 0;
      int conflictCount = 0;

      // Process each note
      for (final encryptedNote in response) {
        try {
          final clientNoteId = encryptedNote['client_note_id'] as int;
          final encryptedData = encryptedNote['encrypted_data'] as String;
          final isDeleted = encryptedNote['is_deleted'] as bool? ?? false;
          final serverUpdatedAt = DateTime.parse(encryptedNote['updated_at']);

          debugPrint('\n🔽 [ApiSync] Processing note $clientNoteId (deleted: $isDeleted)');
          debugPrint('🔽 [ApiSync] Server updated_at: $serverUpdatedAt');

          // Check if note exists locally
          final existingNote = await DriftNoteService.getSingleNote(clientNoteId);
          debugPrint('🔽 [ApiSync] Local note ${existingNote != null ? "EXISTS" : "NOT FOUND"} (local updated: ${existingNote?.updatedAt})');

          if (existingNote != null) {
            // Conflict detection: compare timestamps
            // Only skip if local was modified AFTER the server version
            // AND local is more than 1 second newer (to account for clock skew)
            final timeDiff = existingNote.updatedAt.difference(serverUpdatedAt).inSeconds;
            if (timeDiff > 1) {
              debugPrint('⚠️ [ApiSync] CONFLICT: local is ${timeDiff}s newer - keeping local version');
              conflictCount++;
              // Keep local version (local wins)
              continue;
            } else {
              debugPrint('✅ [ApiSync] Server version is newer or same - will update local');
            }
          } else {
            debugPrint('📝 [ApiSync] Note does not exist locally - will create new');
          }

          // Decrypt and deserialize note
          debugPrint('🔓 [ApiSync] Decrypting note data...');
          final noteData = await _decryptAndDeserializeNote(encryptedData);
          debugPrint('✅ [ApiSync] Decryption successful');

          if (isDeleted) {
            // Soft-delete the note locally (mark as deleted but keep record)
            if (existingNote != null) {
              debugPrint('🗑️ [ApiSync] Soft-deleting note $clientNoteId locally');
              await (_database.update(_database.notes)
                    ..where((tbl) => tbl.id.equals(clientNoteId)))
                  .write(NotesCompanion(
                isDeleted: Value(true),
                updatedAt: Value(serverUpdatedAt),
                isSynced: Value(true), // Mark as synced since we got it from server
              ));
              successCount++;
            } else {
              // Note doesn't exist locally, nothing to delete
              debugPrint('ℹ️ [ApiSync] Note $clientNoteId doesn\'t exist locally, skipping deletion');
            }
          } else {
            // Update or create the note
            await _applyNoteToDatabase(clientNoteId, noteData, serverUpdatedAt);
            successCount++;
          }
        } catch (e) {
          debugPrint('❌ [ApiSync] Failed to process note: $e');
          // Continue with other notes
        }
      }

      // Update last sync time
      _lastSyncTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final message = conflictCount > 0
          ? 'Downloaded $successCount notes, $conflictCount conflicts (kept local)'
          : 'Downloaded $successCount notes';

      debugPrint('✅ [ApiSync] $message');
      debugPrint('🔽 [ApiSync] ========== DOWNLOAD COMPLETE ==========\n');

      return SyncResult(
        success: true,
        message: message,
        notesSynced: successCount,
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

    debugPrint('🔼 [ApiSync] Found ${unsyncedNotes.length} unsynced notes to upload (including ${unsyncedNotes.where((n) => n.isDeleted).length} deleted)');
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

    return {
      'client_note_id': note.id,
      'encrypted_data': encryptedData,
      'metadata': metadata,
      'version': 1,
    };
  }

  /// Build complete note data structure with all related data
  Future<Map<String, dynamic>> _buildNoteDataStructure(Note note) async {
    final data = <String, dynamic>{
      'id': note.id,
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
                  'id': item.id,
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

    // Add folder relationships
    final folderRelations = await (_database.select(_database.noteFolderRelations)
          ..where((tbl) => tbl.noteId.equals(note.id)))
        .get();

    if (folderRelations.isNotEmpty) {
      data['folderIds'] = folderRelations.map((rel) => rel.noteFolderId).toList();
    }

    return data;
  }

  /// Decrypt and deserialize note from encrypted data
  Future<Map<String, dynamic>> _decryptAndDeserializeNote(String encryptedData) async {
    // Decrypt the data
    final jsonString = SecureEncryptionService.decrypt(encryptedData);

    // Parse JSON
    final noteData = jsonDecode(jsonString) as Map<String, dynamic>;

    return noteData;
  }

  /// Apply downloaded note to local database
  Future<void> _applyNoteToDatabase(
    int clientNoteId,
    Map<String, dynamic> noteData,
    DateTime serverUpdatedAt,
  ) async {
    // Check if note exists
    final existingNote = await DriftNoteService.getSingleNote(clientNoteId);

    if (existingNote != null) {
      // Update existing note
      await _updateExistingNote(clientNoteId, noteData, serverUpdatedAt);
    } else {
      // Create new note with the client_note_id
      await _createNoteFromData(clientNoteId, noteData);
    }
  }

  /// Update existing note with downloaded data
  Future<void> _updateExistingNote(
    int noteId,
    Map<String, dynamic> noteData,
    DateTime serverUpdatedAt,
  ) async {
    // Update base note
    await (_database.update(_database.notes)
          ..where((tbl) => tbl.id.equals(noteId)))
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

          // Insert new todo items
          final items = noteData['todoItems'] as List;
          for (final item in items) {
            await _database.into(_database.noteTodoItems).insert(
                  NoteTodoItemsCompanion(
                    noteId: Value(noteId),
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
              reminderTime: Value(DateTime.parse(noteData['reminderTime'] as String)),
            ),
          );
        }
        break;
    }

    // Update folder relationships
    if (noteData.containsKey('folderIds')) {
      final folderIds = (noteData['folderIds'] as List).cast<int>();

      // Delete existing folder relations
      await (_database.delete(_database.noteFolderRelations)
            ..where((tbl) => tbl.noteId.equals(noteId)))
          .go();

      // Create new folder relations
      for (final folderId in folderIds) {
        await _database.into(_database.noteFolderRelations).insert(
          NoteFolderRelationsCompanion(
            noteId: Value(noteId),
            noteFolderId: Value(folderId),
          ),
        );
      }
      debugPrint('✅ [ApiSync] Updated ${folderIds.length} folder relations for note $noteId');
    }

    debugPrint('✅ [ApiSync] Updated note $noteId');
  }

  /// Create new note from downloaded data
  Future<void> _createNoteFromData(
    int clientNoteId,
    Map<String, dynamic> noteData,
  ) async {
    try {
      debugPrint('📝 [ApiSync] Creating new note from server data (client_id: $clientNoteId)');

      final noteType = noteData['noteType'] as String;

      // WARNING: This creates a note with a NEW local ID, not the original client_note_id
      // This means the same note will have different IDs on different devices
      // For proper multi-device sync, we need UUID-based identifiers instead of autoincrement

      // Create base note
      final noteId = await _database.into(_database.notes).insert(
        NotesCompanion(
          noteTitle: Value(noteData['noteTitle'] as String?),
          noteType: Value(noteType),
          isPinned: Value(noteData['isPinned'] as bool? ?? false),
          isArchived: Value(noteData['isArchived'] as bool? ?? false),
          isDeleted: Value(noteData['isDeleted'] as bool? ?? false),
          createdAt: Value(DateTime.parse(noteData['createdAt'] as String)),
          updatedAt: Value(DateTime.parse(noteData['updatedAt'] as String)),
          isSynced: Value(true), // Mark as synced since we got it from server
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
                recordedAt: Value(DateTime.parse(noteData['createdAt'] as String)),
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

          // Create todo items
          if (noteData.containsKey('todoItems')) {
            final items = noteData['todoItems'] as List;
            for (final item in items) {
              await _database.into(_database.noteTodoItems).insert(
                NoteTodoItemsCompanion(
                  noteId: Value(noteId),
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
                description: Value(noteData['reminderDescription'] as String?),
                reminderTime: Value(DateTime.parse(noteData['reminderTime'] as String)),
              ),
            );
          }
          break;
      }

      // Create folder relationships
      if (noteData.containsKey('folderIds')) {
        final folderIds = (noteData['folderIds'] as List).cast<int>();

        for (final folderId in folderIds) {
          await _database.into(_database.noteFolderRelations).insert(
            NoteFolderRelationsCompanion(
              noteId: Value(noteId),
              noteFolderId: Value(folderId),
            ),
          );
        }
        debugPrint('✅ [ApiSync] Created ${folderIds.length} folder relations for note $noteId');
      }

      debugPrint('✅ [ApiSync] Created note $noteId (from server client_id: $clientNoteId)');
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
}
