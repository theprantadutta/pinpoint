/// Sync status enum
enum SyncStatus {
  idle,
  syncing,
  synced,
  error,
}

/// Sync direction enum
enum SyncDirection {
  upload, // Local to cloud
  download, // Cloud to local
  both, // Bidirectional
}

/// Sync result class
class SyncResult {
  final bool success;
  final String message;
  final int notesSynced;
  final int foldersSynced;
  final int tagsSynced;
  final int remindersSynced;
  final int notesFailed;
  final List<String> errors;
  final int decryptionErrors;

  SyncResult({
    required this.success,
    required this.message,
    this.notesSynced = 0,
    this.foldersSynced = 0,
    this.tagsSynced = 0,
    this.remindersSynced = 0,
    this.notesFailed = 0,
    this.errors = const [],
    this.decryptionErrors = 0,
  });

  /// Get a user-friendly summary of the sync result
  String get detailedSummary {
    final parts = <String>[];

    if (notesSynced > 0) parts.add('$notesSynced notes');
    if (foldersSynced > 0) parts.add('$foldersSynced folders');
    if (remindersSynced > 0) parts.add('$remindersSynced reminders');
    if (tagsSynced > 0) parts.add('$tagsSynced tags');

    final restored = parts.isEmpty ? 'No data' : parts.join(', ');

    if (notesFailed > 0 || decryptionErrors > 0) {
      return '$restored restored. $notesFailed failed${decryptionErrors > 0 ? ' ($decryptionErrors decryption errors)' : ''}';
    }

    return parts.isEmpty ? message : '$restored restored successfully';
  }
}

/// Base sync service class
abstract class SyncService {
  SyncStatus _status = SyncStatus.idle;
  String _lastSyncMessage = '';
  int _lastSyncTimestamp = 0;

  SyncStatus get status => _status;
  String get lastSyncMessage => _lastSyncMessage;
  int get lastSyncTimestamp => _lastSyncTimestamp;

  /// Initialize the sync service
  Future<void> init() async {
    // Initialize any required resources
  }

  /// Check if the service is configured and ready to sync
  Future<bool> isConfigured() async {
    return false;
  }

  /// Perform sync operation
  Future<SyncResult> sync(
      {SyncDirection direction = SyncDirection.both}) async {
    _status = SyncStatus.syncing;
    _lastSyncMessage = 'Starting sync...';
    notifyListeners();

    try {
      SyncResult result;

      switch (direction) {
        case SyncDirection.upload:
          result = await uploadChanges();
          break;
        case SyncDirection.download:
          result = await downloadChanges();
          break;
        case SyncDirection.both:
          final uploadResult = await uploadChanges();
          if (!uploadResult.success) {
            throw Exception('Upload failed: ${uploadResult.message}');
          }

          final downloadResult = await downloadChanges();
          if (!downloadResult.success) {
            throw Exception('Download failed: ${downloadResult.message}');
          }

          result = SyncResult(
            success: true,
            message: 'Sync completed successfully',
            notesSynced: uploadResult.notesSynced + downloadResult.notesSynced,
            foldersSynced:
                uploadResult.foldersSynced + downloadResult.foldersSynced,
            tagsSynced: uploadResult.tagsSynced + downloadResult.tagsSynced,
          );
          break;
      }

      _status = SyncStatus.synced;
      _lastSyncMessage = result.message;
      _lastSyncTimestamp = DateTime.now().millisecondsSinceEpoch;
      notifyListeners();

      return result;
    } catch (e) {
      _status = SyncStatus.error;
      _lastSyncMessage = 'Sync failed: ${e.toString()}';
      notifyListeners();

      return SyncResult(
        success: false,
        message: e.toString(),
      );
    }
  }

  /// Upload local changes to cloud
  /// Subclasses should override this method to implement actual upload logic
  Future<SyncResult> uploadChanges() async {
    // This should be implemented by subclasses
    return SyncResult(
      success: true,
      message: 'Upload completed',
    );
  }

  /// Download changes from cloud
  /// Subclasses should override this method to implement actual download logic
  Future<SyncResult> downloadChanges() async {
    // This should be implemented by subclasses
    return SyncResult(
      success: true,
      message: 'Download completed',
    );
  }

  /// Notify listeners about sync status changes
  void notifyListeners() {
    // This can be overridden by subclasses that need to notify UI
  }

  /// Cancel ongoing sync
  void cancelSync() {
    // This can be overridden by subclasses that need to support cancellation
  }

  /// Clean up resources
  void dispose() {
    // This can be overridden by subclasses that need to clean up resources
  }
}
