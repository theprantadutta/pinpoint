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

  SyncResult({
    required this.success,
    required this.message,
    this.notesSynced = 0,
    this.foldersSynced = 0,
    this.tagsSynced = 0,
  });
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
          result = await _uploadChanges();
          break;
        case SyncDirection.download:
          result = await _downloadChanges();
          break;
        case SyncDirection.both:
          final uploadResult = await _uploadChanges();
          if (!uploadResult.success) {
            throw Exception('Upload failed: ${uploadResult.message}');
          }

          final downloadResult = await _downloadChanges();
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
  Future<SyncResult> _uploadChanges() async {
    // This should be implemented by subclasses
    return SyncResult(
      success: true,
      message: 'Upload completed',
    );
  }

  /// Download changes from cloud
  Future<SyncResult> _downloadChanges() async {
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
