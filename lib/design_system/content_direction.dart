import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;

/// The direction of user-written text, independent of the UI's direction.
///
/// Notes are content, not chrome: an English note in the Arabic UI should
/// still read left-to-right (bullets on the left), and an Arabic note in the
/// English UI right-to-left. Falls back to [fallback] for neutral text.
TextDirection contentDirection(String text, {TextDirection? fallback}) {
  if (text.trim().isEmpty) return fallback ?? TextDirection.ltr;
  return intl.Bidi.detectRtlDirectionality(text)
      ? TextDirection.rtl
      : TextDirection.ltr;
}
