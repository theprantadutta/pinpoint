import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database.dart';
import '../service_locators/init_service_locators.dart';

/// Notes the server held back because a free account is at its sync limit.
///
/// They are safe on this device and offered again at every sync, but until
/// one is accepted it exists nowhere else: not on the user's other devices,
/// and not after a lost phone. The cards and the editor mark them "Only on
/// this phone" so nobody switches phones believing everything is backed up.
///
/// Recorded from the server's answer (`rejected_uuids` / accepted notes) at
/// every upload, so the marks are right even when the user never opens the
/// sync screen. A note leaves the set the moment the server takes it.
class HeldBackNotes {
  HeldBackNotes._();

  static const String prefsKey = 'sync_held_back_uuids';
  static const String _dismissedKey = 'sync_held_back_banner_dismissed_at';

  /// The held-back uuids; listen to rebuild markers.
  static final ValueNotifier<Set<String>> notifier = ValueNotifier(const {});

  /// How many were held back when the home banner was last dismissed, so it
  /// comes back only if more notes stop backing up.
  static final ValueNotifier<int> dismissedAt = ValueNotifier(0);

  static bool contains(String? uuid) => uuid != null && notifier.value.contains(uuid);

  /// The set after one upload. Pure, for testing.
  static Set<String> apply(Set<String> current, {required Iterable<String> rejected, required Iterable<String> accepted}) =>
      {...current.difference(accepted.toSet()), ...rejected};

  /// Load the saved set, dropping notes that no longer exist on this device.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = (prefs.getStringList(prefsKey) ?? const []).toSet();
      dismissedAt.value = prefs.getInt(_dismissedKey) ?? 0;
      if (saved.isEmpty) {
        notifier.value = const {};
        return;
      }
      final existing = await _existingUuids();
      final kept = saved.intersection(existing);
      if (kept.length != saved.length) await prefs.setStringList(prefsKey, kept.toList());
      notifier.value = kept;
    } catch (e) {
      debugPrint('⚠️ [HeldBack] Could not load: $e');
    }
  }

  /// Apply one upload's answer from the server. Notes trashed or deleted
  /// since are dropped too: nothing left to back up.
  static Future<void> record({required Iterable<String> rejected, required Iterable<String> accepted}) async {
    var next = apply(notifier.value, rejected: rejected, accepted: accepted);
    if (next.isNotEmpty) {
      try {
        next = next.intersection(await _existingUuids());
      } catch (_) {}
    }
    if (setEquals(next, notifier.value)) return;
    notifier.value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(prefsKey, next.toList());
      // Everything backed up again: the next time it happens, show the banner.
      if (next.isEmpty) {
        dismissedAt.value = 0;
        await prefs.remove(_dismissedKey);
      }
    } catch (e) {
      debugPrint('⚠️ [HeldBack] Could not save: $e');
    }
  }

  static Future<void> dismissBanner() async {
    dismissedAt.value = notifier.value.length;
    try {
      await (await SharedPreferences.getInstance()).setInt(_dismissedKey, dismissedAt.value);
    } catch (_) {}
  }

  /// After sign-out (its preferences are cleared separately).
  static void reset() {
    notifier.value = const {};
    dismissedAt.value = 0;
  }

  /// Notes on this device that are not in the trash.
  static Future<Set<String>> _existingUuids() async {
    final db = getIt<AppDatabase>();
    return {
      for (final n in await (db.select(db.textNotesV2)..where((t) => t.isDeleted.equals(false))).get()) n.uuid,
      for (final n in await (db.select(db.todoListNotesV2)..where((t) => t.isDeleted.equals(false))).get()) n.uuid,
      for (final n in await (db.select(db.voiceNotesV2)..where((t) => t.isDeleted.equals(false))).get()) n.uuid,
      for (final n in await (db.select(db.reminderNotesV2)..where((t) => t.isDeleted.equals(false))).get()) n.uuid,
    };
  }
}
