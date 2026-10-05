import 'package:flutter/material.dart';

// ============================================
// Sketchbook — the design language
// ============================================
//
// Cream paper, 1.5px ink outlines, flat pastels. Screens read the per-theme
// roles from [SketchColors] (`context.sketch`) and the fixed pastels from
// [SketchPastels]; nothing in a widget should need a hex literal.

/// The five pastels. Identical in light and dark: anything drawn ON a pastel
/// is [onPastel] and a pastel element is always outlined in [onPastel].
class SketchPastels {
  SketchPastels._();

  static const Color yellow = Color(0xFFF6E27A);
  static const Color lavender = Color(0xFFB9B6F2);
  static const Color mint = Color(0xFFC9EDB4);
  static const Color pink = Color(0xFFF7B8C8);
  static const Color sky = Color(0xFFA9D3F5);

  /// Text, icons and outline on any pastel, in both themes.
  static const Color onPastel = Color(0xFF141414);

  /// Round-robin order for things that get a pastel assigned (folders).
  static const List<Color> roundRobin = [yellow, lavender, mint, sky, pink];

  /// Stable names, matching [roundRobin] and the persisted folder colour.
  static const List<String> names = [
    'yellow',
    'lavender',
    'mint',
    'sky',
    'pink'
  ];

  static Color? byName(String? name) {
    final i = name == null ? -1 : names.indexOf(name);
    return i < 0 ? null : roundRobin[i];
  }
}

/// Functional colours that are not theme roles.
class SketchFunctional {
  SketchFunctional._();

  /// Success dot on paper.
  static const Color success = Color(0xFF3DBE7A);

  /// Success dot on a lavender card.
  static const Color successOnPastel = Color(0xFF1F9D5B);

  /// Error text, on the [errorFill] pill.
  static const Color error = Color(0xFFE5484D);
  static const Color errorFill = Color(0xFFFFE1E1);
}

/// The user-selectable accent. Picking one only swaps the "highlight" pastel —
/// marker highlight, selected states, the progress card, the logo sticker.
///
/// [legacyColor] is what [ThemeController] persists (the pre-Sketchbook accent
/// hex), so a stored preference round-trips through older builds. [premiumName]
/// is the key [PremiumLimits.freeThemeColors] gates on.
enum SketchAccent {
  amber(SketchPastels.yellow, Color(0xFFF59E0B), 'Orange Sunset'),
  iris(SketchPastels.lavender, Color(0xFF6366F1), 'Purple Dream'),
  mint(SketchPastels.mint, Color(0xFF10B981), 'Neon Mint'),
  rose(SketchPastels.pink, Color(0xFFF43F5E), 'Pink Bliss'),
  ocean(SketchPastels.sky, Color(0xFF0EA5E9), 'Blue Ocean');

  const SketchAccent(this.pastel, this.legacyColor, this.premiumName);

  final Color pastel;

  /// The old accent hex. Also the swatch dot in Settings → Accent, so people
  /// recognise the choice they made before the redesign.
  final Color legacyColor;
  final String premiumName;

  static const SketchAccent fallback = SketchAccent.amber;

  /// Resolve a persisted ARGB value. Anything unknown — including the old
  /// indigo default — becomes [fallback].
  static SketchAccent fromStored(int? argb) {
    if (argb == null) return fallback;
    for (final a in values) {
      if (a.legacyColor.toARGB32() == argb) return a;
    }
    return fallback;
  }

  static SketchAccent? fromName(String? name) {
    for (final a in values) {
      if (a.name == name) return a;
    }
    return null;
  }
}

/// Per-theme colour roles. Registered on both [ThemeData]s.
@immutable
class SketchColors extends ThemeExtension<SketchColors> {
  const SketchColors({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.outline,
    required this.soft,
    required this.inverse,
    required this.onInverse,
    required this.hairline,
    required this.scrim,
    required this.doodle,
    required this.doodleAccent,
    required this.pen,
    required this.highlight,
    this.doodlesEnabled = true,
  });

  /// Scaffold, editor paper.
  final Color bg;

