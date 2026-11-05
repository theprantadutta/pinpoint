import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/services/analytics/first_note_event.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/analytics_recorder.dart';

void main() {
  late RecordingAnalyticsFacade analytics;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    analytics = RecordingAnalyticsFacade();
  });

  test('the first note after onboarding is reported once', () async {
    await FirstNoteEvent.arm(await SharedPreferences.getInstance());

    await FirstNoteEvent.reportIfPending(analytics, noteType: 'text');
    await FirstNoteEvent.reportIfPending(analytics, noteType: 'todo');

    expect(analytics.one('first_note_created').params, {'note_type': 'text'});
  });

  test('someone who never went through onboarding reports nothing', () async {
    await FirstNoteEvent.reportIfPending(analytics, noteType: 'text');

    expect(analytics.contains('first_note_created'), isFalse);
  });
}
