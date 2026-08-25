import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as material_ui;

import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/services/locale_controller.dart';

/// Guards the delegate set in `main.dart`.
///
/// Flutter has split Material out of the framework into `package:material_ui`,
/// which declares its **own** `MaterialLocalizations` type. Packages that have
/// migrated — fleather 1.28, go_router 18 — resolve that type, and the
/// `flutter_localizations` delegates cannot satisfy it: they implement the type
/// from `package:flutter/material.dart`.
///
/// When it is missing, the symptom is remote from the cause: long-pressing text
/// in the note editor throws "No MaterialLocalizations found" from deep inside
/// fleather, with nothing pointing at the app's delegate list. These tests fail
/// loudly instead, in every locale the app ships.
void main() {
  // The exact list main.dart installs on MaterialApp.
  const delegates = <LocalizationsDelegate<dynamic>>[
    AppL10n.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    ...material_ui.GlobalMaterialLocalizations.delegates,
  ];

  Future<void> pumpWithLocale(WidgetTester tester, Locale locale) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: delegates,
        supportedLocales: LocaleController.supportedLocales,
        home: const _Probe(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('material_ui MaterialLocalizations resolves', (tester) async {
    await pumpWithLocale(tester, const Locale('en'));

    final context = tester.element(find.byType(_Probe));
    final resolved = Localizations.of<material_ui.MaterialLocalizations>(
      context,
      material_ui.MaterialLocalizations,
    );

    expect(
      resolved,
      isNotNull,
      reason: 'Widgets from package:material_ui (fleather 1.28, go_router 18) '
          'cannot build without this. Check that main.dart still spreads '
          'material_ui.GlobalMaterialLocalizations.delegates.',
    );
  });

  testWidgets('the framework MaterialLocalizations still resolves',
      (tester) async {
    // Adding the material_ui delegates must not displace the originals — the
    // app itself is still written against package:flutter/material.dart.
    await pumpWithLocale(tester, const Locale('en'));

    final context = tester.element(find.byType(_Probe));
    expect(MaterialLocalizations.of(context), isNotNull);
  });

  testWidgets('both resolve in every shipped locale', (tester) async {
    for (final locale in LocaleController.supportedLocales) {
      await pumpWithLocale(tester, locale);
      final context = tester.element(find.byType(_Probe));

      expect(
        Localizations.of<material_ui.MaterialLocalizations>(
          context,
          material_ui.MaterialLocalizations,
        ),
        isNotNull,
        reason: 'material_ui localizations missing for ${locale.languageCode}',
      );
      expect(
        MaterialLocalizations.of(context),
        isNotNull,
        reason: 'framework localizations missing for ${locale.languageCode}',
      );
    }
  });

  testWidgets('a material_ui widget can actually build', (tester) async {
    // The end-to-end check: material_ui's own widgets run the same
    // debugCheckHasMaterialLocalizations assertion that fleather's selection
    // toolbar tripped on.
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: delegates,
        supportedLocales: LocaleController.supportedLocales,
        home: Builder(
          builder: (context) => material_ui.Scaffold(
            body: material_ui.TextField(
              controller: TextEditingController(text: 'select me'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('without the material_ui delegates the lookup is null',
      (tester) async {
    // Pins *why* the spread in main.dart exists. If a future Flutter release
    // makes flutter_localizations satisfy material_ui's type too, this test
    // starts failing — at which point the extra delegates are redundant and
    // this file should be revisited, rather than the spread being cargo-culted
    // forward forever.
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          // material_ui delegates deliberately omitted.
        ],
        supportedLocales: LocaleController.supportedLocales,
        home: _Probe(),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(_Probe));
    expect(
      Localizations.of<material_ui.MaterialLocalizations>(
        context,
        material_ui.MaterialLocalizations,
      ),
      isNull,
      reason: 'flutter_localizations is not expected to satisfy '
          "material_ui's MaterialLocalizations type.",
    );
  });
}

class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
