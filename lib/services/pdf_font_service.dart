import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Supplies a [pw.ThemeData] with real fonts embedded, for PDF export.
///
/// Without this the `pdf` package falls back to the PDF base-14 fonts
/// (Helvetica and friends), which contain **Latin glyphs only**. That is worse
/// than the on-screen situation: where Flutter would fall through to a system
/// font, a PDF simply draws nothing, so a Thai, Bengali, Arabic or Persian note
/// exports as a page of blanks with no error anywhere.
///
/// Fonts are parsed once and cached — decoding four TTFs on every export is
/// slow enough to be noticeable, and the theme is immutable.
///
/// **Known limitation:** the `pdf` package does not run a full text shaper, so
/// scripts that need contextual shaping (Bengali conjuncts, Arabic letter
/// joining) can render with imperfect glyph forms even though the characters
/// are now present. Embedding the fonts turns "nothing at all" into "legible",
/// not into "typographically perfect".
class PdfFontService {
  PdfFontService._();

  static pw.ThemeData? _cached;

  /// Latin faces — the app's own UI font, so exports look like the app.
  static const _latinRegular = 'assets/fonts/google_fonts/Inter-Regular.ttf';
  static const _latinBold = 'assets/fonts/google_fonts/Inter-Bold.ttf';
  static const _latinItalic = 'assets/fonts/google_fonts/Inter-Italic.ttf';

  /// One fallback per non-Latin script the app ships. Mirrors
  /// `PinpointTypography.scriptFallbacks`; Arabic covers Persian too.
  static const _fallbacks = <String>[
    'assets/fonts/scripts/NotoSansThai-Regular.ttf',
    'assets/fonts/scripts/NotoSansBengali-Regular.ttf',
    'assets/fonts/scripts/NotoSansArabic-Regular.ttf',
  ];

  /// Build (or return the cached) theme for [pw.Document].
  static Future<pw.ThemeData> theme() async {
    final cached = _cached;
    if (cached != null) return cached;

    Future<pw.Font> load(String path) async =>
        pw.Font.ttf(await rootBundle.load(path));

    final theme = pw.ThemeData.withFont(
      base: await load(_latinRegular),
      bold: await load(_latinBold),
      italic: await load(_latinItalic),
      fontFallback: [
        for (final path in _fallbacks) await load(path),
      ],
    );

    return _cached = theme;
  }
}
