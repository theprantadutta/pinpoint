import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

/// One local notification, two days out at 10:00, for someone who asked for
/// it on the notification sheet. It says nothing about their notes, is never
/// repeated, and is dropped once they come back by themselves.
class ComeBackNudge {
  ComeBackNudge._();

  static const int notificationId = 970001;
  static const String scheduledAtKey = 'come_back_nudge_scheduled_at_ms';

  /// Opening the app this long after asking counts as coming back.
  static const Duration returnedAfter = Duration(hours: 12);

  /// 10:00 local time, two days after [now].
  static DateTime fireTime(DateTime now) =>
      DateTime(now.year, now.month, now.day + 2, 10);

  static bool hasReturned(DateTime scheduledAt, DateTime now) =>
      now.difference(scheduledAt) >= returnedAfter;

  static Future<void> schedule({
    required String title,
    required String body,
  }) async {
    final now = DateTime.now();
    await NotificationService.scheduleNudgeNotification(
      id: notificationId,
      title: title,
      body: body,
      when: fireTime(now),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(scheduledAtKey, now.millisecondsSinceEpoch);
  }

  /// Runs each time the home shell starts.
  static Future<void> cancelIfReturned() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(scheduledAtKey);
    if (ms == null) return;
    final scheduledAt = DateTime.fromMillisecondsSinceEpoch(ms);
    if (!hasReturned(scheduledAt, DateTime.now())) return;
    await prefs.remove(scheduledAtKey);
    await NotificationService.cancelNotification(notificationId);
  }
}
