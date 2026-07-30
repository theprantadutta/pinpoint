import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../generated/l10n/app_localizations.dart';
import 'locale_controller.dart';

/// Single source of truth for the Android notification channels, and the only
/// place that knows how to re-localize them.
///
/// Android caches a channel's name and description at *creation* time. Passing
/// a new name to `AndroidNotificationDetails` later changes nothing — the user
/// keeps seeing whatever language the channel was first created in, forever, in
/// their system settings. The only fix is to delete the channel and create it
/// again, which is what [syncWithLocale] does when the language changes.
///
/// Deleting a channel does clear the user's per-channel tweaks (custom sound,
/// importance override). That is why this only runs when the locale actually
/// changed, never on a plain app start.
class NotificationChannels {
  NotificationChannels._();

  /// Remembers which language the channels were last created in.
  static const String _localeKey = 'notification_channels_locale';

  /// Used by firebase_notification_service for FCM pushes.
  static const String defaultId = 'pinpoint_default_channel';

  /// Used by notification_service for locally-raised general notifications.
  /// Separate from [defaultId] historically; both are kept so existing users
  /// do not lose per-channel settings.
  static const String generalId = 'pinpoint_general';
  static const String remindersId = 'pinpoint_reminders';
  static const String recurringId = 'pinpoint_recurring';
  static const String periodicId = 'pinpoint_periodic';

  /// Localized channel text, cached so the notification services — which have
  /// no [BuildContext] — can read it when building `AndroidNotificationDetails`.
  /// Populated by [syncWithLocale]; falls back to English before the first run.
  static NotificationChannelText _text = const NotificationChannelText(
    defaultName: 'Pinpoint Notifications',
    defaultDescription: 'General notifications from Pinpoint',
    remindersName: 'Reminders',
    remindersDescription: 'Scheduled reminders for your notes',
    recurringName: 'Recurring reminders',
    recurringDescription: 'Reminders that repeat on a schedule',
    periodicName: 'Periodic updates',
    periodicDescription: 'Occasional updates from Pinpoint',
  );

  static NotificationChannelText get text => _text;

  /// Create the channels in the current language, recreating them if the
  /// language changed since last time.
  ///
  /// Safe to call on every app start: it no-ops unless the locale differs.
  /// Call it again right after the user picks a new language.
  static Future<void> syncWithLocale(
    BuildContext context,
    FlutterLocalNotificationsPlugin plugin,
  ) async {
    final l10n = AppL10n.of(context);
    _text = NotificationChannelText(
      defaultName: l10n.notifChannelDefaultName,
      defaultDescription: l10n.notifChannelDefaultDescription,
      remindersName: l10n.notifChannelRemindersName,
      remindersDescription: l10n.notifChannelRemindersDescription,
      recurringName: l10n.notifChannelRecurringName,
      recurringDescription: l10n.notifChannelRecurringDescription,
      periodicName: l10n.notifChannelPeriodicName,
      periodicDescription: l10n.notifChannelPeriodicDescription,
    );

    if (!Platform.isAndroid) return;

    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(_localeKey);
    final current = LocaleController.currentTag;

    // Nothing to do if the language has not moved since we last created them.
    if (previous == current) return;

    // Whether to delete before creating. Android ignores the name and
    // description passed to createNotificationChannel for a channel that
    // already exists, so a rename only lands via delete-then-create.
    //
    // The subtle case is the *first* run after this code ships. `previous` is
    // null, but the channels themselves may well exist already — every build
    // before this one created them with hardcoded English names. For a user
    // running the app in English that is fine and we must not delete, because
    // deleting discards their per-channel sound and importance overrides. For
    // a user in any other language those channels are wrong and stay wrong
    // forever unless we recreate them once.
    final isFirstRun = previous == null;
    final mustRecreate = !isFirstRun || current != 'en';

    for (final channel in _channels()) {
      if (mustRecreate) {
        await android.deleteNotificationChannel(channelId: channel.id);
      }
      await android.createNotificationChannel(channel);
    }

    await prefs.setString(_localeKey, current);
  }

  static List<AndroidNotificationChannel> _channels() => [
        AndroidNotificationChannel(
          defaultId,
          _text.defaultName,
          description: _text.defaultDescription,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
        AndroidNotificationChannel(
          generalId,
          _text.defaultName,
          description: _text.defaultDescription,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
        AndroidNotificationChannel(
          remindersId,
          _text.remindersName,
          description: _text.remindersDescription,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
        AndroidNotificationChannel(
          recurringId,
          _text.recurringName,
          description: _text.recurringDescription,
          importance: Importance.high,
        ),
        AndroidNotificationChannel(
          periodicId,
          _text.periodicName,
          description: _text.periodicDescription,
          importance: Importance.defaultImportance,
        ),
      ];
}

/// Immutable bundle of the localized channel strings.
class NotificationChannelText {
  const NotificationChannelText({
    required this.defaultName,
    required this.defaultDescription,
    required this.remindersName,
    required this.remindersDescription,
    required this.recurringName,
    required this.recurringDescription,
    required this.periodicName,
    required this.periodicDescription,
  });

  final String defaultName;
  final String defaultDescription;
  final String remindersName;
  final String remindersDescription;
  final String recurringName;
  final String recurringDescription;
  final String periodicName;
  final String periodicDescription;
}
