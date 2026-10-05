import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// Pinpoint Design System - Typography
/// Writing-focused type system optimized for note-taking
class PinpointTypography {
  // Private constructor to prevent instantiation
  PinpointTypography._();

  // ============================================
  // Font Families
  // ============================================

  /// Primary font for UI and reading. The user's font picker overrides it.
  static const String primaryFontFamily = 'Plus Jakarta Sans';

  /// Headings use the same family as the UI in Sketchbook.
  static const String headingFontFamily = 'Plus Jakarta Sans';

  /// Monospace font for code blocks
  static const String monospaceFontFamily = 'JetBrains Mono';

  /// Editor body. Follows the UI family.
  static const String writingFontFamily = 'Plus Jakarta Sans';

  /// Handwritten accents only — never UI labels.
  static const String handwritingFontFamily = 'Caveat';

  // ============================================
  // Script fallbacks
  // ============================================

  /// Faces consulted, per glyph, when the chosen UI font has nothing to draw.
  ///
  /// Every bundled google_fonts family is a **Latin subset** — Inter-Regular is
  /// 66 KB where the full face is ~300 KB — and `allowRuntimeFetching` is off
  /// (see main.dart), so nothing is downloaded to cover the gap at runtime.
  /// Without this chain, Thai, Bengali, Arabic and Persian render as tofu or
  /// silently fall through to whatever the OS provides, which throws away the
  /// user's font choice on exactly the locales that need it most.
  ///
  /// Ordering is irrelevant to correctness — the scripts do not overlap, so at
  /// most one family can supply any given glyph. Declared statically in
  /// pubspec.yaml so these names resolve in the font registry.
  static const List<String> scriptFallbacks = <String>[
    'Noto Sans Thai',
    'Noto Sans Bengali',
    // Covers Persian as well as Arabic.
    'Noto Sans Arabic',
  ];

  /// [GoogleFonts.getFont] with the script fallback chain attached.
  ///
  /// Every style in this file goes through here (or [_mono]) rather than
  /// calling google_fonts directly, so a new text style cannot accidentally
  /// ship without non-Latin coverage.
  static TextStyle _font(
    String family, {
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    Color? color,
  }) {
    return GoogleFonts.getFont(
      family,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
    ).copyWith(fontFamilyFallback: scriptFallbacks);
  }

  /// The UI fonts a user can pick in Settings → Theme, by google_fonts family
  /// name (which is what [ThemeController] persists). Every one is bundled.
  static const List<String> selectableFonts = <String>[
    'Plus Jakarta Sans',
    'Inter',
    'Roboto',
    'Open Sans',
    'Lato',
    'Montserrat',
    'Poppins',
    'Source Sans 3',
    'Noto Sans',
  ];

  /// A sample of [family] for the font picker, with the script fallbacks.
  static TextStyle fontPreview(
    String family, {
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
  }) =>
      _font(family, fontSize: fontSize, fontWeight: fontWeight, color: color);

  /// Monospace equivalent of [_font]. JetBrains Mono is Latin-only too, and
  /// code blocks can legitimately contain non-Latin text in comments.
  static TextStyle _mono({
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    Color? color,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
    ).copyWith(fontFamilyFallback: scriptFallbacks);
  }

  // ============================================
  // Text Themes
  // ============================================

  /// Ink and muted for [brightness] (Sketchbook roles).
  static Color _ink(Brightness b) =>
      b == Brightness.dark ? SketchColors.dark.ink : SketchColors.light.ink;
  static Color _muted(Brightness b) =>
      b == Brightness.dark ? SketchColors.dark.muted : SketchColors.light.muted;

