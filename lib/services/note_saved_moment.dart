import 'package:flutter/foundation.dart';

/// "Someone just wrote a new note", held until they are back on the home
/// shell, where the follow-ups that should come after a success (the
/// notification ask, the review prompt) run once and only then.
///
/// The full-screen editor raises it when it saves a note for the first time;
/// the shell takes it when the editor has closed. In memory only: a moment
/// that passes with the app killed is not worth replaying on the next start.
class NoteSavedMoment {
  NoteSavedMoment._();

  static final ValueNotifier<bool> pending = ValueNotifier<bool>(false);

  static void noteCreated() => pending.value = true;

  /// True once per moment.
  static bool take() {
    if (!pending.value) return false;
    pending.value = false;
    return true;
  }
}