  /// Outlined cards, sheets, drawer, folder bodies.
  final Color surface;

  /// Primary text, icons, checkbox outlines.
  final Color ink;

  /// Secondary text, counts, timestamps, placeholders.
  final Color muted;

  /// 1.5px borders on cards, chips, circle buttons.
  final Color outline;

  /// Progress tracks, placeholder stripes, pressed fill.
  final Color soft;

  /// Dock, primary pill buttons, selected chip, active drawer row.
  final Color inverse;
  final Color onInverse;

  /// Row dividers inside grouped cards, done-item borders.
  final Color hairline;

  /// Behind drawer / sheets / dialogs.
  final Color scrim;

  /// Background marker swooshes, and the small squiggle.
  final Color doodle;
  final Color doodleAccent;

  /// Handwriting blue.
  final Color pen;

  /// The accent pastel (see [SketchAccent]).
  final Color highlight;

  /// Whether the doodle background paints. Off for high contrast, reduced
  /// motion, or when the user turns it off in Display.
  final bool doodlesEnabled;

  static const SketchColors light = SketchColors(
    bg: Color(0xFFF5F3EC),
    surface: Color(0xFFFFFDF8),
    ink: Color(0xFF141414),
    muted: Color(0xFF6A6861),
    outline: Color(0xFF141414),
    soft: Color(0xFFECE9E0),
    inverse: Color(0xFF141414),
    onInverse: Color(0xFFF5F3EC),
    hairline: Color(0xFFE2DED3),
    scrim: Color(0x61141414),
    doodle: Color(0xFFD8D4F8),
    doodleAccent: Color(0xFFF6E27A),
    pen: Color(0xFF2D45E0),
    highlight: SketchPastels.yellow,
  );

  static const SketchColors dark = SketchColors(
    bg: Color(0xFF131312),
    surface: Color(0xFF1D1D1B),
    ink: Color(0xFFF2F0E9),
    muted: Color(0xFFA3A098),
    outline: Color(0xFFE6E3DA),
    soft: Color(0xFF2A2926),
    inverse: Color(0xFFF2F0E9),
    onInverse: Color(0xFF131312),
    hairline: Color(0xFF2F2E2B),
    scrim: Color(0x99000000),
    doodle: Color(0xFF2D2A48),
    doodleAccent: Color(0xFF5C5428),
    pen: Color(0xFF7B8CFF),
    highlight: SketchPastels.yellow,
  );

  /// High-contrast variants: muted text and hairlines move toward ink.
  SketchColors highContrast(Brightness brightness) => copyWith(
        muted: brightness == Brightness.dark
            ? const Color(0xFFD6D3CB)
            : const Color(0xFF3F3D38),
        hairline: outline,
        doodlesEnabled: false,
      );

  bool get isDark => bg.computeLuminance() < 0.5;

  @override
  SketchColors copyWith({
    Color? bg,
    Color? surface,
    Color? ink,
    Color? muted,
    Color? outline,
    Color? soft,
    Color? inverse,
    Color? onInverse,
    Color? hairline,
    Color? scrim,
    Color? doodle,
    Color? doodleAccent,
    Color? pen,
    Color? highlight,
    bool? doodlesEnabled,
  }) {
    return SketchColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      outline: outline ?? this.outline,
      soft: soft ?? this.soft,
      inverse: inverse ?? this.inverse,
      onInverse: onInverse ?? this.onInverse,
      hairline: hairline ?? this.hairline,
      scrim: scrim ?? this.scrim,
      doodle: doodle ?? this.doodle,
      doodleAccent: doodleAccent ?? this.doodleAccent,
      pen: pen ?? this.pen,
      highlight: highlight ?? this.highlight,
      doodlesEnabled: doodlesEnabled ?? this.doodlesEnabled,
    );
  }

  @override
  SketchColors lerp(ThemeExtension<SketchColors>? other, double t) {
    if (other is! SketchColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return SketchColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      ink: l(ink, other.ink),
      muted: l(muted, other.muted),
      outline: l(outline, other.outline),
      soft: l(soft, other.soft),
      inverse: l(inverse, other.inverse),
      onInverse: l(onInverse, other.onInverse),
      hairline: l(hairline, other.hairline),
      scrim: l(scrim, other.scrim),
      doodle: l(doodle, other.doodle),
      doodleAccent: l(doodleAccent, other.doodleAccent),
      pen: l(pen, other.pen),
      highlight: l(highlight, other.highlight),
      doodlesEnabled: t < 0.5 ? doodlesEnabled : other.doodlesEnabled,
    );
  }
}

