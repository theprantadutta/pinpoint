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
  static const List<String> names = ['yellow', 'lavender', 'mint', 'sky', 'pink'];

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

/// Legacy palette.
///
/// Superseded by [SketchColors] / [SketchPastels]. The values below are
/// repointed at the Sketchbook paper and ink so screens that still read them
/// already sit on the new surfaces; delete a constant once nothing uses it.
class PinpointColors {
  // Private constructor to prevent instantiation
  PinpointColors._();

  // ============================================
  // Core Brand Colors
  // ============================================

  /// Deep ink surfaces for dark mode
  static const Color darkSurface1 = Color(0xFF131312);
  static const Color darkSurface2 = Color(0xFF1D1D1B);
  static const Color darkSurface3 = Color(0xFF2A2926);
  static const Color darkSurface4 = Color(0xFF34332F);

  /// Paper white surfaces for light mode
  static const Color lightSurface1 = Color(0xFFF5F3EC);
  static const Color lightSurface2 = Color(0xFFFFFDF8);
  static const Color lightSurface3 = Color(0xFFECE9E0);
  static const Color lightSurface4 = Color(0xFFE2DED3);

  // ============================================
  // Accent Colors
  // ============================================

  /// Mint - Primary accent
  static const Color mint = Color(0xFF10B981);
  static const Color mintLight = Color(0xFF34D399);
  static const Color mintDark = Color(0xFF059669);
  static const Color mintSubtle = Color(0x2010B981);

  /// Iris - Secondary accent
  static const Color iris = Color(0xFF6366F1);
  static const Color irisLight = Color(0xFF818CF8);
  static const Color irisDark = Color(0xFF4F46E5);
  static const Color irisSubtle = Color(0x206366F1);

  /// Rose - Destructive/Love accent
  static const Color rose = Color(0xFFF43F5E);
  static const Color roseLight = Color(0xFFFB7185);
  static const Color roseDark = Color(0xFFE11D48);
  static const Color roseSubtle = Color(0x20F43F5E);

  /// Amber - Warning/Favorite accent
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberLight = Color(0xFFFBBF24);
  static const Color amberDark = Color(0xFFD97706);
  static const Color amberSubtle = Color(0x20F59E0B);

  /// Ocean - Info accent
  static const Color ocean = Color(0xFF0EA5E9);
  static const Color oceanLight = Color(0xFF38BDF8);
  static const Color oceanDark = Color(0xFF0284C7);
  static const Color oceanSubtle = Color(0x200EA5E9);

  // ============================================
  // Aliases for backward compatibility
  // ============================================

  static const Color purple = iris;
  static const Color pink = rose;
  static const Color orange = amber;
  static const Color blue = ocean;

  // ============================================
  // Semantic Colors
  // ============================================

  static const Color success = mint;
  static const Color successLight = mintLight;
  static const Color successDark = mintDark;
  static const Color successBackground = Color(0x1010B981);

  static const Color error = rose;
  static const Color errorLight = roseLight;
  static const Color errorDark = roseDark;
  static const Color errorBackground = Color(0x10F43F5E);

  static const Color warning = amber;
  static const Color warningLight = amberLight;
  static const Color warningDark = amberDark;
  static const Color warningBackground = Color(0x10F59E0B);

  static const Color info = ocean;
  static const Color infoLight = oceanLight;
  static const Color infoDark = oceanDark;
  static const Color infoBackground = Color(0x100EA5E9);

  // ============================================
  // Text Colors
  // ============================================

  /// Dark mode text
  static const Color darkTextPrimary = Color(0xFFF2F0E9);
  static const Color darkTextSecondary = Color(0xFFA3A098);
  static const Color darkTextTertiary = Color(0xFF8A877F);
  static const Color darkTextDisabled = Color(0xFF4B5563);

  /// Light mode text
  static const Color lightTextPrimary = Color(0xFF141414);
  static const Color lightTextSecondary = Color(0xFF6A6861);
  static const Color lightTextTertiary = Color(0xFF8F8C84);
  static const Color lightTextDisabled = Color(0xFFD1D5DB);

