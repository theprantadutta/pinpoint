import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

/// Locale-aware date and time formatting.
///
/// Exists so no call site constructs a bare `DateFormat('MMM d')`. A DateFormat
/// built without a locale silently uses `Intl.defaultLocale` — which nothing in
/// this app sets — and renders English month names and Western digits no matter
/// what language the user picked. That is invisible in review (English looks
/// correct) and wrong everywhere else.
///
/// Every helper takes a [BuildContext] purely to read the active locale.
class LocalizedDates {
  LocalizedDates._();

  static String _localeOf(BuildContext context) =>
      Localizations.localeOf(context).toString();

  /// Abbreviated month, day and year — e.g. "Mar 14, 2026".
  ///
  /// Deliberately uses [DateFormat.yMMMd] rather than a literal pattern:
  /// field *order* is locale-specific too, so a hardcoded "MMM d, y" would
  /// still read wrong in locales that put the day first.
  static String mediumDate(BuildContext context, DateTime date) =>
      DateFormat.yMMMd(_localeOf(context)).format(date);

  /// Full weekday, day, month and year — e.g. "Saturday, 14 March 2026".
  static String fullDate(BuildContext context, DateTime date) =>
      DateFormat.yMMMMEEEEd(_localeOf(context)).format(date);

  /// Time of day, honouring the locale's 12- vs 24-hour convention.
  static String time(BuildContext context, DateTime date) =>
      DateFormat.jm(_localeOf(context)).format(date);

  /// Abbreviated month and day, no year — e.g. "Mar 14".
  static String monthDay(BuildContext context, DateTime date) =>
      DateFormat.MMMd(_localeOf(context)).format(date);

  /// Date and time together, as the locale would join them.
  static String dateTime(BuildContext context, DateTime date) {
    final locale = _localeOf(context);
    return '${DateFormat.yMMMEd(locale).format(date)} '
        '${DateFormat.jm(locale).format(date)}';
  }

  /// "Today, 6:00 PM", "Tomorrow, 9:00 AM" or "Mar 14, 6:00 PM" — the
  /// reminder chip on note cards and in the editor.
  static String relativeDayTime(BuildContext context, DateTime date,
      {DateTime? now}) {
    // Reminder times can arrive in UTC (they are scheduled server-side);
    // always show them in the device's zone.
    date = date.toLocal();
    final l10n = AppL10n.of(context);
    final today = DateUtils.dateOnly(now ?? DateTime.now());
    final day = DateUtils.dateOnly(date);
    final diff = day.difference(today).inDays;
    final dayLabel = switch (diff) {
      0 => l10n.dateToday,
      1 => l10n.dateTomorrow,
      -1 => l10n.dateYesterday,
      _ => monthDay(context, date),
    };
    return l10n.dateDayAtTime(dayLabel, time(context, date));
  }

  /// A recording length as m:ss ("0:42"), in the locale's digits.
  static String duration(BuildContext context, int seconds) {
    final locale = _localeOf(context);
    final m = NumberFormat.decimalPattern(locale).format(seconds ~/ 60);
    final s = NumberFormat('00', locale).format(seconds % 60);
    return '$m:$s';
  }
}
