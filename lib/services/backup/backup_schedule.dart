/// How often a backup goes up on its own. An interval with a number of files
/// to keep, as The Accountant (and Cashew) do: an interval alone fills the
/// Drive for ever, and a count alone never runs.
enum BackupFrequency {
  /// Only when the button is pressed.
  manual(null),
  daily(Duration(days: 1)),
  weekly(Duration(days: 7)),
  monthly(Duration(days: 30));

  const BackupFrequency(this.interval);

  /// How long after the last backup the next is due; null when never on its own.
  final Duration? interval;

  static BackupFrequency fromName(String? name) => BackupFrequency.values
      .firstWhere((f) => f.name == name, orElse: () => BackupFrequency.manual);
}

/// Why the last automatic backup did not happen, so a schedule that has quietly
/// stopped can say so instead of looking idle.
enum BackupFailure { needsAuthorization, offline, storageFull, failed }

class BackupSchedule {
  const BackupSchedule({
    this.frequency = BackupFrequency.manual,
    this.keep = defaultKeep,
    this.lastBackupAt,
    this.lastFailure,
  });

  /// Enough history to notice a mistake a few days late without filling the
  /// user's Drive.
  static const int defaultKeep = 5;
  static const List<int> keepOptions = [3, 5, 10, 20];

  final BackupFrequency frequency;

  /// How many backups to keep. Older ones are removed after a successful run,
  /// never before, so a failed upload cannot cost a copy already there.
  final int keep;
  final DateTime? lastBackupAt;
  final BackupFailure? lastFailure;

  bool get isAutomatic => frequency.interval != null;

  /// Whether an automatic run is owed as of [now].
  bool isDue(DateTime now) {
    final interval = frequency.interval;
    if (interval == null) return false;
    final last = lastBackupAt;
    return last == null || !now.isBefore(last.add(interval));
  }

  BackupSchedule copyWith({
    BackupFrequency? frequency,
    int? keep,
    DateTime? lastBackupAt,
    BackupFailure? lastFailure,
    bool clearFailure = false,
  }) =>
      BackupSchedule(
        frequency: frequency ?? this.frequency,
        keep: keep ?? this.keep,
        lastBackupAt: lastBackupAt ?? this.lastBackupAt,
        lastFailure: clearFailure ? null : (lastFailure ?? this.lastFailure),
      );
}
