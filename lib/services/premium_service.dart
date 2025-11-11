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

  bool get isPremium => _isPremium || _isInGracePeriod;
  bool get isInGracePeriod => _isInGracePeriod;
  String get subscriptionType => _subscriptionType;
  DateTime? get expiresAt => _expiresAt;
  DateTime? get gracePeriodEndsAt => _gracePeriodEndsAt;

  /// Initialize the service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadPremiumStatus();
    await _checkMonthlyReset();
  }

  /// Load premium status from Subscription Manager and backend API
  Future<void> _loadPremiumStatus() async {
    try {
      // First check local subscription manager
      final subscriptionManager = SubscriptionManager();
      _isPremium = subscriptionManager.isPremium;
      _subscriptionType = subscriptionManager.subscriptionType ?? 'free';
      _expiresAt = subscriptionManager.expirationDate;

      // Then check backend for grace period status
      try {
        final apiService = ApiService();
        final statusResponse = await apiService.getSubscriptionStatus();

        _isInGracePeriod = statusResponse['is_in_grace_period'] ?? false;

        if (statusResponse['grace_period_ends_at'] != null) {
          _gracePeriodEndsAt = DateTime.parse(statusResponse['grace_period_ends_at']);
        }

        // Update from backend if available (more authoritative)
        if (statusResponse['subscription_tier'] != null) {
          _subscriptionType = statusResponse['subscription_tier'];
        }

        if (statusResponse['subscription_expires_at'] != null) {
          _expiresAt = DateTime.parse(statusResponse['subscription_expires_at']);
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
    await _loadPremiumStatus();
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

  /// Increment OCR scan count
  Future<void> incrementOcrScans() async {
    if (_prefs == null) return;

    final current = getOcrScansThisMonth();
    await _prefs!.setInt(UsageTrackingKeys.ocrScansThisMonth, current + 1);

    debugPrint(
        '📊 [PremiumService] OCR scans: ${current + 1}/${PremiumLimits.maxOcrScansPerMonthForFree}');
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

  /// Increment export count
  Future<void> incrementExports() async {
    if (_prefs == null) return;

    final current = getExportsThisMonth();
    await _prefs!.setInt(UsageTrackingKeys.exportsThisMonth, current + 1);

    debugPrint(
        '📊 [PremiumService] Exports: ${current + 1}/${PremiumLimits.maxExportsPerMonthForFree}');
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
