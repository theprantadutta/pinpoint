import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database.dart';
import 'notification_service.dart';
import 'subscription_manager.dart';

/// A reminder rings on the device that set it even offline or with the app
/// closed, as a local notification (review 2026-11-01, F5). The server's push
/// still reaches the user's other devices; the device that scheduled locally
/// is reported in sync (`local_device_id`) so it is not pushed to as well.
///
/// The claim is made only for an exact alarm: if exact alarms are refused the
/// notification is still scheduled (inexactly) but the push keeps coming, and
/// the shared Android tag makes the two replace each other, not stack.
class ReminderLocalScheduler {
  ReminderLocalScheduler._();

  static const String prefsKey = 'reminders_scheduled_locally';

  /// Stable, positive notification id per reminder. Pure, for testing.
  static int notificationId(String uuid) {
    var hash = 0x811c9dc5;
    for (final unit in uuid.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  /// Shared with the server push, so a duplicate replaces rather than stacks.
  static String tag(String uuid) => 'reminder-$uuid';

  /// Whether [note] should ring locally now. Pure, for testing.
  static bool shouldSchedule(ReminderNoteEntity note, DateTime now) =>
      !note.isDeleted && !note.isTriggered && note.reminderTime.isAfter(now);

  /// Schedule (or reschedule) [note]; returns whether it holds an exact alarm.
  static Future<bool> schedule(ReminderNoteEntity note) async {
    if (!shouldSchedule(note, DateTime.now())) {
      await cancel(note.uuid);
      return false;
    }
    final title = (note.notificationTitle?.trim().isNotEmpty ?? false)
        ? note.notificationTitle!
        : (note.title ?? '');
    final body = note.notificationContent ?? note.description ?? '';
    var exact = false;
    try {
      exact = await NotificationService.scheduleReminderNotification(
        id: notificationId(note.uuid),
        title: title,
        body: body,
        when: note.reminderTime,
        tag: tag(note.uuid),
        payload: note.uuid,
      );
    } catch (e) {
      debugPrint('⚠️ [ReminderLocal] Could not schedule ${note.uuid}: $e');
    }
    await _record(note.uuid, exact);
    return exact;
  }

  static Future<void> cancel(String uuid) async {
    try {
      await NotificationService.cancelNotification(notificationId(uuid));
    } catch (_) {}
    await _record(uuid, false);
  }

  static Future<Set<String>> scheduledUuids() async =>
      ((await SharedPreferences.getInstance()).getStringList(prefsKey) ?? const []).toSet();

  /// This device's id when it scheduled [uuid] locally, else null.
  static Future<String?> localDeviceIdFor(String uuid) async =>
      (await scheduledUuids()).contains(uuid) ? await SubscriptionManager().installId() : null;

  static Future<void> _record(String uuid, bool exact) async {
    final prefs = await SharedPreferences.getInstance();
    final set = (prefs.getStringList(prefsKey) ?? const []).toSet();
    final changed = exact ? set.add(uuid) : set.remove(uuid);
    if (changed) await prefs.setStringList(prefsKey, set.toList());
  }
}