  /// The Sketchbook type scale mapped onto Material's roles, so widgets that
  /// read `Theme.of(context).textTheme` land on the new scale.
  ///
  /// | Role           | Sketchbook     | Size/weight |
  /// |----------------|----------------|-------------|
  /// | displayLarge   | displayNumber  | 40 / 800    |
  /// | displayMedium  | paywall title  | 32 / 800    |
  /// | displaySmall   | screenTitle    | 30 / 800    |
  /// | headlineLarge  | pageTitle      | 28 / 800    |
  /// | headlineMedium | sheetTitle     | 26 / 800    |
  /// | headlineSmall  | empty / dialog | 22 / 800    |
  /// | titleLarge     | brand          | 20 / 800    |
  /// | titleMedium    | sectionTitle   | 18 / 700    |
  /// | titleSmall     | cardTitle      | 15 / 700    |
  /// | bodyLarge      | editor body    | 16 / 400    |
  /// | bodyMedium     | body           | 15 / 500    |
  /// | bodySmall      | bodySmall      | 13 / 500    |
  /// | labelLarge     | button         | 16 / 700    |
  /// | labelMedium    | chip           | 13 / 600    |
  /// | labelSmall     | caption        | 12 / 600    |
  static TextTheme createTextTheme({
    required Brightness brightness,
    String? primaryFont,
    String? headingFont,
    String? monoFont,
  }) {
    final f = primaryFont ?? primaryFontFamily;
    final ink = _ink(brightness);
    final muted = _muted(brightness);

    TextStyle s(double size, FontWeight w, double h,
            {double trackingEm = 0, Color? color}) =>
        _font(f,
            fontSize: size,
            fontWeight: w,
            height: h,
            letterSpacing: size * trackingEm,
            color: color ?? ink);

    return TextTheme(
      displayLarge: s(40, FontWeight.w800, 1.0, trackingEm: -0.04),
      displayMedium: s(32, FontWeight.w800, 1.15, trackingEm: -0.03),
      displaySmall: s(30, FontWeight.w800, 1.1, trackingEm: -0.03),
      headlineLarge: s(28, FontWeight.w800, 1.15, trackingEm: -0.025),
      headlineMedium: s(26, FontWeight.w800, 1.1, trackingEm: -0.02),
      headlineSmall: s(22, FontWeight.w800, 1.2, trackingEm: -0.02),
      titleLarge: s(20, FontWeight.w800, 1.2, trackingEm: -0.02),
      titleMedium: s(18, FontWeight.w700, 1.3),
      titleSmall: s(15, FontWeight.w700, 1.25),
      bodyLarge: s(16, FontWeight.w400, 1.65),
      bodyMedium: s(15, FontWeight.w500, 1.5),
      bodySmall: s(13, FontWeight.w500, 1.45, color: muted),
      labelLarge: s(16, FontWeight.w700, 1.25),
      labelMedium: s(13, FontWeight.w600, 1.3),
      labelSmall: s(12, FontWeight.w600, 1.4, color: muted),
    );
  }

  /// The named Sketchbook styles, registered as a [ThemeExtension].
  static SketchText createSketchText({
    required Brightness brightness,
    String? primaryFont,
  }) {
    final f = primaryFont ?? primaryFontFamily;
    final ink = _ink(brightness);
    final muted = _muted(brightness);

    TextStyle s(double size, FontWeight w, double h,
            {double trackingEm = 0, Color? color}) =>
        _font(f,
            fontSize: size,
            fontWeight: w,
            height: h,
            letterSpacing: size * trackingEm,
            color: color ?? ink);

    return SketchText(
      displayNumber: s(40, FontWeight.w800, 1.0, trackingEm: -0.04),
      heroTitle: s(32, FontWeight.w800, 1.15, trackingEm: -0.03),
      screenTitle: s(30, FontWeight.w800, 1.1, trackingEm: -0.03),
      pageTitle: s(28, FontWeight.w800, 1.15, trackingEm: -0.025),
      sheetTitle: s(26, FontWeight.w800, 1.1, trackingEm: -0.02),
      emptyTitle: s(22, FontWeight.w800, 1.2, trackingEm: -0.02),
      brand: s(20, FontWeight.w800, 1.2, trackingEm: -0.02),
      sectionTitle: s(18, FontWeight.w700, 1.3),
      cardTitleLarge: s(17, FontWeight.w700, 1.25),
      cardTitle: s(15, FontWeight.w700, 1.25),
      bodyLarge: s(16, FontWeight.w400, 1.65),
      body: s(15, FontWeight.w600, 1.5),
      bodyRegular: s(15, FontWeight.w500, 1.5),
      bodySmall: s(13, FontWeight.w500, 1.45, color: muted),
      chip: s(13, FontWeight.w600, 1.3),
      caption: s(12, FontWeight.w500, 1.4, color: muted),
      overline: s(11, FontWeight.w700, 1.2, trackingEm: 0.10, color: muted),
      button: s(16, FontWeight.w700, 1.25),
      handwriting: _font(handwritingFontFamily,
          fontSize: 40, fontWeight: FontWeight.w600, height: 1.0),
    );
  }

  // ============================================
  // Specialized Text Styles
  // ============================================

  /// Editor title style - large, prominent for note titles (BOLD)
  static TextStyle editorTitle({required Brightness brightness}) {
    final color = _ink(brightness);

    return _font(
      headingFontFamily,
      fontSize: 32, // Larger
      fontWeight: FontWeight.w800, // BOLD: Increased from w700
      letterSpacing: -0.8, // Tighter
      height: 1.25,
      color: color,
    );
  }

