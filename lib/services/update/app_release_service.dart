import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_service.dart';
import 'app_release_policy.dart';

/// Tells an iOS build that a newer one is on the App Store.
///
/// Android does not come through here: Google Play has a real in-app update
/// API and `InAppUpdateService` uses it. None of that exists on iOS, where the
/// best available answer is a dialog and a link to the store — so the version
/// to compare against comes from our backend.
///
/// One check per process, after the shell is up. The snooze stamp is this
/// device's last refusal, so it lives in SharedPreferences.
///
/// Offline-safe: a failed fetch is [UpdatePrompt.none], never a blocked app.
class AppReleaseService {
  static final AppReleaseService _instance = AppReleaseService._internal();
  factory AppReleaseService() => _instance;
  AppReleaseService._internal();

  @visibleForTesting
  AppReleaseService.forTesting();

  static const _kDeclinedAtMs = 'app_release_declined_ms';

  bool _checkedThisSession = false;

  /// Where the update button should send the user. Null until a check found
  /// something to show.
  String? storeUrl;

  /// The version the store is supposed to have, for the dialog.
  String? latestVersion;

  /// Decide what to show. Never throws.
  Future<UpdatePrompt> check({
    @visibleForTesting Future<Map<String, dynamic>> Function()? fetch,
    @visibleForTesting String? currentVersionOverride,
    @visibleForTesting bool force = false,
  }) async {
    if (!force) {
      if (!Platform.isIOS) return UpdatePrompt.none;
      if (kDebugMode) return UpdatePrompt.none;
      if (_checkedThisSession) return UpdatePrompt.none;
      _checkedThisSession = true;
    }

    try {
      final response =
          await (fetch ?? () => ApiService().getAppRelease('ios'))();

      final enabled = response['enabled'] as bool? ?? false;
      final latest = response['latest_version'] as String?;
      final minimum = response['minimum_supported_version'] as String?;
      final url = response['store_url'] as String?;

      final current = currentVersionOverride ??
          (await PackageInfo.fromPlatform()).version;

      final prefs = await SharedPreferences.getInstance();
      final declinedMs = prefs.getInt(_kDeclinedAtMs);
      final sinceDeclined = declinedMs == null
          ? null
          : Duration(
              milliseconds: DateTime.now().millisecondsSinceEpoch - declinedMs,
            );

      final prompt = AppReleasePolicy.decide(
        enabled: enabled,
        currentVersion: current,
        latestVersion: latest,
        minimumSupportedVersion: minimum,
        sinceDeclined: sinceDeclined,
      );

      // Publish the destination only when there is something to show, so a
      // stale URL can never reach a dialog that should not open.
      if (prompt != UpdatePrompt.none) {
        storeUrl = url;
        latestVersion = latest;
      }
      debugPrint('[AppRelease] current=$current latest=$latest '
          'minimum=$minimum prompt=${prompt.name}');
      return prompt;
    } catch (e) {
      debugPrint('[AppRelease] check failed: $e');
      return UpdatePrompt.none;
    }
  }

  /// Remember that the user said "later", so the optional prompt is not
  /// repeated on the next launch.
  Future<void> recordDeclined() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _kDeclinedAtMs, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // A snooze that fails to persist costs one extra prompt.
      debugPrint('[AppRelease] could not record decline: $e');
    }
  }
}
