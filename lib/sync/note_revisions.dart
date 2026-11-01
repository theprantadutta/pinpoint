import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Which server copy of each note this device last saw, as the server's own
/// write time (`server_updated_ms`). Sent with every upload as
/// `base_server_ms`, so the server can refuse an edit made on a copy another
/// device has since replaced instead of silently overwriting it (review
/// 2026-11-01, F1). Account-specific: sign-out clears it with the other
/// account preferences.
class NoteRevisions {
  NoteRevisions._();

  static const String prefsKey = 'note_server_revisions';

  static Future<Map<String, int>> all() async {
    final raw = (await SharedPreferences.getInstance()).getString(prefsKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).map((k, v) => MapEntry('$k', (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  /// Record the server copies just seen, keyed by note uuid.
  static Future<void> record(Map<String, int> seen) async {
    if (seen.isEmpty) return;
    final map = await all()..addAll(seen);
    await (await SharedPreferences.getInstance()).setString(prefsKey, jsonEncode(map));
  }

  /// The uuid → server_updated_ms pairs in a list of notes from the server.
  static Map<String, int> from(Iterable<dynamic> notes) => {
        for (final n in notes)
          if (n is Map && n['client_note_uuid'] is String && n['server_updated_ms'] is num)
            n['client_note_uuid'] as String: (n['server_updated_ms'] as num).toInt(),
      };
}
