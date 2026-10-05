/// How an available Play Store update is offered.
enum UpdateFlow {
  /// Nothing this session.
  none,

  /// Play's blocking full-screen flow. The app cannot be used until the
  /// update installs. Reserved for releases published as urgent.
  immediate,

  /// Play downloads in the background while the user keeps writing; the app
  /// offers a restart once the download lands.
  flexible,
}

/// The rule for which flow to run on Android, kept pure so it can be tested.
///
/// Google Play never installs an update silently; both flows need the user
/// to accept a Play-owned dialog. What we control is WHICH one and how often
/// we ask. The old policy ran the blocking flow for every update on every
/// cold start — a wall in front of someone who opened Pinpoint to jot one
/// thing down. Flexible is the default; immediate is for emergencies,
/// signalled by the release's update priority (set when publishing through
/// the Play Developer API; a console upload is priority 0).
class UpdatePolicy {
  const UpdatePolicy._();

  /// Priority at or above which a release is an emergency and gets the
  /// blocking flow. Play's scale is 0 (default) to 5.
  static const int immediatePriorityThreshold = 4;

  /// How long a declined flexible offer is left alone before asking again.
  static const Duration snooze = Duration(hours: 24);

  static UpdateFlow decide({
    required bool updateAvailable,
    required int priority,
    required bool immediateAllowed,
    required bool flexibleAllowed,
    required Duration? sinceDeclined,
  }) {
    if (!updateAvailable) return UpdateFlow.none;

    // An emergency cuts through a snooze: the point of the priority is that
    // this one cannot wait for a better moment.
    if (priority >= immediatePriorityThreshold && immediateAllowed) {
      return UpdateFlow.immediate;
    }

    if (sinceDeclined != null && sinceDeclined < snooze) return UpdateFlow.none;

    if (flexibleAllowed) return UpdateFlow.flexible;

    // Play sometimes allows only the immediate flow (for example when a
    // flexible download is in an odd state). A routine release is not worth
    // a wall; wait for the next check.
    return UpdateFlow.none;
  }
}
