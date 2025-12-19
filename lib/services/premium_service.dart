import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/premium_limits.dart';
import 'subscription_manager.dart';
import 'api_service.dart';

/// Service for managing premium features and usage limits
class PremiumService extends ChangeNotifier {
  static final PremiumService _instance = PremiumService._internal();
  factory PremiumService() => _instance;
  PremiumService._internal();

  SharedPreferences? _prefs;
  bool _isPremium = false;
  bool _isInGracePeriod = false;
  String _subscriptionType = 'free';
  DateTime? _expiresAt;
  DateTime? _gracePeriodEndsAt;
  bool _isInitialized = false;

  bool get isPremium => _isPremium || _isInGracePeriod;
  bool get isInGracePeriod => _isInGracePeriod;
  String get subscriptionType => _subscriptionType;
  DateTime? get expiresAt => _expiresAt;
  DateTime? get gracePeriodEndsAt => _gracePeriodEndsAt;

  /// Initialize the service
  Future<void> initialize() async {
    // Prevent multiple initializations
    if (_isInitialized) {
      debugPrint('⏭️ [PremiumService] Already initialized, skipping...');
      return;
    }

    _prefs = await SharedPreferences.getInstance();
    await _loadPremiumStatus();
    await _checkMonthlyReset();

    // Auto-reconcile on app startup if needed (once per day)
    // This catches first-time migrations and periodic drift fixes
    try {
      await autoReconcileIfNeeded();
    } catch (e) {
      debugPrint('⚠️ [PremiumService] Initial auto-reconcile failed: $e');
      // Don't block initialization if reconcile fails
    }

    _isInitialized = true;
    debugPrint('✅ [PremiumService] Initialization complete');
  }