  // ============================================
  // Glass Morphism Overlays
  // ============================================

  static const Color glassWhite = Color(0x0AFFFFFF);
  static const Color glassWhiteMedium = Color(0x14FFFFFF);
  static const Color glassWhiteStrong = Color(0x1FFFFFFF);

  static const Color glassBlack = Color(0x0A000000);
  static const Color glassBlackMedium = Color(0x14000000);
  static const Color glassBlackStrong = Color(0x1F000000);

  // ============================================
  // Border Colors
  // ============================================

  static const Color darkBorder = Color(0xFF2F2E2B);
  static const Color darkBorderSubtle = Color(0xFF2A2926);
  static const Color darkBorderBold =
      Color(0xFF4A5568); // Bold borders for brutalist style
  static const Color lightBorder = Color(0xFFE2DED3);
  static const Color lightBorderSubtle = Color(0xFFECE9E0);
  static const Color lightBorderBold =
      Color(0xFF9CA3AF); // Bold borders for brutalist style

  // ============================================
  // Shadow Colors
  // ============================================

  static const Color shadowColor = Color(0x1A000000);
  static const Color shadowColorStrong = Color(0x33000000);
  static const Color shadowColorLight = Color(0x0D000000);

  // ============================================
  // Brutalist/Bold Design Elements
  // ============================================

  /// Bold border widths for brutalist aesthetic
  static const double borderThin = 1.0;
  static const double borderMedium = 2.0;
  static const double borderThick = 3.0;
  static const double borderExtraThick = 4.0;

  /// High contrast overlays for emphasis
  static const Color highContrastLight = Color(0xFFFFFFFF);
  static const Color highContrastDark = Color(0xFF000000);

  // ============================================
  // "Keep, refined" — borderless flat design system
  // (matched light + dark pair; single shared accent)
  // ============================================

  /// Legacy "refined accent". Sketchbook has no single brand accent — primary
  /// actions are ink-on-paper — so this now resolves to ink. New code reads
  /// [SketchColors] instead.
  static const Color accentRefined = Color(0xFF141414);
  static const Color onAccentRefined = Color(0xFFFFFFFF);

  // --- Dark surfaces ---
  // Cool, subtly indigo-tinted neutrals (hue ~222, very low saturation) so
  // surfaces feel related to the indigo-blue accent instead of flat gray.
  static const Color keepDarkCanvas = Color(0xFF131312); // scaffold bg
  static const Color keepDarkCard = Color(0xFF1D1D1B); // note card / default note
  static const Color keepDarkBar = Color(0xFF1D1D1B); // top bar / drawer
  static const Color keepDarkPill = Color(0xFF2A2926); // search pill / chips
  static const Color keepDarkTextPrimary = Color(0xFFF2F0E9);
  static const Color keepDarkTextSecondary = Color(0xFFA3A098);
  static const Color keepDarkTextHint = Color(0xFF8A877F);
  static const Color keepDarkDivider = Color(0xFF2F2E2B);

  // --- Light surfaces ---
  // White cards on a faint cool canvas; borders/pills carry a light indigo
  // tint to harmonize with the accent.
  static const Color keepLightCanvas = Color(0xFFF5F3EC); // scaffold bg
  static const Color keepLightCard = Color(0xFFFFFDF8); // note card / default note
  static const Color keepLightCardBorder = Color(0xFFE2DED3); // hairline outline
  static const Color keepLightBar = Color(0xFFFFFDF8); // top bar / drawer
  static const Color keepLightPill = Color(0xFFECE9E0); // search pill / chips
  static const Color keepLightTextPrimary = Color(0xFF141414);
  static const Color keepLightTextSecondary = Color(0xFF6A6861);
  static const Color keepLightTextHint = Color(0xFF8F8C84);
  static const Color keepLightDivider = Color(0xFFE2DED3);