/// `context.sketch` — the current [SketchColors].
extension SketchContext on BuildContext {
  SketchColors get sketch =>
      Theme.of(this).extension<SketchColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? SketchColors.dark
          : SketchColors.light);
}

/// Note colours by name. The palette itself lives in [SketchColors] and
/// [SketchPastels]; this resolves the name stored in a note's encrypted
/// payload.
class PinpointColors {
  PinpointColors._();

  /// Resolve a note colour (by stable name) to its pastel.
  ///
  /// Pastels are the same in both themes — anything drawn on one uses
  /// [SketchPastels.onPastel] — so [brightness] does not change the result;
  /// it stays in the signature for the existing call sites.
  /// A null/unknown/"default" name returns null → caller uses its surface.
  static Color? noteColor(String? name, Brightness brightness) =>
      NoteSwatch.resolve(name)?.color;
}


/// A note colour swatch. Persisted by [name] only — inside the encrypted
/// payload — so it survives theme switches and encryption round-trips.
class NoteSwatch {
  final String name; // stable key stored in the encrypted payload
  final String label; // English fallback label (UI uses the ARB string)
  final Color? color; // null for the default (uncoloured) swatch

  const NoteSwatch({
    required this.name,
    required this.label,
    required this.color,
  });

  /// The default (no colour) option — renders as the theme's surface.
  static const NoteSwatch defaultSwatch =
      NoteSwatch(name: 'default', label: 'Default', color: null);

  /// The five Sketchbook pastels, in round-robin order.
  static const List<NoteSwatch> colored = [
    NoteSwatch(name: 'yellow', label: 'Yellow', color: SketchPastels.yellow),
    NoteSwatch(
        name: 'lavender', label: 'Lavender', color: SketchPastels.lavender),
    NoteSwatch(name: 'mint', label: 'Mint', color: SketchPastels.mint),
    NoteSwatch(name: 'sky', label: 'Sky', color: SketchPastels.sky),
    NoteSwatch(name: 'pink', label: 'Pink', color: SketchPastels.pink),
  ];

  /// Default + all coloured swatches (for the colour-picker UI).
  static const List<NoteSwatch> all = [defaultSwatch, ...colored];

  /// The eleven Keep-era colour names, mapped to the nearest pastel.
  ///
  /// Stored payloads are never rewritten: a note keeps its old name until the
  /// user picks a new colour, so this lookup is the only migration. `chalk`
  /// was a near-white grey and reads best as the plain surface.
  static const Map<String, String?> legacyNames = {
    'coral': 'pink',
    'peach': 'yellow',
    'sand': 'yellow',
    'sage': 'mint',
    'fog': 'sky',
    'storm': 'sky',
    'dusk': 'lavender',
    'blossom': 'pink',
    'clay': 'yellow',
    'chalk': null,
  };

  static NoteSwatch? byName(String name) {
    for (final s in all) {
      if (s.name == name) return s;
    }
    return null;
  }

  /// [byName] that also understands the legacy Keep names. Returns null for
  /// "no colour".
  static NoteSwatch? resolve(String? name) {
    if (name == null || name.isEmpty || name == 'default') return null;
    final direct = byName(name);
    if (direct != null) return direct;
    if (!legacyNames.containsKey(name)) return null;
    final mapped = legacyNames[name];
    return mapped == null ? null : byName(mapped);
  }

  /// The swatch the picker should show as selected for a stored [name].
  static NoteSwatch selectedFor(String? name) => resolve(name) ?? defaultSwatch;
}
