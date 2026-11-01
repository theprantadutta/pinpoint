import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/models/reminder_dto.dart';
import 'package:pinpoint/services/reminder_local_scheduler.dart';

import 'support/project_source.dart';

/// Review 2026-11-01, F5: a reminder rings on the device that set it even
/// offline or with the app closed, and is not pushed to that device as well.
void main() {
  final now = DateTime(2026, 11, 1, 9);
  ReminderNoteEntity reminder({DateTime? at, bool deleted = false, bool triggered = false}) => ReminderNoteEntity(
        id: 1, uuid: 'r-1', title: 'Call mum', notificationTitle: 'Call mum',
        reminderTime: at ?? now.add(const Duration(hours: 1)),
        recurrenceType: 'once', recurrenceInterval: 1, recurrenceEndType: 'never', occurrenceNumber: 1,
        isTriggered: triggered, isPinned: false, isArchived: false, isDeleted: deleted, isSynced: false,
        createdAt: now, updatedAt: now,
      );

  test('only a live, future reminder rings locally', () {
    expect(ReminderLocalScheduler.shouldSchedule(reminder(), now), isTrue);
    expect(ReminderLocalScheduler.shouldSchedule(reminder(at: now.subtract(const Duration(minutes: 1))), now), isFalse);
    expect(ReminderLocalScheduler.shouldSchedule(reminder(deleted: true), now), isFalse);
    expect(ReminderLocalScheduler.shouldSchedule(reminder(triggered: true), now), isFalse);
  });

  test('ids are stable and positive, and the tag matches the server push', () {
    final id = ReminderLocalScheduler.notificationId('r-1');
    expect(id, ReminderLocalScheduler.notificationId('r-1'));
    expect(id, isNonNegative);
    expect(id, isNot(ReminderLocalScheduler.notificationId('r-2')));
    // FcmService.ReminderTag on the server builds the same string.
    expect(ReminderLocalScheduler.tag('abc'), 'reminder-abc');
  });

  test('sync tells the server which device rings locally', () {
    final json = ReminderDto.fromLocal(
      noteUuid: 'r-1', title: 't', notificationTitle: 't', reminderTime: now, localDeviceId: 'android-123',
    ).toJsonSync();
    expect(json['local_device_id'], 'android-123');
    expect(ReminderDto.fromLocal(noteUuid: 'r-1', title: 't', notificationTitle: 't', reminderTime: now)
        .toJsonSync()
        .containsKey('local_device_id'), isFalse);
  });

  test('wired: create, update, delete and restore keep the local alarm in step', () {
    final src = readProjectFile('lib/services/reminder_note_service.dart');
    expect(RegExp(r'ReminderLocalScheduler\.schedule\(').allMatches(src).length, greaterThanOrEqualTo(3));
    expect(src, contains('ReminderLocalScheduler.cancel(noteToDelete.uuid)'));
    expect(readProjectFile('lib/services/reminder_sync_service.dart'), contains('localDeviceId:'));
  });
}