  /// Resolve a note colour (by stable name) to its pastel.
  ///
  /// Pastels are the same in both themes — anything drawn on one uses
  /// [SketchPastels.onPastel] — so [brightness] no longer changes the result;
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
    NoteSwatch(name: 'lavender', label: 'Lavender', color: SketchPastels.lavender),
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
  static NoteSwatch selectedFor(String? name) =>
      resolve(name) ?? defaultSwatch;
}

/// Material 3 Color Scheme Extensions
extension PinpointColorScheme on ColorScheme {
  /// Get accent color based on index
  Color getAccentColor(int index) {
    final accents = [
      PinpointColors.mint,
      PinpointColors.iris,
      PinpointColors.rose,
      PinpointColors.amber,
      PinpointColors.ocean,
    ];
    return accents[index % accents.length];
  }

  /// Get surface color based on elevation level
  Color getSurfaceColor(int level) {
    if (brightness == Brightness.dark) {
      switch (level) {
        case 1:
          return PinpointColors.darkSurface1;
        case 2:
          return PinpointColors.darkSurface2;
        case 3:
          return PinpointColors.darkSurface3;
        case 4:
          return PinpointColors.darkSurface4;
        default:
          return PinpointColors.darkSurface1;
      }
    } else {
      switch (level) {
        case 1:
          return PinpointColors.lightSurface1;
        case 2:
          return PinpointColors.lightSurface2;
        case 3:
          return PinpointColors.lightSurface3;
        case 4:
          return PinpointColors.lightSurface4;
        default:
          return PinpointColors.lightSurface1;
      }
    }
  }

  /// Get text color based on emphasis
  Color getTextColor(TextEmphasis emphasis) {
    if (brightness == Brightness.dark) {
      switch (emphasis) {
        case TextEmphasis.primary:
          return PinpointColors.darkTextPrimary;
        case TextEmphasis.secondary:
          return PinpointColors.darkTextSecondary;
        case TextEmphasis.tertiary:
          return PinpointColors.darkTextTertiary;
        case TextEmphasis.disabled:
          return PinpointColors.darkTextDisabled;
      }
    } else {
      switch (emphasis) {
        case TextEmphasis.primary:
          return PinpointColors.lightTextPrimary;
        case TextEmphasis.secondary:
          return PinpointColors.lightTextSecondary;
        case TextEmphasis.tertiary:
          return PinpointColors.lightTextTertiary;
        case TextEmphasis.disabled:
          return PinpointColors.lightTextDisabled;
      }
    }
  }

  /// Get glass overlay color
  Color getGlassOverlay({bool strong = false}) {
    if (brightness == Brightness.dark) {
      return strong
          ? PinpointColors.glassWhiteStrong
          : PinpointColors.glassWhite;
    } else {
      return strong
          ? PinpointColors.glassBlackStrong
          : PinpointColors.glassBlack;
    }
  }
}

/// Text emphasis levels
enum TextEmphasis {
  primary,
  secondary,
  tertiary,
  disabled,
}

/// Tag color palette
class TagColors {
  final Color background;
  final Color foreground;
  final Color border;

  const TagColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  static const List<TagColors> presets = [
    TagColors(
      background: PinpointColors.mintSubtle,
      foreground: PinpointColors.mint,
      border: PinpointColors.mint,
    ),
    TagColors(
      background: PinpointColors.irisSubtle,
      foreground: PinpointColors.iris,
      border: PinpointColors.iris,
    ),
    TagColors(
      background: PinpointColors.roseSubtle,
      foreground: PinpointColors.rose,
      border: PinpointColors.rose,
    ),
    TagColors(
      background: PinpointColors.amberSubtle,
      foreground: PinpointColors.amber,
      border: PinpointColors.amber,
    ),
    TagColors(
      background: PinpointColors.oceanSubtle,
      foreground: PinpointColors.ocean,
      border: PinpointColors.ocean,
    ),
  ];

  static TagColors getPreset(int index) {
    return presets[index % presets.length];
  }
}
