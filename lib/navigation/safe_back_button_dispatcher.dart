import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// A [RootBackButtonDispatcher] that shields the app from a known go_router
/// crash on the Android system back button.
///
/// go_router's `GoRouterDelegate.popRoute()` walks the current route match
/// chain in `_findCurrentNavigators()` and force-unwraps each
/// `ShellRouteMatch.navigatorKey.currentState!`. When the back button fires
/// before the current shell branch's navigator is mounted (e.g. during a
/// branch switch / rebuild), that `currentState` is null and go_router throws
/// `Null check operator used on a null value` — surfacing as a fatal crash via
/// `WidgetsBinding.handlePopRoute -> invokeCallback`.
///
/// The bug is still present in the latest go_router (17.x), so we guard the
/// invocation here: if the dispatch throws, we report it as a non-fatal and
/// treat the back press as handled instead of crashing. The navigator settles
/// on the next frame, so a subsequent back press works normally.
class SafeBackButtonDispatcher extends RootBackButtonDispatcher {
  @override
  Future<bool> invokeCallback(Future<bool> defaultValue) async {
    try {
      return await super.invokeCallback(defaultValue);
    } catch (error, stack) {
      // Swallow the go_router race and keep the app alive. Record it
      // (non-fatal) in release builds so we retain visibility.
      if (kReleaseMode) {
        FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          reason: 'Guarded system back-button pop (go_router popRoute)',
          fatal: false,
        );
      }
      // Treat as handled so the OS does not close the app mid-transition.
      return true;
    }
  }
}
