import 'package:flutter/foundation.dart';
import 'package:pinpoint/sync/file_sync_service.dart';
import 'package:pinpoint/sync/sync_service.dart';

/// Sync manager to handle sync operations throughout the app
class SyncManager with ChangeNotifier {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  SyncService? _syncService;
  bool _isInitialized = false;

  SyncStatus get status => _syncService?.status ?? SyncStatus.idle;
  String get lastSyncMessage => _syncService?.lastSyncMessage ?? '';
  int get lastSyncTimestamp => _syncService?.lastSyncTimestamp ?? 0;

  /// Initialize the sync manager
  Future<void> init() async {
    if (_isInitialized) return;

    // For now, we'll use the file sync service
    // In the future, this could be configured to use different backends
    _syncService = FileSyncService();
    await _syncService!.init();

    // Listen to sync service changes
    if (_syncService is FileSyncService) {
      (_syncService as FileSyncService).addListener(notifyListeners);
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Check if sync is configured and ready
  Future<bool> isConfigured() async {
    if (!_isInitialized || _syncService == null) return false;
    return await _syncService!.isConfigured();
  }

  /// Perform sync operation
  Future<SyncResult> sync(
      {SyncDirection direction = SyncDirection.both}) async {
    if (!_isInitialized || _syncService == null) {
      return SyncResult(
        success: false,
        message: 'Sync service not initialized',
      );
    }

    final result = await _syncService!.sync(direction: direction);
    notifyListeners();
    return result;
  }

  /// Upload local changes only
  Future<SyncResult> upload() async {
    return await sync(direction: SyncDirection.upload);
  }

  /// Download cloud changes only
  Future<SyncResult> download() async {
    return await sync(direction: SyncDirection.download);
  }

  /// Check if sync is currently in progress
  bool get isSyncing => status == SyncStatus.syncing;

  /// Get last sync timestamp as DateTime
  DateTime? get lastSyncDateTime {
    if (lastSyncTimestamp == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(lastSyncTimestamp);
  }

  @override
  void dispose() {
    if (_syncService is FileSyncService) {
      (_syncService as FileSyncService).removeListener(notifyListeners);
    }
    _syncService?.dispose();
    super.dispose();
  }
}
