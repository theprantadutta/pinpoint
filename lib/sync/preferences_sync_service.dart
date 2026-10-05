import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design_system/colors.dart';
import '../services/api_service.dart';
import '../services/backend_auth_service.dart';
import '../services/theme_controller.dart';

/// Keeps the look (theme mode, accent, font, doodles, onboarding version)
/// the same across a user's devices via `/api/v1/users/me/preferences`.
///
/// Offline-first: SharedPreferences stays the source of truth, every network
/// failure is swallowed, and nothing here blocks the UI. Conflicts resolve
/// last-write-wins on `updatedAt`, matching the server. An older server
/// without the endpoint answers 404 and is treated as "nothing stored".
class PreferencesSyncService {
  PreferencesSyncService._();
  static final PreferencesSyncService instance = PreferencesSyncService._();

  /// Must match the onboarding flow's key (lib/constants).
  static const String onboardingVersionKey = 'onboarding_version';

  ThemeController? _theme;
  Timer? _debounce;
  bool _busy = false;

  /// Starts listening for local changes and reconciles once.
  void start(ThemeController theme) {
    if (_theme == null) {
      _theme = theme;
      theme.addListener(_onLocalChange);
    }
    unawaited(reconcile());
  }

  void _onLocalChange() {
    final theme = _theme;
    if (theme == null || theme.isApplyingRemote) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => unawaited(reconcile()));
  }

  /// Pull, compare clocks, then apply the newer side.
  Future<void> reconcile() async {
    final theme = _theme;
    if (theme == null || _busy) return;
    if (!BackendAuthService().isAuthenticated) return;
    _busy = true;
    try {
      final api = ApiService();
      final remote = await api.getAppearancePreferences();
      final local = theme.appearanceUpdatedAt;
      final remoteAt = _parseTime(remote?['updatedAt']);

      if (remote != null &&
          remoteAt != null &&
          (local == null || remoteAt.isAfter(local))) {
        await _apply(theme, remote, remoteAt);
      } else if (local != null || remote == null) {
        final body = await _localBody(theme);
        final stored = await api.putAppearancePreferences(body);
        // The response is the server's truth; the accent may have been
        // folded to a free one if the plan lapsed.
        final storedAt = _parseTime(stored['updatedAt']);
        final accent = SketchAccent.fromName(stored['accent'] as String?);
        if (storedAt != null && accent != null && accent != theme.accent) {
          await theme.applyRemote(accent: accent, updatedAt: storedAt);
        }
      }
    } catch (e) {
      debugPrint('🎨 [PreferencesSync] skipped: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> _apply(
      ThemeController theme, Map<String, dynamic> remote, DateTime at) async {
    await theme.applyRemote(
      mode: _modeFrom(remote['themeMode'] as String?),
      accent: SketchAccent.fromName(remote['accent'] as String?),
      fontFamily: remote['font'] as String?,
      doodlesEnabled: remote['doodlesEnabled'] as bool?,
      updatedAt: at,
    );
    final version = (remote['onboardingVersion'] as num?)?.toInt();
    if (version != null) {
      final prefs = await SharedPreferences.getInstance();
      final mine = prefs.getInt(onboardingVersionKey) ?? 0;
      // Never move backwards: seeing the newer onboarding on one device
      // counts everywhere.
      if (version > mine) await prefs.setInt(onboardingVersionKey, version);
    }
  }

  Future<Map<String, dynamic>> _localBody(ThemeController theme) async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'themeMode': ThemeController.modeAnalyticsLabel(theme.mode),
      'accent': theme.accent.name,
      'font': theme.fontFamily,
      'doodlesEnabled': theme.doodlesEnabled,
      'onboardingVersion': prefs.getInt(onboardingVersionKey) ?? 0,
      'updatedAt': (theme.appearanceUpdatedAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
    };
  }

  static ThemeMode? _modeFrom(String? s) => switch (s) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => null,
      };

  static DateTime? _parseTime(Object? s) {
    if (s is! String) return null;
    return DateTime.tryParse(s)?.toUtc();
  }
}
