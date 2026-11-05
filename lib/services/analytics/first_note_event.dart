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
  static const String blankNoteKey = 'first_note_blank_note_pending';

  static Future<void> arm(SharedPreferences prefs) async {
    await prefs.setBool(pendingKey, true);
    await prefs.setBool(blankNoteKey, true);
  }

  /// Whether to open a blank note on arriving home after onboarding, so a new
  /// person starts writing instead of facing an empty notebook. True at most
  /// once, and never for someone whose notes came back with their account.
  static Future<bool> takeBlankNote({
    required Future<bool> Function() hasNotes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(blankNoteKey) ?? false)) return false;
    await prefs.remove(blankNoteKey);
    return !await hasNotes();
  }

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
