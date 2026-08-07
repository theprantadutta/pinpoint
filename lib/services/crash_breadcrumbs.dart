import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'logger_service.dart';

/// Short trail of "what the user was doing" that Crashlytics attaches to the
/// next crash report.
///
/// Deliberately separate from the app's other two logging paths:
///   * [LoggerService] writes to the dev console and is invisible in release.
///   * `AnalyticsFacade` records product metrics, which are sampled, delayed,
///     and not joined to a stack trace.
///
/// Breadcrumbs exist purely to make a report diagnosable. Add one where a
/// stack trace alone would leave you guessing which screen the user was on.
///
/// Every method is fire-and-forget and swallows its own errors: diagnostics
/// must never be able to crash the app they exist to explain.
class CrashBreadcrumbs {
  CrashBreadcrumbs._();

  /// Custom key holding the popup menu currently on screen, or [_noMenu].
  ///
  /// Shows up as a field on the crash report, so a report can be read as "this
  /// happened while the editor's overflow menu was open" without hunting
  /// through the breadcrumb trail.
  static const String _openMenuKey = 'open_popup_menu';
  static const String _noMenu = 'none';

  /// Whether Crashlytics is actually available to receive this.
  ///
  /// Mirrors the guard in `main.dart` that installs the error handlers:
  /// collection is off in debug, and Firebase may have failed to initialise.
  static bool get _enabled => !kDebugMode && Firebase.apps.isNotEmpty;

  /// Record a free-form breadcrumb.
  ///
  /// Keep messages short and greppable — they are read as a list, newest last.
  static void log(String message) {
    if (!_enabled) {
      // Still worth seeing while developing, where Crashlytics is off.
      log_.d('🍞 $message');
      return;
    }
    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (_) {
      // A diagnostics failure is not worth surfacing, let alone throwing.
    }
  }

  /// Attach [value] to every subsequent report under [key].
  static void setKey(String key, Object value) {
    if (!_enabled) return;
    try {
      FirebaseCrashlytics.instance.setCustomKey(key, value);
    } catch (_) {}
  }

  /// Record that [id]'s popup menu has opened.
  ///
  /// [id] is a stable dotted name for the menu — `screen.menu`, e.g.
  /// `editor.overflow` — not a user-visible label, so it stays meaningful
  /// across translations.
  ///
  /// Added while chasing a "RenderBox was not laid out:
  /// RenderFractionalTranslation" crash thrown from
  /// `PopupMenuButtonState._positionBuilder`, which reports the render object
  /// but nothing about which of the app's menus was involved.
  static void popupMenuOpened(String id) {
    log('popup menu opened: $id');
    setKey(_openMenuKey, id);
  }

  /// Record that [id]'s popup menu has been dismissed, by selection or not.
  ///
  /// Note this fires when the menu is *popped*, not when it is gone: the route
  /// lingers for its reverse transition afterwards. So a crash arriving in that
  /// window carries `$_openMenuKey = none` even though a menu route is still
  /// alive — read the breadcrumb trail, where the open/close pair is
  /// timestamped, rather than the key alone.
  static void popupMenuClosed(String id, {Object? selected}) {
    log(selected == null
        ? 'popup menu dismissed: $id'
        : 'popup menu selected: $id → $selected');
    setKey(_openMenuKey, _noMenu);
  }
}

/// Local alias so this file can use the console logger without its bare `log`
/// getter colliding with [CrashBreadcrumbs.log].
LoggerService get log_ => LoggerService.I;
