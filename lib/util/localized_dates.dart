import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

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
}
