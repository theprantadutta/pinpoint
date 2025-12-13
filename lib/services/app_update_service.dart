import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Service to handle forced in-app updates from Google Play Store.
///
/// This service checks for available updates and forces users to update
/// before they can continue using the app. Updates are mandatory.
class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  AppUpdateInfo? _updateInfo;
  bool _isUpdateAvailable = false;

  /// Whether an update is available
  bool get isUpdateAvailable => _isUpdateAvailable;

  /// The update info from Google Play
  AppUpdateInfo? get updateInfo => _updateInfo;

  /// Check for available updates from Google Play Store.
  ///
  /// Returns true if an update is available, false otherwise.
  /// Only works on Android - returns false on other platforms.
  Future<bool> checkForUpdate() async {
    // Only check on Android
    if (!Platform.isAndroid) {
      debugPrint('📱 [AppUpdateService] Not on Android, skipping update check');
      return false;
    }

    try {
      debugPrint('🔍 [AppUpdateService] Checking for updates...');
      _updateInfo = await InAppUpdate.checkForUpdate();

      _isUpdateAvailable = _updateInfo?.updateAvailability ==
          UpdateAvailability.updateAvailable;

      if (_isUpdateAvailable) {
        debugPrint(
            '✅ [AppUpdateService] Update available! Priority: ${_updateInfo?.updatePriority}');
        debugPrint(
            '   Available version code: ${_updateInfo?.availableVersionCode}');
        debugPrint(
            '   Immediate update allowed: ${_updateInfo?.immediateUpdateAllowed}');
        debugPrint(
            '   Flexible update allowed: ${_updateInfo?.flexibleUpdateAllowed}');
      } else {
        debugPrint('✅ [AppUpdateService] App is up to date');
      }

      return _isUpdateAvailable;
    } catch (e) {
      debugPrint('❌ [AppUpdateService] Error checking for updates: $e');
      // Don't block the app if we can't check for updates
      return false;
    }
  }

  /// Perform an immediate (forced) update.
  ///
  /// This will block the app and show the Google Play update screen.
  /// The user MUST complete the update to continue using the app.
  /// Returns true if update was started successfully.
  Future<bool> performImmediateUpdate() async {
    if (!Platform.isAndroid) {
      debugPrint(
          '📱 [AppUpdateService] Not on Android, skipping immediate update');
      return false;
    }

    try {
      // Check if immediate update is allowed
      if (_updateInfo?.immediateUpdateAllowed != true) {
        debugPrint(
            '⚠️ [AppUpdateService] Immediate update not allowed, trying flexible...');
        return await performFlexibleUpdate();
      }

      debugPrint('🚀 [AppUpdateService] Starting immediate update...');
      await InAppUpdate.performImmediateUpdate();
      debugPrint('✅ [AppUpdateService] Immediate update completed');
      return true;
    } catch (e) {
      debugPrint('❌ [AppUpdateService] Immediate update failed: $e');
      return false;
    }
  }

  /// Perform a flexible update as fallback.
  ///
  /// Downloads in background and prompts user to install when ready.
  Future<bool> performFlexibleUpdate() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      if (_updateInfo?.flexibleUpdateAllowed != true) {
        debugPrint('⚠️ [AppUpdateService] Flexible update not allowed');
        return false;
      }

      debugPrint('🔄 [AppUpdateService] Starting flexible update...');
      await InAppUpdate.startFlexibleUpdate();
      await InAppUpdate.completeFlexibleUpdate();
      debugPrint('✅ [AppUpdateService] Flexible update completed');
      return true;
    } catch (e) {
      debugPrint('❌ [AppUpdateService] Flexible update failed: $e');
      return false;
    }
  }

  /// Check for update and perform immediate update if available.
  ///
  /// This is the main method to call for forced updates.
  /// Returns true if no update is needed or update was started.
  /// Returns false if update check failed.
  Future<bool> checkAndPerformImmediateUpdate() async {
    final hasUpdate = await checkForUpdate();

    if (!hasUpdate) {
      return true; // No update needed
    }

    // Force immediate update
    return await performImmediateUpdate();
  }
}
