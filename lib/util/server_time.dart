/// Parses a timestamp from the Pinpoint API.
///
/// The .NET backend stores UTC but serialises many `DateTime`s without a
/// zone designator ("2026-10-05T12:00:00"). `DateTime.parse` reads such a
/// string as *local* time, which shifts the instant by the device's UTC
/// offset — a reminder set for 18:00 in Dhaka came back as 12:00. A string
/// without a zone is therefore read as UTC; one with a zone is honoured.
/// The result is in local time, ready for display and scheduling.
DateTime parseServerUtc(String raw) {
  final s = raw.trim();
  final hasZone = s.endsWith('Z') ||
      s.endsWith('z') ||
      RegExp(r'[+-]\d\d:?\d\d$').hasMatch(s);
  return DateTime.parse(hasZone ? s : '${s}Z').toLocal();
}
