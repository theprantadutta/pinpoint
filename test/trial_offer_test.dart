import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as material_ui;

import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/services/locale_controller.dart';

/// Guards the free-trial copy on the paywall.
///
/// The trial is a Google Play base-plan *offer*: 3 days on monthly, 7 on
/// yearly at the time of writing. It can be changed or withdrawn in the
/// Console with no app release, and Play withholds it from anyone who has
/// already used one. So the length must be read from the live offer and
/// rendered through a plural — never hardcoded, and never assembled with
/// string concatenation, which breaks in Arabic, Persian and Bengali.
void main() {
  const delegates = <LocalizationsDelegate<dynamic>>[
    AppL10n.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    ...material_ui.GlobalMaterialLocalizations.delegates,
  ];

  Future<AppL10n> l10nFor(WidgetTester tester, Locale locale) async {
    late AppL10n l10n;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: delegates,
        supportedLocales: LocaleController.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppL10n.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return l10n;
  }

  testWidgets('English renders both trial lengths we actually offer',
      (tester) async {
    final l10n = await l10nFor(tester, const Locale('en'));

    expect(l10n.subTrialCta(3), 'Start 3-day free trial');
    expect(l10n.subTrialCta(7), 'Start 7-day free trial');
    expect(l10n.subTrialThenPrice(3, '\$4.99'), '3 days free, then \$4.99');
    expect(l10n.subTrialThenPrice(7, '\$39.99'), '7 days free, then \$39.99');
  });

  testWidgets('the singular branch is wired', (tester) async {
    final l10n = await l10nFor(tester, const Locale('en'));

    expect(l10n.subTrialCta(1), 'Start 1-day free trial');
    expect(l10n.subTrialThenPrice(1, '\$4.99'), '1 day free, then \$4.99');
  });

  testWidgets('every supported locale resolves trial copy for any length',
      (tester) async {
    for (final locale in LocaleController.supportedLocales) {
      final l10n = await l10nFor(tester, locale);

      for (final days in const [1, 3, 7, 14, 30]) {
        final cta = l10n.subTrialCta(days);
        final then = l10n.subTrialThenPrice(days, 'PRICE');

        expect(cta.trim(), isNotEmpty,
            reason: 'subTrialCta($days) is empty in ${locale.languageCode}');
        expect(then.trim(), isNotEmpty,
            reason:
                'subTrialThenPrice($days) is empty in ${locale.languageCode}');
        expect(
          then,
          contains('PRICE'),
          reason: 'The store-formatted price must survive into '
              '${locale.languageCode}; it is inserted, never rebuilt.',
        );
        // A plural that fell through to a literal placeholder is a broken ARB.
        expect(cta, isNot(contains('{days}')),
            reason: 'Unsubstituted placeholder in ${locale.languageCode}');
        expect(then, isNot(contains('{days}')),
            reason: 'Unsubstituted placeholder in ${locale.languageCode}');
      }
    }
  });

  testWidgets('the trial length is not baked into the copy', (tester) async {
    // If someone "simplifies" these into fixed strings, the paywall starts
    // promising a trial length the Play Console may no longer offer.
    final l10n = await l10nFor(tester, const Locale('en'));

    expect(l10n.subTrialCta(3), isNot(l10n.subTrialCta(7)));
    expect(
      l10n.subTrialThenPrice(3, 'X'),
      isNot(l10n.subTrialThenPrice(7, 'X')),
    );
  });
}
