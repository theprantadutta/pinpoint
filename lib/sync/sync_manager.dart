import 'package:flutter/foundation.dart';
import 'package:pinpoint/sync/sync_service.dart';
import 'package:pinpoint/services/premium_service.dart';
import 'package:pinpoint/services/drift_note_service.dart';

/// Sync manager to handle sync operations throughout the app
class SyncManager with ChangeNotifier {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  SyncService? _syncService;
  bool _isInitialized = false;
  bool _isSyncing = false; // Lock to prevent concurrent syncs

  SyncStatus get status => _syncService?.status ?? SyncStatus.idle;
  String get lastSyncMessage => _syncService?.lastSyncMessage ?? '';
  int get lastSyncTimestamp => _syncService?.lastSyncTimestamp ?? 0;
  bool get isSyncing => _isSyncing;

  /// Initialize the sync manager with a sync service
  Future<void> init({SyncService? syncService}) async {
    if (_isInitialized) return;

    if (syncService != null) {
      _syncService = syncService;
      await _syncService!.init();
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Set the sync service (can be called after initialization)
  void setSyncService(SyncService syncService) {
    _syncService = syncService;
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

    // Skip if already syncing to prevent database lock conflicts
    if (_isSyncing) {
      debugPrint('⚠️ [SyncManager] Sync already in progress, skipping...');
      return SyncResult(
        success: true,
        message: 'Sync already in progress',
      );
    }

    try {
      _isSyncing = true;
      notifyListeners();

      // Check premium limits before syncing
      if (direction == SyncDirection.upload || direction == SyncDirection.both) {
        final limitCheck = await _checkSyncLimits();
        if (!limitCheck.success) {
          return limitCheck;
        }
      }

      // Perform the actual sync
      final result = await _syncService!.sync(direction: direction);

      // After successful sync, update usage stats from backend
      if (result.success) {
        await _syncUsageStatsWithBackend();
      }

      return result;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Sync usage stats with backend after sync operation
  Future<void> _syncUsageStatsWithBackend() async {
    try {
      final premiumService = PremiumService();

      // Fetch latest usage stats
      await premiumService.syncUsageWithBackend();
      debugPrint('✅ [SyncManager] Synced usage stats with backend');

      // Auto-reconcile after every sync to keep backend count accurate
      await premiumService.autoReconcileIfNeeded();
    } catch (e) {
      debugPrint('⚠️ [SyncManager] Could not sync usage stats: $e');
      // Don't fail the sync if usage stats sync fails
    }
  }

  /// Check if user can sync based on premium limits
  Future<SyncResult> _checkSyncLimits() async {
    final premiumService = PremiumService();

    // Premium users have no limits
    if (premiumService.isPremium) {
      return SyncResult(success: true, message: 'Premium - no limits');
    }

    // Get total note count
    try {
      final allNotes = await DriftNoteService.watchNotesWithDetails().first;
      final totalNotes = allNotes.length;

      // Check if exceeds free tier limit
      if (!premiumService.canSyncNote() || totalNotes > 50) {
        return SyncResult(
          success: false,
          message:
              'Sync limit reached: Free plan allows up to 50 notes. Upgrade to Premium for unlimited sync.',
        );
      }

      return SyncResult(success: true, message: 'Within limits');
    } catch (e) {
      debugPrint('Error checking sync limits: $e');
      // If we can\'t check, allow sync to proceed
      return SyncResult(
          success: true, message: 'Limit check failed, proceeding');
    }
  }

  /// Upload local changes only
  Future<SyncResult> upload() async {
    return await sync(direction: SyncDirection.upload);
  }

  /// Download cloud changes only
  Future<SyncResult> download() async {
    return await sync(direction: SyncDirection.download);
  }

  /// Get last sync timestamp as DateTime
  DateTime? get lastSyncDateTime {
    if (lastSyncTimestamp == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(lastSyncTimestamp);
  }

  @override
  void dispose() {
    _syncService?.dispose();
    super.dispose();
  }
}
