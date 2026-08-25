import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:refresh_rate/refresh_rate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/shared_preference_keys.dart';

/// Reactive owner of the "smooth motion" preference — whether Pinpoint asks the
/// display for its highest refresh rate.
///
/// Flutter's engine never calls the platform's rate-setting APIs, so a 120 Hz
/// phone renders the app at 60 Hz unless we opt in. Everything that moves —
/// the masonry grid scrolling, the FAB speed dial, page transitions — is
/// smoother when we do.
///
/// Owned the same way as [ThemeController] and [LocaleController]: a
/// [ChangeNotifier] provided near the root, persisted to SharedPreferences
/// rather than the encrypted note database. This is a per-device display
/// preference with nothing sensitive in it, and it has to be readable before
/// the first frame — the same reasons theme mode and language live there.
class RefreshRateController extends ChangeNotifier {
  /// On by default. Someone who paid for a high-refresh screen should see the
  /// app use it without hunting through settings first — and this preserves
  /// the behaviour of the unconditional `flutter_displaymode` call it replaces,
  /// so upgrading users notice nothing.
  static const bool _defaultEnabled = true;

  bool _enabled = _defaultEnabled;
  bool _loaded = false;
  DisplayInfo? _info;

  bool get isEnabled => _enabled;
  bool get isLoaded => _loaded;

  /// What the display is actually doing, as last read from the platform.
  /// Null until the first successful query.
  DisplayInfo? get info => _info;

  /// A panel that can only do one rate has nothing to offer, so the toggle is
  /// pointless there. Guards on both the max rate and the list of modes because
  /// some Android OEMs under-report one or the other.
  ///
  /// The 61 Hz threshold rather than 60 is deliberate: panels commonly report
  /// 60.000004 Hz, and `> 60` would call that high-refresh.
  bool get deviceSupportsHighRate {
    final i = _info;
    if (i == null) return false;
    return i.maxRate > 61 || i.supportedRates.length > 1;
  }

  /// The OS throttles the display in battery saver whatever we ask for. Worth
  /// saying out loud on the settings screen, otherwise the toggle looks broken.
  bool get throttledByBattery => _info?.isLowPowerMode ?? false;

  /// Same for heat: a warm device holds a lower rate until it cools.
  bool get throttledByHeat {
    final state = _info?.thermalState;
    return state != null &&
        state != ThermalState.nominal &&
        state != ThermalState.unknown;
  }

  /// Load the stored preference and push it to the platform. Call once at
  /// startup, before the first frame.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(kHighRefreshRateKey) ?? _defaultEnabled;
    } catch (e) {
      // A preferences read failing is not worth blocking startup over; fall
      // back to the default and carry on.
      debugPrint('Could not read the refresh-rate preference: $e');
    }

    _loaded = true;
    await apply();
  }

  /// Push the current preference to the platform, then re-read what it did.
  ///
  /// Safe to call repeatedly, and it must be called on resume: Android drops
  /// the window's preferred display mode when the app is backgrounded, so
  /// without this the app quietly slides back to 60 Hz after a task switch and
  /// never recovers until the next cold start.
  Future<void> apply() async {
    try {
      if (_enabled) {
        RefreshRate.enable();
        RefreshRate.preferMax();
      } else {
        RefreshRate.disable();
      }
    } catch (e) {
      // Refresh rate is a nicety, and OEMs reject or under-report modes in
      // ways that surface as a PlatformException. An unsupported device is not
      // a failure worth surfacing — the previous implementation logging this
      // as a fatal Crashlytics error on every iOS launch is exactly the
      // outcome being avoided here.
      debugPrint('Could not set the refresh rate: $e');
    }

    await refreshInfo();
  }

  /// Re-read what the display is doing right now, without changing anything.
  Future<void> refreshInfo() async {
    try {
      _info = await RefreshRate.refresh();
      notifyListeners();
    } catch (e) {
      debugPrint('Could not read display info: $e');
    }
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;

    _enabled = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kHighRefreshRateKey, value);
    } catch (e) {
      debugPrint('Could not save the refresh-rate preference: $e');
    }

    await apply();
  }
}
