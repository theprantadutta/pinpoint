import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinpoint/constants/premium_limits.dart';
import 'package:pinpoint/design_system/design_system.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('SketchAccent', () {
    test('stored legacy accent hexes round-trip', () {
      for (final a in SketchAccent.values) {
        expect(SketchAccent.fromStored(a.legacyColor.toARGB32()), a);
      }
    });

    test('the old indigo default and missing values fall back to amber', () {
      expect(SketchAccent.fromStored(0xFF6C8FF5), SketchAccent.amber);
      expect(SketchAccent.fromStored(null), SketchAccent.amber);
    });

    test('the default accent is free, so a free user can always return to it',
        () {
      expect(PremiumLimits.freeThemeColors,
          contains(SketchAccent.fallback.premiumName));
      expect(PremiumLimits.freeThemeColors.length,
          PremiumLimits.maxThemeColorsForFree);
    });

    test('every premium name the gate checks is a real accent', () {
      final names = SketchAccent.values.map((a) => a.premiumName).toSet();
      expect(names.containsAll(PremiumLimits.freeThemeColors), isTrue);
      expect(SketchAccent.values.length, PremiumLimits.totalThemeColors);
    });
  });

  group('NoteSwatch', () {
    test('offers the default plus five pastels', () {
      expect(NoteSwatch.all.map((s) => s.name),
          ['default', 'yellow', 'lavender', 'mint', 'sky', 'pink']);
    });

    test('every Keep-era colour name still resolves (no payload rewrite)', () {
      const keep = [
        'coral', 'peach', 'sand', 'mint', 'sage', 'fog', //
        'storm', 'dusk', 'blossom', 'clay',
      ];
      for (final name in keep) {
        expect(NoteSwatch.resolve(name), isNotNull, reason: name);
      }
      // Chalk was near-white: it reads as the plain surface.
      expect(NoteSwatch.resolve('chalk'), isNull);
      expect(PinpointColors.noteColor('dusk', Brightness.dark),
          SketchPastels.lavender);
    });

    test('pastels are identical in both themes', () {
      expect(PinpointColors.noteColor('yellow', Brightness.light),
          PinpointColors.noteColor('yellow', Brightness.dark));
    });

    test('unknown and default names mean "no colour"', () {
      expect(NoteSwatch.resolve(null), isNull);
      expect(NoteSwatch.resolve('default'), isNull);
      expect(NoteSwatch.resolve('not-a-colour'), isNull);
      expect(NoteSwatch.selectedFor('not-a-colour'), NoteSwatch.defaultSwatch);
    });
  });

  group('contrast', () {
    for (final entry in {
      'light': SketchColors.light,
      'dark': SketchColors.dark,
    }.entries) {
      final c = entry.value;
      test('${entry.key}: text roles clear 4.5:1 on paper and surface', () {
        for (final bg in [c.bg, c.surface]) {
          expect(_contrast(c.ink, bg), greaterThanOrEqualTo(4.5));
          expect(_contrast(c.muted, bg), greaterThanOrEqualTo(4.5));
        }
        expect(_contrast(c.onInverse, c.inverse), greaterThanOrEqualTo(4.5));
      });
    }

    test('ink on every pastel clears 4.5:1', () {
      for (final p in SketchPastels.roundRobin) {
        expect(_contrast(SketchPastels.onPastel, p),
            greaterThanOrEqualTo(4.5));
      }
    });
  });

  group('PinpointTheme', () {
    test('registers the Sketchbook extensions in both themes', () {
      for (final t in [PinpointTheme.light(), PinpointTheme.dark()]) {
        expect(t.extension<SketchColors>(), isNotNull);
        expect(t.extension<SketchText>(), isNotNull);
      }
    });

    test('the accent only swaps the highlight pastel', () {
      final t = PinpointTheme.light(accent: SketchAccent.iris);
      final c = t.extension<SketchColors>()!;
      expect(c.highlight, SketchPastels.lavender);
      expect(c.bg, SketchColors.light.bg);
      expect(t.colorScheme.primary, SketchColors.light.inverse);
    });

    test('high contrast turns the doodles off', () {
      final c = PinpointTheme.dark(highContrast: true)
          .extension<SketchColors>()!;
      expect(c.doodlesEnabled, isFalse);
    });

    test('Plus Jakarta Sans is the default family', () {
      final t = PinpointTheme.light();
      expect(t.textTheme.bodyMedium!.fontFamily, contains('PlusJakartaSans'));
    });
  });
}
