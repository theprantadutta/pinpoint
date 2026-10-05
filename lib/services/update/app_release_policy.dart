/// What, if anything, to tell the user about a newer build on the store.
enum UpdatePrompt {
  /// Say nothing this session.
  none,

  /// A dismissible notice. Declining snoozes it for [AppReleasePolicy.snooze].
  optional,

  /// A blocking dialog with no way past it. The build in the user's hand has
  /// been declared unfit to keep using.
  required,
}

/// A dotted-numeric version, ordered segment by segment.
///
/// Mirrors `AppVersion` on the backend, which validates what the operator
/// types. The two must agree about ordering, or the server would accept a
/// floor the client reads differently.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion._(this.segments);

  final List<int> segments;

  static final RegExp _shape = RegExp(r'^\d{1,6}(\.\d{1,6}){0,3}$');

  /// Null rather than throwing: every caller treats an unreadable version as
  /// "do nothing", and that must not be an exception path.
  static AppVersion? tryParse(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (!_shape.hasMatch(trimmed)) return null;
    return AppVersion._(
      trimmed.split('.').map(int.parse).toList(growable: false),
    );
  }

  /// A missing segment reads as 0, so 4.1 and 4.1.0 are the same version.
  @override
  int compareTo(AppVersion other) {
    final length = segments.length > other.segments.length
        ? segments.length
        : other.segments.length;
    for (var i = 0; i < length; i++) {
      final a = i < segments.length ? segments[i] : 0;
      final b = i < other.segments.length ? other.segments[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    return 0;
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;

  @override
  String toString() => segments.join('.');
}

/// The rule for which prompt to show on iOS, kept pure so it can be tested.
///
/// The iOS counterpart to `UpdatePolicy`. The shapes differ because the
/// platforms do: Google Play owns the update and tells the app what it has,
/// so Android asks Play. The App Store tells the app nothing, so iOS asks OUR
/// backend what the store is supposed to have and compares itself.
///
/// Every unknown resolves to [UpdatePrompt.none]. A version that will not
/// parse, a policy that never arrived — none of those are reasons to stand
/// between a user and their notes. The only path to [UpdatePrompt.required]
/// is an explicit, readable floor the running build is genuinely below.
class AppReleasePolicy {
  const AppReleasePolicy._();

  /// How long a declined optional prompt is left alone. Matches the Android
  /// snooze so someone switching devices meets the same cadence.
  static const Duration snooze = Duration(hours: 24);

  static UpdatePrompt decide({
    required bool enabled,
    required String? currentVersion,
    required String? latestVersion,
    required String? minimumSupportedVersion,
    required Duration? sinceDeclined,
  }) {
    if (!enabled) return UpdatePrompt.none;

    final current = AppVersion.tryParse(currentVersion);
    // A build whose own version is unreadable is a packaging bug, not the
    // user's problem — it must never lock them out.
    if (current == null) return UpdatePrompt.none;

    final minimum = AppVersion.tryParse(minimumSupportedVersion);
    if (minimum != null && current < minimum) return UpdatePrompt.required;

    final latest = AppVersion.tryParse(latestVersion);
    if (latest == null || !(current < latest)) return UpdatePrompt.none;

    // Only the optional prompt is snoozed; the blocking one returned above.
    if (sinceDeclined != null && sinceDeclined < snooze) {
      return UpdatePrompt.none;
    }

    return UpdatePrompt.optional;
  }
}