  /// Load premium status from Subscription Manager and backend API
  Future<void> _loadPremiumStatus() async {
    try {
      // First check local subscription manager
      final subscriptionManager = SubscriptionManager();
      _isPremium = subscriptionManager.isPremium;
      _isInGracePeriod = subscriptionManager.isInGracePeriod;
      _subscriptionType = subscriptionManager.subscriptionType ?? 'free';
      _expiresAt = subscriptionManager.expirationDate;
      _gracePeriodEndsAt = subscriptionManager.gracePeriodEndsAt;

      // Skip backend call if SubscriptionManager has fresh data
      // This reduces redundant API calls on app startup
      if (subscriptionManager.hasFreshData) {
        debugPrint(
            '💎 [PremiumService] Using fresh data from SubscriptionManager');
        debugPrint('   Premium status: $_isPremium');
        debugPrint('   In grace period: $_isInGracePeriod');
        debugPrint('   Subscription type: $_subscriptionType');
        notifyListeners();
        return;
      }

      // Only fetch from backend if SubscriptionManager data is stale
      try {
        final apiService = ApiService();
        final statusResponse = await apiService.getSubscriptionStatus();

        _isInGracePeriod = statusResponse['is_in_grace_period'] ?? false;

        if (statusResponse['grace_period_ends_at'] != null) {
          _gracePeriodEndsAt =
              DateTime.parse(statusResponse['grace_period_ends_at']);
        }

        // Update from backend if available (more authoritative)
        if (statusResponse['subscription_tier'] != null) {
          _subscriptionType = statusResponse['subscription_tier'];
        }

        if (statusResponse['subscription_expires_at'] != null) {
          _expiresAt =
              DateTime.parse(statusResponse['subscription_expires_at']);
        }

        // Check if we're premium based on backend (includes grace period)
        final isPremiumBackend = statusResponse['is_premium'] ?? false;
        if (isPremiumBackend && !_isPremium) {
          _isPremium = isPremiumBackend;
        }
      } catch (e) {
        debugPrint('⚠️ [PremiumService] Could not fetch backend status: $e');
        // Continue with local status
      }

      debugPrint('💎 [PremiumService] Premium status: $_isPremium');
      debugPrint('   In grace period: $_isInGracePeriod');
      debugPrint('   Subscription type: $_subscriptionType');
      if (_gracePeriodEndsAt != null) {
        debugPrint('   Grace period ends: $_gracePeriodEndsAt');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ [PremiumService] Error loading premium status: $e');
    }
  }

  /// Refresh premium status (call after purchase/restore)
  Future<void> refreshPremiumStatus() async {
    debugPrint('🔄 [PremiumService] Manually refreshing premium status...');
    await _loadPremiumStatus();
  }

  /// Fetch and cache usage stats from backend
  Future<Map<String, dynamic>?> fetchUsageStatsFromBackend() async {
    try {
      final apiService = ApiService();
      final stats = await apiService.getUsageStats();

      // Cache the backend stats locally for offline use
      await _cacheUsageStats(stats);

      debugPrint('📊 [PremiumService] Fetched usage stats from backend');
      debugPrint(
          '   Synced notes: ${stats['synced_notes']['current']}/${stats['synced_notes']['limit']}');
      debugPrint(
          '   OCR scans: ${stats['ocr_scans']['current']}/${stats['ocr_scans']['limit']}');
      debugPrint(
          '   Exports: ${stats['exports']['current']}/${stats['exports']['limit']}');

      return stats;
    } catch (e) {
      debugPrint(
          '⚠️ [PremiumService] Could not fetch usage stats from backend: $e');
      return null;
    }
  }

  /// Cache usage stats from backend response
  Future<void> _cacheUsageStats(Map<String, dynamic> stats) async {
    if (_prefs == null) return;

    try {
      // Update synced notes count from backend
      final syncedNotes = stats['synced_notes'];
      if (syncedNotes != null && syncedNotes['current'] != null) {
        await _prefs!.setInt(
          UsageTrackingKeys.syncedNotesCount,
          syncedNotes['current'] as int,
        );
      }

      // Update OCR scans count from backend
      final ocrScans = stats['ocr_scans'];
      if (ocrScans != null && ocrScans['current'] != null) {
        await _prefs!.setInt(
          UsageTrackingKeys.ocrScansThisMonth,
          ocrScans['current'] as int,
        );
      }

      // Update exports count from backend
      final exports = stats['exports'];
      if (exports != null && exports['current'] != null) {
        await _prefs!.setInt(
          UsageTrackingKeys.exportsThisMonth,
          exports['current'] as int,
        );
      }

      // Cache last update timestamp
      await _prefs!.setString(
        'usage_stats_last_updated',
        DateTime.now().toIso8601String(),
      );

      debugPrint('✅ [PremiumService] Cached usage stats locally');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [PremiumService] Error caching usage stats: $e');
    }
  }

  /// Reconcile usage counts with backend
  /// This fixes any discrepancies between local and server counts
  Future<Map<String, dynamic>?> reconcileUsageWithBackend() async {
    try {
      final apiService = ApiService();
      final result = await apiService.reconcileUsage();

      debugPrint('🔄 [PremiumService] Reconciliation result:');
      debugPrint('   Old count: ${result['old_count']}');
      debugPrint('   New count: ${result['new_count']}');
      debugPrint('   Reconciled: ${result['reconciled']}');

      // Update local count with reconciled value
      if (result['new_count'] != null) {
        await _prefs?.setInt(
          UsageTrackingKeys.syncedNotesCount,
          result['new_count'] as int,
        );
        notifyListeners();
      }

      return result;
    } catch (e) {
      debugPrint('⚠️ [PremiumService] Could not reconcile usage: $e');
      return null;
    }
  }

  /// Sync usage stats with backend (call after sync operations)
  Future<void> syncUsageWithBackend() async {
    await fetchUsageStatsFromBackend();
  }

  /// Get last time usage stats were synced with backend
  DateTime? getLastUsageSync() {
    final lastSyncString = _prefs?.getString('usage_stats_last_updated');
    if (lastSyncString == null) return null;
    return DateTime.parse(lastSyncString);
  }

  /// Check if usage stats are stale and need refreshing
  bool shouldRefreshUsageStats() {
    final lastSync = getLastUsageSync();
    if (lastSync == null) return true;

    // Refresh if older than 1 hour
    final hoursSinceSync = DateTime.now().difference(lastSync).inHours;
    return hoursSinceSync >= 1;
  }

  /// Get last time usage was reconciled
  DateTime? getLastReconciliation() {
    final lastReconcileString = _prefs?.getString('usage_last_reconcile');
    if (lastReconcileString == null) return null;
    return DateTime.parse(lastReconcileString);
  }

  /// Check if reconciliation is needed (once per hour to reduce API calls)
  bool shouldReconcile() {
    final lastReconcile = getLastReconciliation();
    if (lastReconcile == null) return true;

    // Only reconcile if more than 1 hour has passed
    final hoursSinceReconcile =
        DateTime.now().difference(lastReconcile).inHours;
    return hoursSinceReconcile >= 1;
  }

  /// Auto-reconcile usage if needed (called periodically)
  Future<void> autoReconcileIfNeeded() async {
    if (!shouldReconcile()) {
      debugPrint(
          '⏭️ [PremiumService] Skipping reconcile - last reconciled ${getLastReconciliation()}');
      return;
    }

    debugPrint('🔄 [PremiumService] Auto-reconciling usage after sync');

    try {
      final result = await reconcileUsageWithBackend();

      if (result != null) {
        // Store reconciliation timestamp
        await _prefs?.setString(
          'usage_last_reconcile',
          DateTime.now().toIso8601String(),
        );

        final reconciled = result['reconciled'] as bool;
        final oldCount = result['old_count'] as int;
        final newCount = result['new_count'] as int;

        if (reconciled) {
          debugPrint(
              '✅ [PremiumService] Auto-reconciled: $oldCount → $newCount notes');
        } else {
          debugPrint('✓ [PremiumService] Already in sync: $newCount notes');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [PremiumService] Auto-reconcile failed: $e');
      // Don't throw - reconciliation is not critical
    }
  }

  /// Check if monthly limits need to be reset
  Future<void> _checkMonthlyReset() async {
    if (_prefs == null) return;

    final lastResetString =
        _prefs!.getString(UsageTrackingKeys.lastMonthlyReset);
    final now = DateTime.now();

    if (lastResetString == null) {
      // First time, set last reset to now
      await _prefs!.setString(
        UsageTrackingKeys.lastMonthlyReset,
        now.toIso8601String(),
      );
      return;
    }

    final lastReset = DateTime.parse(lastResetString);

    // Check if we're in a new month
    if (now.year > lastReset.year || now.month > lastReset.month) {
      debugPrint('🔄 [PremiumService] Resetting monthly limits');
      await _resetMonthlyLimits();
      await _prefs!.setString(
        UsageTrackingKeys.lastMonthlyReset,
        now.toIso8601String(),
      );
    }
  }

  /// Reset monthly usage counters
  Future<void> _resetMonthlyLimits() async {
    if (_prefs == null) return;

    await _prefs!.setInt(UsageTrackingKeys.ocrScansThisMonth, 0);
    await _prefs!.setInt(UsageTrackingKeys.exportsThisMonth, 0);

    debugPrint('✅ [PremiumService] Monthly limits reset');
  }

  // ============================================
  // Cloud Sync Limits
  // ============================================

  /// Get current synced notes count
  int getSyncedNotesCount() {
    return _prefs?.getInt(UsageTrackingKeys.syncedNotesCount) ?? 0;
  }

  /// Check if user can sync more notes
  bool canSyncNote() {
    if (_isPremium) return true;

    final count = getSyncedNotesCount();
    return count < PremiumLimits.maxSyncedNotesForFree;
  }

  /// Increment synced notes count
  Future<void> incrementSyncedNotes() async {
    if (_prefs == null) return;

    final current = getSyncedNotesCount();
    await _prefs!.setInt(UsageTrackingKeys.syncedNotesCount, current + 1);

    debugPrint(
        '📊 [PremiumService] Synced notes: ${current + 1}/${PremiumLimits.maxSyncedNotesForFree}');
  }

  /// Decrement synced notes count (when note is deleted)
  Future<void> decrementSyncedNotes() async {
    if (_prefs == null) return;

    final current = getSyncedNotesCount();
    if (current > 0) {
      await _prefs!.setInt(UsageTrackingKeys.syncedNotesCount, current - 1);
    }
  }

  /// Get remaining sync slots
  int getRemainingSyncSlots() {
    if (_isPremium) return -1; // unlimited

    final used = getSyncedNotesCount();
    final remaining = PremiumLimits.maxSyncedNotesForFree - used;
    return remaining > 0 ? remaining : 0;
  }

  // ============================================
  // OCR Limits
  // ============================================

  /// Get OCR scans used this month
  int getOcrScansThisMonth() {
    return _prefs?.getInt(UsageTrackingKeys.ocrScansThisMonth) ?? 0;
  }

  /// Check if user can perform OCR scan
  bool canPerformOcrScan() {
    if (_isPremium) return true;

    final scans = getOcrScansThisMonth();
    return scans < PremiumLimits.maxOcrScansPerMonthForFree;
  }

  /// Increment OCR scan count (locally and on backend)
  Future<void> incrementOcrScans() async {
    if (_prefs == null) return;

    // 1. Increment locally first (for offline support and immediate UI update)
    final current = getOcrScansThisMonth();
    await _prefs!.setInt(UsageTrackingKeys.ocrScansThisMonth, current + 1);

    debugPrint(
        '📊 [PremiumService] OCR scans: ${current + 1}/${PremiumLimits.maxOcrScansPerMonthForFree}');

    // 2. Sync to backend (fire and forget - don't block the user)
    try {
      final response = await ApiService().incrementOcrScans();
      debugPrint('✅ [PremiumService] OCR scan synced to backend: $response');

      // Update local count from backend response (authoritative source)
      if (response['current'] != null) {
        await _prefs!.setInt(
          UsageTrackingKeys.ocrScansThisMonth,
          response['current'] as int,
        );
      }
    } catch (e) {
      debugPrint('⚠️ [PremiumService] Failed to sync OCR scan to backend: $e');
      // Continue anyway - local count is already updated
    }

    notifyListeners();
  }

  /// Get remaining OCR scans this month
  int getRemainingOcrScans() {
    if (_isPremium) return -1;

    final used = getOcrScansThisMonth();
    final remaining = PremiumLimits.maxOcrScansPerMonthForFree - used;
    return remaining > 0 ? remaining : 0;
  }

  // ============================================
  // Export Limits
  // ============================================

  /// Get exports used this month
  int getExportsThisMonth() {
    return _prefs?.getInt(UsageTrackingKeys.exportsThisMonth) ?? 0;
  }

  /// Check if user can export
  bool canExport() {
    if (_isPremium) return true;

    final exports = getExportsThisMonth();
    return exports < PremiumLimits.maxExportsPerMonthForFree;
  }

  /// Increment export count (locally and on backend)
  Future<void> incrementExports() async {
    if (_prefs == null) return;

    // 1. Increment locally first (for offline support and immediate UI update)
    final current = getExportsThisMonth();
    await _prefs!.setInt(UsageTrackingKeys.exportsThisMonth, current + 1);

    debugPrint(
        '📊 [PremiumService] Exports: ${current + 1}/${PremiumLimits.maxExportsPerMonthForFree}');

    // 2. Sync to backend (fire and forget - don't block the user)
    try {
      final response = await ApiService().incrementExports();
      debugPrint('✅ [PremiumService] Export synced to backend: $response');

      // Update local count from backend response (authoritative source)
      if (response['current'] != null) {
        await _prefs!.setInt(
          UsageTrackingKeys.exportsThisMonth,
          response['current'] as int,
        );
      }
    } catch (e) {
      debugPrint('⚠️ [PremiumService] Failed to sync export to backend: $e');
      // Continue anyway - local count is already updated
    }

    notifyListeners();
  }

  /// Get remaining exports this month
  int getRemainingExports() {
    if (_isPremium) return -1;

    final used = getExportsThisMonth();
    final remaining = PremiumLimits.maxExportsPerMonthForFree - used;
    return remaining > 0 ? remaining : 0;
  }

  // ============================================
  // Voice Recording Limits
  // ============================================

  /// Get max voice recording duration in seconds
  int getMaxVoiceRecordingDuration() {
    return _isPremium
        ? PremiumLimits.maxVoiceRecordingDurationForPremium
        : PremiumLimits.maxVoiceRecordingDurationForFree;
  }

  /// Check if voice recording duration is unlimited
  bool isVoiceRecordingUnlimited() {
    return _isPremium;
  }

  // ============================================
  // Folder Limits
  // ============================================

  /// Check if user can create more folders
  bool canCreateFolder(int currentFolderCount) {
    if (_isPremium) return true;

    return currentFolderCount < PremiumLimits.maxFoldersForFree;
  }

  /// Get remaining folder slots
  int getRemainingFolderSlots(int currentFolderCount) {
    if (_isPremium) return -1;

    final remaining = PremiumLimits.maxFoldersForFree - currentFolderCount;
    return remaining > 0 ? remaining : 0;
  }

  // ============================================
  // Theme Limits
  // ============================================

  /// Check if theme color is available for free users
  bool isThemeColorAvailable(String colorName) {
    if (_isPremium) return true;

    return PremiumLimits.freeThemeColors.contains(colorName);
  }

  // ============================================
  // Premium-Only Features
  // ============================================

  /// Check if markdown export is available
  bool canExportMarkdown() {
    return _isPremium;
  }

  /// Check if encrypted sharing is available
  bool canShareEncrypted() {
    return _isPremium;
  }

  /// Check if templates are available
  bool canUseTemplates() {
    return _isPremium;
  }

  /// Check if advanced search is available
  bool canUseAdvancedSearch() {
    return _isPremium;
  }

  // ============================================
  // Helper Methods
  // ============================================

  /// Get formatted subscription status text
  String getSubscriptionStatusText() {
    if (_isPremium) {
      if (_subscriptionType.toLowerCase().contains('lifetime')) {
        return 'Lifetime Premium';
      } else if (_subscriptionType.toLowerCase().contains('yearly')) {
        return 'Premium (Yearly)';
      } else if (_subscriptionType.toLowerCase().contains('monthly')) {
        return 'Premium (Monthly)';
      }
      return 'Premium Active';
    }

    return 'Free Tier';
  }

  /// Get days until expiration (returns null for lifetime)
  int? getDaysUntilExpiration() {
    if (_expiresAt == null) return null;
    if (_subscriptionType.toLowerCase().contains('lifetime')) return null;

    final now = DateTime.now();
    final difference = _expiresAt!.difference(now);
    return difference.inDays;
  }

  /// Get days until grace period ends
  int? getDaysUntilGracePeriodEnds() {
    if (_gracePeriodEndsAt == null) return null;

    final now = DateTime.now();
    final difference = _gracePeriodEndsAt!.difference(now);
    return difference.inDays;
  }

  /// Check if subscription is expiring soon (within 7 days)
  bool isExpiringSoon() {
    final days = getDaysUntilExpiration();
    if (days == null) return false;

    return days <= 7 && days > 0;
  }

  /// Get formatted grace period message for UI
  String? getGracePeriodMessage() {
    if (!_isInGracePeriod) return null;

    final daysLeft = getDaysUntilGracePeriodEnds();
    if (daysLeft == null) return null;

    if (daysLeft <= 0) {
      return 'Grace period expired. Please renew your subscription.';
    } else if (daysLeft == 1) {
      return 'Payment failed. Retry within 1 day to keep premium access.';
    } else {
      return 'Payment failed. Retry within $daysLeft days to keep premium access.';
    }
  }
}
