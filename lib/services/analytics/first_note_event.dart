import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_facade.dart';

/// Reports first_note_created once, for the first note after onboarding.
///
/// Finishing onboarding arms it, so people who were already using the app when
/// this shipped never report a "first" note. A reinstall goes through
/// onboarding again and counts as a new start.
class FirstNoteEvent {
  FirstNoteEvent._();

  static const String pendingKey = 'first_note_event_pending';

  static Future<void> arm(SharedPreferences prefs) =>
      prefs.setBool(pendingKey, true);

  static Future<void> reportIfPending(
    AnalyticsFacade analytics, {
    required String noteType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(pendingKey) ?? false)) return;
    await prefs.remove(pendingKey);
    await analytics.trackFirstNoteCreated(noteType: noteType);
  }
}
