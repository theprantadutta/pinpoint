import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/premium_limits.dart';
import 'subscription_manager.dart';
import 'api_service.dart';
import 'backend_auth_service.dart';
import 'pending_usage.dart';

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

    // SubscriptionManager is the single source of truth for entitlement (it is
    // what purchase verification updates). Mirror it reactively so feature gates
    // — which read PremiumService — unlock the instant a purchase is verified or
    // provisionally granted, instead of staying locked until the next app launch.
    SubscriptionManager().addListener(_syncFromSubscriptionManager);

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

  /// Copy entitlement fields from SubscriptionManager whenever it changes.
  ///
  /// Fired by SubscriptionManager's listeners after purchase verification,
  /// provisional grant, restore, or a backend status refresh — keeping the two
  /// services in lockstep so feature gates never read a stale locked state.
  void _syncFromSubscriptionManager() {
    final subscriptionManager = SubscriptionManager();
    final wasPremium = _isPremium || _isInGracePeriod;

    _isPremium = subscriptionManager.isPremium;
    _isInGracePeriod = subscriptionManager.isInGracePeriod;
    _subscriptionType = subscriptionManager.subscriptionType ?? 'free';
    _expiresAt = subscriptionManager.expirationDate;
    _gracePeriodEndsAt = subscriptionManager.gracePeriodEndsAt;

    final isPremiumNow = _isPremium || _isInGracePeriod;
    if (isPremiumNow != wasPremium) {
      debugPrint('💎 [PremiumService] Entitlement synced from '
          'SubscriptionManager: premium=$isPremiumNow');
    }
    notifyListeners();
  }

  /// Fetch and cache usage stats from backend
  Future<Map<String, dynamic>?> fetchUsageStatsFromBackend() async {
    try {
      await flushPendingUsage();
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
      // Usage the server has not been told about yet is added on top, so a
      // fetch never erases what was done offline.
      final pending = _pendingUsage();
      final ocrScans = stats['ocr_scans'];
      if (ocrScans != null && ocrScans['current'] != null) {
        await _prefs!.setInt(
          UsageTrackingKeys.ocrScansThisMonth,
          PendingUsage.merge(ocrScans['current'] as int, pending?.ocr ?? 0),
        );
      }

      // Update exports count from backend
      final exports = stats['exports'];
      if (exports != null && exports['current'] != null) {
        await _prefs!.setInt(
          UsageTrackingKeys.exportsThisMonth,
          PendingUsage.merge(exports['current'] as int, pending?.exports ?? 0),
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

  /// The quota month, in UTC like the server's reset ("2026-10").
  @visibleForTesting
  static String quotaPeriodOf(DateTime when) {
    final utc = when.toUtc();
    return '${utc.year}-${utc.month.toString().padLeft(2, '0')}';
  }

  /// Tag existing counters with their month on first run of this version, so
  /// counts made earlier this month are not wiped, then roll over if needed.
  Future<void> _checkMonthlyReset() async {
    if (_prefs == null) return;

    if (_prefs!.getString(UsageTrackingKeys.quotaPeriod) == null) {
      final lastReset = _prefs!.getString(UsageTrackingKeys.lastMonthlyReset);
      final since = lastReset == null ? DateTime.now() : DateTime.tryParse(lastReset) ?? DateTime.now();
      await _prefs!.setString(UsageTrackingKeys.quotaPeriod, quotaPeriodOf(since));
    }
    _rollQuotaPeriodIfNeeded();
  }

  /// Zero the monthly counters when the month has changed. Called from every
  /// read, not only at start-up: an app left open across midnight at the end
  /// of the month, or used offline, must not stay blocked by last month's
  /// usage until it is restarted.
  void _rollQuotaPeriodIfNeeded() {
    final prefs = _prefs;
    if (prefs == null) return;
    final current = quotaPeriodOf(DateTime.now());
    if (prefs.getString(UsageTrackingKeys.quotaPeriod) == current) return;

    debugPrint('🔄 [PremiumService] New quota month $current: resetting monthly limits');
    prefs.setInt(UsageTrackingKeys.ocrScansThisMonth, 0);
    prefs.setInt(UsageTrackingKeys.exportsThisMonth, 0);
    prefs.setString(UsageTrackingKeys.quotaPeriod, current);
    prefs.setString(UsageTrackingKeys.lastMonthlyReset, DateTime.now().toIso8601String());
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
    _rollQuotaPeriodIfNeeded();
    return _prefs?.getInt(UsageTrackingKeys.ocrScansThisMonth) ?? 0;
  }

  /// Check if user can perform OCR scan
  bool canPerformOcrScan() {
    if (_isPremium) return true;

    final scans = getOcrScansThisMonth();
    return scans < PremiumLimits.maxOcrScansPerMonthForFree;
  }

  /// Count an OCR scan: locally at once, then on the server, replaying later
  /// if the server cannot be reached now.
  Future<void> incrementOcrScans() => _recordUsage(_Metered.ocr);

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
    _rollQuotaPeriodIfNeeded();
    return _prefs?.getInt(UsageTrackingKeys.exportsThisMonth) ?? 0;
  }

  /// Check if user can export
  bool canExport() {
    if (_isPremium) return true;

    final exports = getExportsThisMonth();
    return exports < PremiumLimits.maxExportsPerMonthForFree;
  }

  /// Count an export: locally at once, then on the server, replaying later
  /// if the server cannot be reached now.
  Future<void> incrementExports() => _recordUsage(_Metered.export);

  // ============================================
  // Usage replay
  // ============================================

  String? get _accountId {
    final auth = BackendAuthService();
    return auth.isAuthenticated ? auth.userId : null;
  }

  /// The pending usage for the signed-in account this month, or null.
  PendingUsage? _pendingUsage() {
    final pending = PendingUsage.decode(_prefs?.getString(PendingUsage.prefsKey));
    final period = quotaPeriodOf(DateTime.now());
    return pending != null && pending.appliesTo(_accountId, period) ? pending : null;
  }

  Future<void> _savePending(PendingUsage pending) =>
      _prefs!.setString(PendingUsage.prefsKey, pending.encode());

  Future<void> _recordUsage(_Metered kind) async {
    if (_prefs == null) return;

    final key = kind == _Metered.ocr
        ? UsageTrackingKeys.ocrScansThisMonth
        : UsageTrackingKeys.exportsThisMonth;
    final current = kind == _Metered.ocr ? getOcrScansThisMonth() : getExportsThisMonth();
    await _prefs!.setInt(key, current + 1);
    debugPrint('📊 [PremiumService] ${kind.name}: ${current + 1} this month');

    // Signed in: queue it for the account. A guest has no server counter.
    final owner = _accountId;
    if (owner != null) {
      final pending = PendingUsage.decode(_prefs!.getString(PendingUsage.prefsKey))
              ?.forScope(owner, quotaPeriodOf(DateTime.now())) ??
          PendingUsage(owner: owner, period: quotaPeriodOf(DateTime.now()));
      await _savePending(kind == _Metered.ocr
          ? pending.copyWith(ocr: pending.ocr + 1)
          : pending.copyWith(exports: pending.exports + 1));
    }
    notifyListeners();
    await flushPendingUsage();
  }

  Future<void>? _flushing;

  /// Tell the server about queued usage. Safe to call often: concurrent calls
  /// share one run, and whatever cannot be sent stays queued.
  Future<void> flushPendingUsage() =>
      _flushing ??= _flushPendingUsage().whenComplete(() => _flushing = null);

  Future<void> _flushPendingUsage() async {
    if (_prefs == null) return;
    var pending = _pendingUsage();
    if (pending == null) {
      // Last month's can never be sent. Another account's waits for it.
      final stored = PendingUsage.decode(_prefs!.getString(PendingUsage.prefsKey));
      if (stored != null && stored.period != quotaPeriodOf(DateTime.now())) {
        await _prefs!.remove(PendingUsage.prefsKey);
      }
      return;
    }
    if (pending.isEmpty) return;

    final api = ApiService();
    int? ocrServer, exportsServer;
    try {
      while (pending!.ocr > 0) {
        final sent = await _sendOne(api.incrementOcrScans);
        pending = pending.copyWith(ocr: pending.ocr - 1);
        await _savePending(pending);
        ocrServer = sent ?? ocrServer;
      }
      while (pending!.exports > 0) {
        final sent = await _sendOne(api.incrementExports);
        pending = pending.copyWith(exports: pending.exports - 1);
        await _savePending(pending);
        exportsServer = sent ?? exportsServer;
      }
    } catch (e) {
      debugPrint('⚠️ [PremiumService] Usage replay deferred: $e');
    }

    // The server's answer is authoritative for what it has counted.
    if (ocrServer != null) {
      await _prefs!.setInt(UsageTrackingKeys.ocrScansThisMonth,
          PendingUsage.merge(ocrServer, pending!.ocr));
    }
    if (exportsServer != null) {
      await _prefs!.setInt(UsageTrackingKeys.exportsThisMonth,
          PendingUsage.merge(exportsServer, pending!.exports));
    }
    if (ocrServer != null || exportsServer != null) notifyListeners();
  }

  /// Send one queued use. Returns the server's new count, or null when the
  /// outcome is unknown; throws to keep it queued.
  ///
  /// A timeout may have been counted before the reply was lost. That one is
  /// treated as sent: undercounting a quota is the user-friendly error, and a
  /// retry could count it twice.
  static Future<int?> _sendOne(Future<Map<String, dynamic>> Function() send) async {
    try {
      final response = await send();
      return response['current'] as int?;
    } on ApiError catch (e) {
      if (e.type == ApiErrorType.timeout) return null;
      rethrow;
    }
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

enum _Metered { ocr, export }
