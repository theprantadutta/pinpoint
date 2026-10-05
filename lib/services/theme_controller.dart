import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/shared_preference_keys.dart';
import '../design_system/colors.dart';
import '../design_system/typography.dart';

/// Central, reactive owner of app-wide appearance state.
///
/// Replaces the old `_PinPointAppState` + `PinPointApp.of(context).changeTheme()` pattern
/// (which rebuilt the whole tree via `findAncestorStateOfType` and could only
/// persist a 2-state dark/light bool). This is a [ChangeNotifier] provided at
/// the top of the tree; `MaterialApp.router` watches it, so changes re-theme
/// the app instantly with no restart.
///
/// Theme mode is a proper 3-state value (system / light / dark) persisted as a
/// string. The legacy `kIsDarkModeKey` bool is migrated on first load.
class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  SketchAccent _accent = SketchAccent.fallback;
  bool _highContrast = false;
  bool _doodlesEnabled = true;
  String _fontFamily = PinpointTypography.primaryFontFamily;
  bool _loaded = false;

  ThemeMode get mode => _mode;
  /// The accent; it only picks the highlight pastel (see [SketchAccent]).
  SketchAccent get accent => _accent;
  bool get highContrast => _highContrast;

  /// The "Background doodles" Display setting. The doodle painter also stays
  /// off under high contrast and when the OS asks for reduced motion.
  bool get doodlesEnabled => _doodlesEnabled;
  String get fontFamily => _fontFamily;
  bool get isLoaded => _loaded;

  /// Resolve the effective brightness for the current mode against the OS.
  Brightness effectiveBrightness(BuildContext context) {
    switch (_mode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return MediaQuery.platformBrightnessOf(context);
    }
  }

  /// Load persisted preferences. Call once at startup.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Theme mode (with one-time migration from the legacy bool).
    final stored = prefs.getString(kThemeModeKey);
    if (stored != null) {
      _mode = _modeFromString(stored);
    } else {
      final legacyDark = prefs.getBool(kIsDarkModeKey);
      if (legacyDark != null) {
        _mode = legacyDark ? ThemeMode.dark : ThemeMode.light;
        await prefs.setString(kThemeModeKey, _modeToString(_mode));
      }
    }

    // Persisted as the pre-Sketchbook accent hex so the value still means
    // something to an older build; unknown values (the old indigo default)
    // resolve to the Sketchbook default.
    _accent = SketchAccent.fromStored(prefs.getInt(kAccentColorKey));

    final doodles = prefs.getBool(kDoodlesEnabledKey);
    if (doodles != null) _doodlesEnabled = doodles;

    final hc = prefs.getBool(kHighContrastKey);
    if (hc != null) _highContrast = hc;

    final font = prefs.getString(kSelectedFontKey);
    if (font != null) _fontFamily = font;

    _loaded = true;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kThemeModeKey, _modeToString(mode));
    // Keep the legacy key roughly in sync for any old readers.
    if (mode != ThemeMode.system) {
      await prefs.setBool(kIsDarkModeKey, mode == ThemeMode.dark);
    }
  }

  Future<void> setAccent(SketchAccent accent) async {
    if (_accent == accent) return;
    _accent = accent;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kAccentColorKey, accent.legacyColor.toARGB32());
  }

  Future<void> setDoodlesEnabled(bool enabled) async {
    if (_doodlesEnabled == enabled) return;
    _doodlesEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kDoodlesEnabledKey, enabled);
  }

  Future<void> setHighContrast(bool enabled) async {
    if (_highContrast == enabled) return;
    _highContrast = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kHighContrastKey, enabled);
  }

  Future<void> setFontFamily(String fontFamily) async {
    if (_fontFamily == fontFamily) return;
    _fontFamily = fontFamily;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kSelectedFontKey, fontFamily);
  }

  /// Lowercase label for analytics (e.g. 'light' | 'dark' | 'system').
  static String modeAnalyticsLabel(ThemeMode m) => _modeToString(m);

  static ThemeMode _modeFromString(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static String _modeToString(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  /// Human-facing label for the current mode (for settings UI).
  String get modeLabel {
    switch (_mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System default';
    }
  }
}
