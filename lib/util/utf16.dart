/// Unpaired UTF-16 surrogates.
///
/// An emoji outside the Basic Multilingual Plane is two UTF-16 code units, a
/// high and a low surrogate. When only one of them ends up in a string (half an
/// emoji deleted, pasted or typed), Flutter's text engine throws "string is not
/// well-formed UTF-16" every time it lays the text out, so a note holding one
/// crashes on every open (Crashlytics, 4.3.2, Nov 2026).
library;

bool _isHigh(int u) => u >= 0xD800 && u <= 0xDBFF;
bool _isLow(int u) => u >= 0xDC00 && u <= 0xDFFF;

/// Index of the first unpaired surrogate in [s], or -1 if it is well formed.
int indexOfLoneSurrogate(String s) {
  for (var i = 0; i < s.length; i++) {
    final u = s.codeUnitAt(i);
    if (_isHigh(u)) {
      if (i + 1 < s.length && _isLow(s.codeUnitAt(i + 1))) {
        i++; // A valid pair.
        continue;
      }
      return i;
    }
    if (_isLow(u)) return i;
  }
  return -1;
}

/// [s] with every unpaired surrogate removed. Well-formed text, emoji
/// included, comes back unchanged (and identical, so callers can compare).
String withoutLoneSurrogates(String s) {
  if (indexOfLoneSurrogate(s) < 0) return s;
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final u = s.codeUnitAt(i);
    if (_isHigh(u)) {
      if (i + 1 < s.length && _isLow(s.codeUnitAt(i + 1))) {
        out.writeCharCode(u);
        out.writeCharCode(s.codeUnitAt(i + 1));
        i++;
      }
      continue;
    }
    if (_isLow(u)) continue;
    out.writeCharCode(u);
  }
  return out.toString();
}
