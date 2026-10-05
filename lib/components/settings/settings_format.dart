import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../util/localized_dates.dart';

/// "just now", "2 min ago", "3 h ago", then "Yesterday, 9:41 AM" — the
/// last-sync time on the Settings account card and the Sync screen.
///
/// Built from ARB plurals and [LocalizedDates], never from a bare DateFormat
/// or a hand-rolled "s".
String relativeAgo(BuildContext context, DateTime when, {DateTime? now}) {
  final l10n = AppL10n.of(context);
  final diff = (now ?? DateTime.now()).difference(when);
  if (diff.inSeconds < 60) return l10n.stJustNow;
  if (diff.inMinutes < 60) return l10n.stMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.stHoursAgo(diff.inHours);
  return LocalizedDates.relativeDayTime(context, when, now: now);
}

/// The platform store's name, for "Manage in {store}".
String get storeName => Platform.isIOS ? 'App Store' : 'Google Play';

/// Opens the platform's subscription-management page. Store policy requires
/// linking to the right one: App Store on iOS, Google Play on Android.
///
/// Returns false when nothing could be opened, so the caller can say so.
Future<bool> openManageSubscriptions() async {
  try {
    final uri = Uri.parse(
      Platform.isIOS
          ? 'https://apps.apple.com/account/subscriptions'
          : 'https://play.google.com/store/account/subscriptions',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
  } catch (_) {
    // Reported by the caller.
  }
  return false;
}
