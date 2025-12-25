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

/// Sync phase for detailed progress tracking
enum SyncPhase {
  idle,
  preparingFolders,
  syncingFolders,
  preparingNotes,
  uploadingNotes,
  downloadingNotes,
  processingNotes,
  syncingReminders,
  finalizing,
  completed,
  error,
}

/// Detailed sync progress tracking
class SyncProgress {
  final SyncPhase phase;
  final String message;
  final int currentItem;
  final int totalItems;
  final String? currentItemType; // 'folder', 'note', 'reminder', etc.
  final String? currentItemName; // Name of the item being processed
  final double? overallProgress; // 0.0 to 1.0

  const SyncProgress({
    required this.phase,
    required this.message,
    this.currentItem = 0,
    this.totalItems = 0,
    this.currentItemType,
    this.currentItemName,
    this.overallProgress,
  });

  /// Create an idle progress state
  factory SyncProgress.idle() => const SyncProgress(
    phase: SyncPhase.idle,
    message: 'Ready to sync',
  );

  /// Create a completed progress state
  factory SyncProgress.completed({String? message}) => SyncProgress(
    phase: SyncPhase.completed,
    message: message ?? 'Sync completed',
    overallProgress: 1.0,
  );

  /// Create an error progress state
  factory SyncProgress.error(String error) => SyncProgress(
    phase: SyncPhase.error,
    message: error,
  );

  /// Get progress percentage (0-100)
  int get percentComplete {
    if (overallProgress != null) {
      return (overallProgress! * 100).round();
    }
    if (totalItems == 0) return 0;
    return ((currentItem / totalItems) * 100).round();
  }

  /// Get a display-friendly progress string
  String get progressDisplay {
    if (totalItems > 0 && currentItem > 0) {
      return '$currentItem of $totalItems';
    }
    return '';
  }

  /// Whether sync is in an active state
  bool get isActive => phase != SyncPhase.idle &&
                        phase != SyncPhase.completed &&
                        phase != SyncPhase.error;

  @override
  String toString() => 'SyncProgress(phase: $phase, $currentItem/$totalItems, $message)';
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
  SyncProgress _progress = SyncProgress.idle();

  /// Optional callback for detailed progress updates
  void Function(SyncProgress progress)? onProgressUpdate;

  SyncStatus get status => _status;
  String get lastSyncMessage => _lastSyncMessage;
  int get lastSyncTimestamp => _lastSyncTimestamp;
  SyncProgress get progress => _progress;

  /// Update sync progress and notify listeners
  void updateProgress(SyncProgress progress) {
    _progress = progress;
    onProgressUpdate?.call(progress);
    notifyListeners();
  }

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
