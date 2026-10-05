import '../util/server_time.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../database/database.dart';
import '../services/api_service.dart';
import 'sync_service.dart';

/// Service for syncing folders with the backend
/// CRITICAL: This must ALWAYS run BEFORE note sync to prevent race conditions
class FolderSyncService {
  final ApiService _apiService;
  final AppDatabase _database;

  FolderSyncService({
    required ApiService apiService,
    required AppDatabase database,
  })  : _apiService = apiService,
        _database = database;

  /// Sync folders bidirectionally (upload then download)
  /// Returns SyncResult with foldersSynced count
  Future<SyncResult> syncFolders() async {
    try {
      debugPrint('\n📁 [FolderSync] ========== STARTING FOLDER SYNC ==========');

      // STEP 1: Upload local folders to server
      final uploadResult = await _uploadFolders();
      if (!uploadResult.success) {
        debugPrint('❌ [FolderSync] Upload failed: ${uploadResult.message}');
        return uploadResult;
      }

      // STEP 2: Download server folders to local
      final downloadResult = await _downloadFolders();
      if (!downloadResult.success) {
        debugPrint('❌ [FolderSync] Download failed: ${downloadResult.message}');
        return downloadResult;
      }

      final totalSynced = uploadResult.foldersSynced + downloadResult.foldersSynced;
      debugPrint('✅ [FolderSync] Synced $totalSynced folders total');
      debugPrint('📁 [FolderSync] ========== FOLDER SYNC COMPLETE ==========\n');

      return SyncResult(
        success: true,
        message: 'Synced $totalSynced folders',
        foldersSynced: totalSynced,
      );
    } catch (e, st) {
      debugPrint('❌ [FolderSync] Folder sync failed: $e');
      debugPrint('Stack trace: $st');
      return SyncResult(
        success: false,
        message: 'Folder sync failed: ${e.toString()}',
      );
    }
  }

  /// Upload local folders to server
  Future<SyncResult> _uploadFolders() async {
    try {
      debugPrint('🔼 [FolderSync] Uploading local folders...');

      // Get all local folders
      final localFolders = await _database.select(_database.noteFolders).get();
      debugPrint('🔼 [FolderSync] Found ${localFolders.length} local folders');

      if (localFolders.isEmpty) {
        debugPrint('✅ [FolderSync] No folders to upload');
        return SyncResult(
          success: true,
          message: 'No folders to upload',
          foldersSynced: 0,
        );
      }

      // Convert to API format
      final foldersData = localFolders.map((folder) {
        return {
          'uuid': folder.uuid,
          'title': folder.noteFolderTitle,
          // UTC with a 'Z': the server compares these for last-write-wins,
          // and a bare local timestamp is read there as UTC.
          'created_at': folder.createdAt.toUtc().toIso8601String(),
          'updated_at': folder.updatedAt.toUtc().toIso8601String(),
          // Sketchbook (schema v12). Folders are organisational and already
          // plaintext server-side, so these travel beside the title. A server
          // without the columns ignores them.
          'color': folder.color,
          'sort_order': folder.sortOrder,
        };
      }).toList();

      // Upload to backend
      final response = await _apiService.syncFolders(folders: foldersData);

      // The response carries the folders it now holds; there is no
      // 'synced_count' field (reading it always gave 0).
      final syncedCount = (response['folders'] as List?)?.length ??
          foldersData.length;
      debugPrint('✅ [FolderSync] Uploaded $syncedCount folders successfully');

      return SyncResult(
        success: true,
        message: 'Uploaded $syncedCount folders',
        foldersSynced: syncedCount,
      );
    } catch (e, st) {
      debugPrint('❌ [FolderSync] Upload failed: $e');
      debugPrint('Stack trace: $st');
      return SyncResult(
        success: false,
        message: 'Folder upload failed: ${e.toString()}',
      );
    }
  }

  /// Download folders from server and upsert locally
  Future<SyncResult> _downloadFolders() async {
    try {
      debugPrint('🔽 [FolderSync] Downloading folders from server...');

      // Fetch all folders from backend
      final response = await _apiService.getAllFolders();

      if (response.isEmpty) {
        debugPrint('✅ [FolderSync] No folders on server');
        return SyncResult(
          success: true,
          message: 'No folders to download',
          foldersSynced: 0,
        );
      }

      debugPrint('📥 [FolderSync] Downloaded ${response.length} folders from server');

      int upsertedCount = 0;

      // Process each folder
      for (final serverFolder in response) {
        try {
          final uuid = serverFolder['uuid'] as String;
          final title = serverFolder['title'] as String;
          final createdAt = parseServerUtc(serverFolder['created_at'] as String);
          final updatedAt = parseServerUtc(serverFolder['updated_at'] as String);
          // Absent on a server without the Sketchbook columns: keep local.
          final hasColor = serverFolder.containsKey('color');
          final hasOrder = serverFolder.containsKey('sort_order');
          final color = serverFolder['color'] as String?;
          final sortOrder = (serverFolder['sort_order'] as num?)?.toInt();

          debugPrint('🔽 [FolderSync] Processing folder: $uuid ($title)');

          // Check if folder exists locally
          final existingFolder = await (_database.select(_database.noteFolders)
                ..where((t) => t.uuid.equals(uuid)))
              .getSingleOrNull();

          if (existingFolder != null) {
            // Update existing folder if server version is newer
            if (updatedAt.isAfter(existingFolder.updatedAt)) {
              debugPrint('  ↻ Updating existing folder (server is newer)');
              await (_database.update(_database.noteFolders)
                    ..where((t) => t.uuid.equals(uuid)))
                  .write(
                NoteFoldersCompanion(
                  noteFolderTitle: Value(title),
                  updatedAt: Value(updatedAt),
                  color: hasColor ? Value(color) : const Value.absent(),
                  sortOrder:
                      hasOrder ? Value(sortOrder) : const Value.absent(),
                ),
              );
              upsertedCount++;
            } else {
              debugPrint('  ✓ Local folder is up-to-date');
            }
          } else {
            // Insert new folder
            debugPrint('  + Inserting new folder');
            await _database.into(_database.noteFolders).insert(
                  NoteFoldersCompanion(
                    uuid: Value(uuid),
                    noteFolderTitle: Value(title),
                    createdAt: Value(createdAt),
                    updatedAt: Value(updatedAt),
                    color: Value(color),
                    sortOrder: Value(sortOrder),
                  ),
                  mode: InsertMode.insertOrIgnore,
                );
            upsertedCount++;
          }
        } catch (e) {
          debugPrint('❌ [FolderSync] Failed to process folder: $e');
          // Continue with next folder
        }
      }

      debugPrint('✅ [FolderSync] Upserted $upsertedCount folders locally');

      return SyncResult(
        success: true,
        message: 'Downloaded $upsertedCount folders',
        foldersSynced: upsertedCount,
      );
    } catch (e, st) {
      debugPrint('❌ [FolderSync] Download failed: $e');
      debugPrint('Stack trace: $st');
      return SyncResult(
        success: false,
        message: 'Folder download failed: ${e.toString()}',
      );
    }
  }
}
