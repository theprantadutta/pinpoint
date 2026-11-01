import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/components/create_note_screen/reminder_type/reminder_delivery_status.dart';

/// The reminder editor says whether this phone will ring (review 2026-11-01,
/// F4): notifications off beats everything; otherwise exact or a little late.
void main() {
  test('notifications off: blocked, whatever exact alarms say', () {
    expect(reminderDelivery(notificationsOn: false, exactAllowed: true), ReminderDelivery.blocked);
    expect(reminderDelivery(notificationsOn: false, exactAllowed: false), ReminderDelivery.blocked);
  });

  test('notifications on: exact when allowed, else possibly late', () {
    expect(reminderDelivery(notificationsOn: true, exactAllowed: true), ReminderDelivery.exact);
    expect(reminderDelivery(notificationsOn: true, exactAllowed: false), ReminderDelivery.inexact);
  });
}