  /// Editor body style - optimized for writing
  static TextStyle editorBody({
    required Brightness brightness,
    bool focusMode = false,
  }) {
    final color = _ink(brightness);

    return _font(
      writingFontFamily,
      fontSize: focusMode ? 18 : 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: focusMode ? 1.8 : 1.6,
      color: color,
    );
  }

  /// Code block style - monospace for code
  static TextStyle codeBlock({required Brightness brightness}) {
    final color = _ink(brightness);

    return _mono(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.4,
      color: color,
    );
  }

  /// Note card title (BOLD)
  static TextStyle noteCardTitle({required Brightness brightness}) {
    final color = _ink(brightness);

    return _font(
      primaryFontFamily,
      fontSize: 17, // Slightly larger
      fontWeight: FontWeight.w700, // BOLD: Increased from w600
      letterSpacing: -0.1, // Tighter
      height: 1.4,
      color: color,
    );
  }

  /// Note card excerpt
  static TextStyle noteCardExcerpt({required Brightness brightness}) {
    final color = _muted(brightness);

    return _font(
      primaryFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.5,
      color: color,
    );
  }

  /// Metadata text (timestamps, counts, etc.)
  static TextStyle metadata({required Brightness brightness}) {
    final color = _muted(brightness);

    return _font(
      primaryFontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.3,
      height: 1.4,
      color: color,
    );
  }

  /// Tag chip text
  static TextStyle tagChip({
    required Brightness brightness,
    Color? color,
  }) {
    final textColor = color ?? _ink(brightness);

    return _font(
      primaryFontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
      height: 1.3,
      color: textColor,
    );
  }

  /// Button text styles (BOLD)
  static TextStyle button({
    required Brightness brightness,
    ButtonSize size = ButtonSize.medium,
    Color? color,
  }) {
    final textColor = color ?? _ink(brightness);

    double fontSize;
    FontWeight fontWeight;

    switch (size) {
      case ButtonSize.small:
        fontSize = 13; // Slightly larger
        fontWeight = FontWeight.w600; // BOLD: Increased from w500
        break;
      case ButtonSize.medium:
        fontSize = 15; // Slightly larger
        fontWeight = FontWeight.w700; // BOLD: Increased from w600
        break;
      case ButtonSize.large:
        fontSize = 17; // Slightly larger
        fontWeight = FontWeight.w700; // BOLD: Same weight
        break;
    }

    return _font(
      primaryFontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: 0.3, // Tighter
      height: 1.4,
      color: textColor,
    );
  }

  /// Empty state text
  static TextStyle emptyState({
    required Brightness brightness,
    bool isTitle = false,
  }) {
    final color = _muted(brightness);

    if (isTitle) {
      return _font(
        headingFontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.4,
        color: color,
      );
    }

    return _font(
      primaryFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.5,
      color: color.withValues(alpha: 0.8),
    );
  }

  /// Keyboard shortcut hint text
  static TextStyle keyboardHint({required Brightness brightness}) {
    final color = _muted(brightness);

    return _mono(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.3,
      color: color,
    );
  }
}

/// Button size variants
enum ButtonSize {
  small,
  medium,
  large,
}

/// Text style utilities
class TextStyleUtils {
  /// Apply gradient to text
  static ShaderMask gradientText({
    required Widget child,
    required Gradient gradient,
  }) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: child,
    );
  }

  /// Get responsive font size
  static double responsiveFontSize(
    BuildContext context,
    double baseSize, {
    double? minSize,
    double? maxSize,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth / 375; // Base on iPhone 11 width

    final scaledSize = baseSize * scaleFactor;

    if (minSize != null && scaledSize < minSize) return minSize;
    if (maxSize != null && scaledSize > maxSize) return maxSize;

    return scaledSize;
  }
}

/// The named Sketchbook text styles (`context.type`). Colours are ink, or
/// muted where the role is secondary; override with `copyWith(color:)`.
@immutable
class SketchText extends ThemeExtension<SketchText> {
  const SketchText({
    required this.displayNumber,
    required this.heroTitle,
    required this.screenTitle,
    required this.pageTitle,
    required this.sheetTitle,
    required this.emptyTitle,
    required this.brand,
    required this.sectionTitle,
    required this.cardTitleLarge,
    required this.cardTitle,
    required this.bodyLarge,
    required this.body,
    required this.bodyRegular,
    required this.bodySmall,
    required this.chip,
    required this.caption,
    required this.overline,
    required this.button,
    required this.handwriting,
  });

  /// 40/800 — "221B", "50%".
  final TextStyle displayNumber;

  /// 32/800 — the paywall headline.
  final TextStyle heroTitle;

