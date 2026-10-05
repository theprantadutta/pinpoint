import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_policy.dart';

/// In-app updates from the Play Store (Android only).
///
/// Runs ONE check per process, after the shell is up rather than during
/// start-up, and picks the flow with [UpdatePolicy]: flexible by default —
/// Play downloads while the user writes, and the app offers a restart through
/// [updateReadyToInstall] — and the blocking immediate flow only for releases
/// published with a high update priority. A declined flexible offer is
/// snoozed rather than re-asked on the next launch.
///
/// Offline-safe: no network, no Play, or any error is a log line, never a
/// blocked app.
class InAppUpdateService {
  static final InAppUpdateService _instance = InAppUpdateService._internal();
  factory InAppUpdateService() => _instance;
  InAppUpdateService._internal();

  static const _kDeclinedAtMs = 'in_app_update_declined_ms';

  bool _checkedThisSession = false;
  StreamSubscription<InstallStatus>? _installSub;

  /// True once a flexible update has downloaded and only needs a restart.
  /// The shell's update pill listens to this.
  final ValueNotifier<bool> updateReadyToInstall = ValueNotifier(false);

  /// Check once per session and start whichever flow the policy picks.
  Future<void> checkForUpdate() async {
    if (!Platform.isAndroid || kDebugMode) return;
    if (_checkedThisSession) return;
    _checkedThisSession = true;

    try {
      final info = await InAppUpdate.checkForUpdate()
          .timeout(const Duration(seconds: 5));

      // A download from an earlier session that finished while we were
      // away: nothing to start, just offer the restart.
      if (info.installStatus == InstallStatus.downloaded) {
        updateReadyToInstall.value = true;
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final declinedMs = prefs.getInt(_kDeclinedAtMs);
      final sinceDeclined = declinedMs == null
          ? null
          : Duration(
              milliseconds:
                  DateTime.now().millisecondsSinceEpoch - declinedMs);

      final flow = UpdatePolicy.decide(
        updateAvailable:
            info.updateAvailability == UpdateAvailability.updateAvailable,
        priority: info.updatePriority,
        immediateAllowed: info.immediateUpdateAllowed,
        flexibleAllowed: info.flexibleUpdateAllowed,
        sinceDeclined: sinceDeclined,
      );
      debugPrint('[InAppUpdate] available=${info.updateAvailability.name} '
          'priority=${info.updatePriority} flow=${flow.name}');

      switch (flow) {
        case UpdateFlow.none:
          return;
        case UpdateFlow.immediate:
          await _runImmediate();
        case UpdateFlow.flexible:
          await _runFlexible(prefs);
      }
    } catch (e) {
      debugPrint('[InAppUpdate] check failed: $e');
    }
  }

  /// The blocking Play flow. Returns when the update installed (Play
  /// restarts the app) or the user backed out of it.
  Future<void> _runImmediate() async {
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (e) {
      debugPrint('[InAppUpdate] immediate update failed: $e');
    }
  }

  /// Ask Play to download in the background. The user sees one small Play
  /// dialog; "No thanks" is remembered for [UpdatePolicy.snooze].
  Future<void> _runFlexible(SharedPreferences prefs) async {
    _installSub ??= InAppUpdate.installUpdateListener.listen(
      (status) {
        if (status == InstallStatus.downloaded) {
          updateReadyToInstall.value = true;
        } else if (status == InstallStatus.installed ||
            status == InstallStatus.failed ||
            status == InstallStatus.canceled) {
          updateReadyToInstall.value = false;
        }
      },
      onError: (Object e) =>
          debugPrint('[InAppUpdate] status stream failed: $e'),
    );

    try {
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result == AppUpdateResult.userDeniedUpdate) {
        await prefs.setInt(
            _kDeclinedAtMs, DateTime.now().millisecondsSinceEpoch);
      }
    } catch (e) {
      debugPrint('[InAppUpdate] flexible update failed to start: $e');
    }
  }

  /// Apply a downloaded flexible update. Play restarts the app. Notes are
  /// already saved locally on every edit, so nothing is lost.
  Future<void> completeUpdate() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (e) {
      debugPrint('[InAppUpdate] completing the update failed: $e');
      updateReadyToInstall.value = false;
    }
  }
}
