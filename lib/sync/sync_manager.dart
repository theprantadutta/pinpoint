import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pinpoint/sync/sync_service.dart';
import 'package:pinpoint/services/premium_service.dart';
import 'package:pinpoint/services/connectivity_service.dart';

/// Sync manager to handle sync operations throughout the app
class SyncManager with ChangeNotifier {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  SyncService? _syncService;
  bool _isInitialized = false;
  bool _isSyncing = false; // Lock to prevent concurrent syncs
  bool _hasCompletedInitialSync = false; // Track if initial sync done this session

  // Offline-first: auto-flush pending changes when connectivity is restored.
  StreamSubscription<ConnectivityStatus>? _connectivitySub;
  Timer? _reconnectDebounce;

  SyncStatus get status => _syncService?.status ?? SyncStatus.idle;
  String get lastSyncMessage => _syncService?.lastSyncMessage ?? '';
  int get lastSyncTimestamp => _syncService?.lastSyncTimestamp ?? 0;
  bool get isSyncing => _isSyncing;
  bool get hasCompletedInitialSync => _hasCompletedInitialSync;

  /// Get current sync progress
  SyncProgress get progress => _syncService?.progress ?? SyncProgress.idle();

  // The phase-specific status text used to live here as English literals.
  // It now lives in lib/util/sync_phase_labels.dart, which renders the phase
  // through AppL10n at the point of display — this class has no BuildContext.

  /// Initialize the sync manager with a sync service
  Future<void> init({SyncService? syncService}) async {
    if (_isInitialized) return;

    if (syncService != null) {
      _syncService = syncService;
      await _syncService!.init();
    }

    _isInitialized = true;
    _listenForReconnect();
    notifyListeners();
  }

  /// Auto-flush pending changes when connectivity is restored (offline-first):
  /// edits made offline upload as soon as the network returns — no need to wait
  /// for the next app launch or a manual sync. Debounced and guarded against
  /// concurrent syncs. Subscription is set up once (this is a singleton).
  void _listenForReconnect() {
    if (_connectivitySub != null) return;
    _connectivitySub = ConnectivityService().onStatusChange.listen((status) {
      if (status != ConnectivityStatus.online) return;
      _reconnectDebounce?.cancel();
      _reconnectDebounce = Timer(const Duration(seconds: 2), () async {
        if (_syncService == null || _isSyncing) return;
        try {
          debugPrint('🌐 [SyncManager] Connectivity restored — syncing');
          await sync();
        } catch (e) {
          debugPrint('⚠️ [SyncManager] Reconnect sync failed: $e');
        }
      });
    });
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

      // No client-side gate on the free 50-note cap: the server admits new
      // notes up to the cap and holds back the rest (SyncResult.notesOverLimit),
      // while edits, deletions and downloads always go through.
      // Perform the actual sync
      final result = await _syncService!.sync(direction: direction);

      // After successful sync, update usage stats from backend
      if (result.success) {
        _hasCompletedInitialSync = true;
        await _syncUsageStatsWithBackend();
      }

      return result;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Sync usage stats with backend after sync operation
  /// Only syncs if stats are stale (>1 hour old) to reduce API calls
  Future<void> _syncUsageStatsWithBackend() async {
    try {
      final premiumService = PremiumService();

      // Only fetch usage stats if they're stale (reduces API calls)
      if (premiumService.shouldRefreshUsageStats()) {
        await premiumService.syncUsageWithBackend();
        debugPrint('✅ [SyncManager] Synced usage stats with backend');
      } else {
        debugPrint(
            '⏭️ [SyncManager] Usage stats still fresh, skipping sync');
      }

      // Auto-reconcile if needed (already checks timing internally)
      await premiumService.autoReconcileIfNeeded();
    } catch (e) {
      debugPrint('⚠️ [SyncManager] Could not sync usage stats: $e');
      // Don't fail the sync if usage stats sync fails
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
    _reconnectDebounce?.cancel();
    _connectivitySub?.cancel();
    _syncService?.dispose();
    super.dispose();
  }
}
