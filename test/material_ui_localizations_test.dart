import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
// Only to look up the legacy localizations type that packages still on
// package:flutter/material.dart resolve.
// ignore: deprecated_member_use
import 'package:flutter/material.dart' as legacy show MaterialLocalizations;

import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/services/locale_controller.dart';

/// Guards the localization setup in `main.dart` after the move to
/// `package:material_ui` (Flutter 3.50).
///
/// `material_ui` declares its **own** `MaterialLocalizations` type. The app and
/// the migrated packages (fleather, go_router) resolve that one, from
/// `GlobalMaterialLocalizations.delegates`. Packages still on
/// `package:flutter/material.dart` (toastification, tutorial_coach_mark, …)
/// resolve the legacy type, which `MaterialUiCompatibilityBridge` provides.
///
/// When either is missing, the symptom is remote from the cause: long-pressing
/// text in the note editor once threw "No MaterialLocalizations found" from
/// deep inside fleather. These tests fail loudly instead, in every locale.
void main() {
  // The exact list main.dart installs on MaterialApp.
  const delegates = <LocalizationsDelegate<dynamic>>[
    AppL10n.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ];

  Future<void> pumpWithLocale(WidgetTester tester, Locale locale) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: delegates,
        supportedLocales: LocaleController.supportedLocales,
        // As main.dart's builder does.
        // ignore: deprecated_member_use
        builder: (context, child) => MaterialUiCompatibilityBridge(child: child!),
        home: const _Probe(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('both localization types resolve in every shipped locale',
      (tester) async {
    for (final locale in LocaleController.supportedLocales) {
      await pumpWithLocale(tester, locale);
      final context = tester.element(find.byType(_Probe));

      expect(
        Localizations.of<MaterialLocalizations>(context, MaterialLocalizations),
        isNotNull,
        reason: 'material_ui localizations missing for ${locale.languageCode}',
      );
      expect(
        Localizations.of<legacy.MaterialLocalizations>(
            context, legacy.MaterialLocalizations),
        isNotNull,
        reason: 'legacy localizations (for packages not yet on material_ui) '
            'missing for ${locale.languageCode}: is the bridge still in '
            "main.dart's builder?",
      );
      expect(AppL10n.of(context), isNotNull);
    }
  });

  testWidgets('a text field can build and select', (tester) async {
    // The end-to-end check: the same debugCheckHasMaterialLocalizations
    // assertion fleather's selection toolbar once tripped on.
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: delegates,
        supportedLocales: LocaleController.supportedLocales,
        home: Scaffold(
          body: TextField(
            controller: TextEditingController(text: 'select me'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
