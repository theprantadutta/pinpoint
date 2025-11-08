import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/premium_limits.dart';
import 'revenue_cat_service.dart';

/// Service for managing premium features and usage limits
class PremiumService extends ChangeNotifier {
  static final PremiumService _instance = PremiumService._internal();
  factory PremiumService() => _instance;
  PremiumService._internal();

  SharedPreferences? _prefs;
  bool _isPremium = false;
  String _subscriptionType = 'free';
  DateTime? _expiresAt;

  bool get isPremium => _isPremium;
  String get subscriptionType => _subscriptionType;
  DateTime? get expiresAt => _expiresAt;

  /// Initialize the service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadPremiumStatus();
    await _checkMonthlyReset();
  }

  /// Load premium status from RevenueCat
  Future<void> _loadPremiumStatus() async {
    try {
      _isPremium = await RevenueCatService.isPremium();
      _subscriptionType =
          await RevenueCatService.getSubscriptionType() ?? 'free';
      _expiresAt = await RevenueCatService.getExpirationDate();

      debugPrint('💎 [PremiumService] Premium status: $_isPremium');
      debugPrint('   Subscription type: $_subscriptionType');

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
  Future<int?> getDaysUntilExpiration() async {
    if (_expiresAt == null) return null;
    if (await RevenueCatService.isLifetime()) return null;

    final now = DateTime.now();
    final difference = _expiresAt!.difference(now);
    return difference.inDays;
  }

  /// Check if subscription is expiring soon (within 7 days)
  Future<bool> isExpiringSoon() async {
    final days = await getDaysUntilExpiration();
    if (days == null) return false;

    return days <= 7 && days > 0;
  }
}