  /// 30/800 — "My folders".
  final TextStyle screenTitle;

  /// 28/800 — "Settings", the note title.
  final TextStyle pageTitle;

  /// 26/800 — "Filters".
  final TextStyle sheetTitle;

  /// 22/800 — empty states, confirm sheets.
  final TextStyle emptyTitle;

  /// 20/800 — "Pinpoint" header.
  final TextStyle brand;

  /// 18/700 — "My folders", "Recent notes".
  final TextStyle sectionTitle;

  /// 17/700 — folder tile and drawer profile titles.
  final TextStyle cardTitleLarge;

  /// 15/700 — note card titles.
  final TextStyle cardTitle;

  /// 16/400, 1.65 — editor body.
  final TextStyle bodyLarge;

  /// 15/600 — list, settings and menu rows.
  final TextStyle body;

  /// 15/500 — body copy.
  final TextStyle bodyRegular;

  /// 13/500 muted — subtitles.
  final TextStyle bodySmall;

  /// 13/600 — chip labels.
  final TextStyle chip;

  /// 12/500 muted — card snippets, counts.
  final TextStyle caption;

  /// 11/700 +0.1em muted — render UPPERCASE ("FOLDERS").
  final TextStyle overline;

  /// 16/700 — pill buttons.
  final TextStyle button;

  /// Caveat 40/600 — handwritten accents only.
  final TextStyle handwriting;

  @override
  SketchText copyWith({
    TextStyle? displayNumber,
    TextStyle? heroTitle,
    TextStyle? screenTitle,
    TextStyle? pageTitle,
    TextStyle? sheetTitle,
    TextStyle? emptyTitle,
    TextStyle? brand,
    TextStyle? sectionTitle,
    TextStyle? cardTitleLarge,
    TextStyle? cardTitle,
    TextStyle? bodyLarge,
    TextStyle? body,
    TextStyle? bodyRegular,
    TextStyle? bodySmall,
    TextStyle? chip,
    TextStyle? caption,
    TextStyle? overline,
    TextStyle? button,
    TextStyle? handwriting,
  }) {
    return SketchText(
      displayNumber: displayNumber ?? this.displayNumber,
      heroTitle: heroTitle ?? this.heroTitle,
      screenTitle: screenTitle ?? this.screenTitle,
      pageTitle: pageTitle ?? this.pageTitle,
      sheetTitle: sheetTitle ?? this.sheetTitle,
      emptyTitle: emptyTitle ?? this.emptyTitle,
      brand: brand ?? this.brand,
      sectionTitle: sectionTitle ?? this.sectionTitle,
      cardTitleLarge: cardTitleLarge ?? this.cardTitleLarge,
      cardTitle: cardTitle ?? this.cardTitle,
      bodyLarge: bodyLarge ?? this.bodyLarge,
      body: body ?? this.body,
      bodyRegular: bodyRegular ?? this.bodyRegular,
      bodySmall: bodySmall ?? this.bodySmall,
      chip: chip ?? this.chip,
      caption: caption ?? this.caption,
      overline: overline ?? this.overline,
      button: button ?? this.button,
      handwriting: handwriting ?? this.handwriting,
    );
  }

  @override
  SketchText lerp(ThemeExtension<SketchText>? other, double t) {
    if (other is! SketchText) return this;
    TextStyle l(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return SketchText(
      displayNumber: l(displayNumber, other.displayNumber),
      heroTitle: l(heroTitle, other.heroTitle),
      screenTitle: l(screenTitle, other.screenTitle),
      pageTitle: l(pageTitle, other.pageTitle),
      sheetTitle: l(sheetTitle, other.sheetTitle),
      emptyTitle: l(emptyTitle, other.emptyTitle),
      brand: l(brand, other.brand),
      sectionTitle: l(sectionTitle, other.sectionTitle),
      cardTitleLarge: l(cardTitleLarge, other.cardTitleLarge),
      cardTitle: l(cardTitle, other.cardTitle),
      bodyLarge: l(bodyLarge, other.bodyLarge),
      body: l(body, other.body),
      bodyRegular: l(bodyRegular, other.bodyRegular),
      bodySmall: l(bodySmall, other.bodySmall),
      chip: l(chip, other.chip),
      caption: l(caption, other.caption),
      overline: l(overline, other.overline),
      button: l(button, other.button),
      handwriting: l(handwriting, other.handwriting),
    );
  }
}

/// `context.type` — the current [SketchText].
extension SketchTextContext on BuildContext {
  SketchText get type =>
      Theme.of(this).extension<SketchText>() ??
      PinpointTypography.createSketchText(
          brightness: Theme.of(this).brightness);
}
