import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/main.dart';
import 'package:pinpoint/services/locale_controller.dart';

/// Regression tests for the two startup error screens.
///
/// Both crashed in production with "Null check operator used on a null value"
/// out of `AppL10n.of`. Each builds its own `MaterialApp` and then passed a
/// `home:` subtree built with `build`'s own context — which sits *above* the
/// `Localizations` that `MaterialApp` installs, so the lookup returned null and
/// `AppL10n.of`'s `!` threw. They are error paths, so nothing else exercises
/// them; pumping each one directly is what keeps the bug from coming back.
///
/// These assert only that the screen renders and shows translated text. They
/// deliberately do not touch the retry buttons: `_retryAuthentication` calls
/// `runApp` and the init screen's retry calls `main()`, neither of which a
/// widget test can meaningfully drive.
void main() {
  testWidgets('AuthenticationFailedApp builds without a Localizations error',
      (tester) async {
    await tester.pumpWidget(const AuthenticationFailedApp());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Authentication Failed'), findsOneWidget);
    expect(find.text('Please restart the app and try again'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
  });

  testWidgets('InitializationErrorApp builds and shows the underlying error',
      (tester) async {
    await tester.pumpWidget(
      const InitializationErrorApp(error: 'Failed to open database'),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('App Initialization Failed'), findsOneWidget);
    // The label is localized; the exception text is passed through verbatim.
    expect(find.text('Error: Failed to open database'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('startup error screens localize with the device locale',
      (tester) async {
    // Spanish rather than English proves the strings really are coming from
    // the delegate rather than from a hardcoded literal that happens to match.
    //
    // `localesTestValue`, not `localeTestValue`: MaterialApp resolves against
    // the full preferred-locales list, and setting only the singular leaves
    // that list at its default so the app still comes up English.
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const AuthenticationFailedApp());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Error de autenticación'), findsOneWidget);
  });

  test('every supported locale resolves the startup error strings', () async {
    // `AppL10n.of` is only as safe as the delegate's coverage: a locale that
    // loads but is missing these keys would crash the same screens again.
    for (final locale in LocaleController.supportedLocales) {
      final l10n = await AppL10n.delegate.load(locale);
      expect(l10n.startupAuthFailed, isNotEmpty,
          reason: 'startupAuthFailed missing for ${locale.languageCode}');
      expect(l10n.startupInitFailed, isNotEmpty,
          reason: 'startupInitFailed missing for ${locale.languageCode}');
      expect(l10n.startupErrorDetail('boom'), contains('boom'),
          reason: 'startupErrorDetail dropped its placeholder for '
              '${locale.languageCode}');
    }
  });
}
