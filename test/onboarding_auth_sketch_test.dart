import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as material_ui;
import 'package:pinpoint/components/onboarding/whats_new_sheet.dart';
import 'package:pinpoint/constants/shared_preference_keys.dart';
import 'package:pinpoint/design_system/design_system.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/screens/onboarding_screen.dart';
import 'package:pinpoint/screens/splash_screen.dart';
import 'package:pinpoint/screens/unlock_screen.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';
import 'package:pinpoint/services/locale_controller.dart';
import 'package:pinpoint/services/onboarding_version.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/analytics_recorder.dart';
import 'support/sketch_harness.dart';

/// Splash, onboarding (incl. the versioned What's-new sheet) and unlock in
/// the Sketchbook system. Regenerate goldens with
/// `flutter test --update-goldens test/onboarding_auth_sketch_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnboardingVersion.decide', () {
    test('a new install gets the full onboarding', () {
      expect(
        OnboardingVersion.decide(
            hasCompletedOnboarding: false, seenVersion: null),
        OnboardingAction.fullOnboarding,
      );
      // Even a stray version number does not skip onboarding.
      expect(
        OnboardingVersion.decide(
            hasCompletedOnboarding: false,
            seenVersion: OnboardingVersion.current),
        OnboardingAction.fullOnboarding,
      );
    });

    test('someone who finished the old onboarding gets What\'s new', () {
      expect(
        OnboardingVersion.decide(
            hasCompletedOnboarding: true, seenVersion: null),
        OnboardingAction.whatsNew,
      );
      expect(
        OnboardingVersion.decide(hasCompletedOnboarding: true, seenVersion: 1),
        OnboardingAction.whatsNew,
      );
    });

    test('an up-to-date install gets nothing', () {
      expect(
        OnboardingVersion.decide(
            hasCompletedOnboarding: true,
            seenVersion: OnboardingVersion.current),
        OnboardingAction.none,
      );
      expect(
        OnboardingVersion.decide(
            hasCompletedOnboarding: true,
            seenVersion: OnboardingVersion.current + 1),
        OnboardingAction.none,
      );
    });

    test('the current version is the shared constant, stored as an int',
        () async {
      expect(OnboardingVersion.current, kCurrentOnboardingVersion);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await OnboardingVersion.markSeen(prefs);
      expect(prefs.getInt(kOnboardingVersionKey), kCurrentOnboardingVersion);
    });
  });

  group('What\'s new sheet', () {
    late BuildContext hostContext;

    Widget host() => _app(Builder(builder: (context) {
          hostContext = context;
          return const Scaffold(body: SizedBox.expand());
        }));

    testWidgets('shows once for an upgrading user, then never again',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {kHasCompletedOnboardingKey: true});
      await tester.pumpWidget(host());

      late bool shown;
      WhatsNewSheet.showIfNeeded(hostContext).then((v) => shown = v);
      await tester.pumpAndSettle();

      expect(find.text('Fresh new look'), findsOneWidget);
      expect(find.text("Dark mode that's actually dark"), findsOneWidget);
      expect(find.text('Color your folders'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(kOnboardingVersionKey), kCurrentOnboardingVersion);

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(shown, isTrue);
      expect(find.text('Fresh new look'), findsNothing);

      late bool again;
      WhatsNewSheet.showIfNeeded(hostContext).then((v) => again = v);
      await tester.pumpAndSettle();
      expect(again, isFalse);
      expect(find.text('Fresh new look'), findsNothing);
    });

    testWidgets('never shows for a brand-new install', (tester) async {
      // A new user finishing onboarding records the current version, so the
      // shell's What's-new check comes up empty and only the walkthrough runs.
      SharedPreferences.setMockInitialValues({
        kHasCompletedOnboardingKey: true,
        kOnboardingVersionKey: kCurrentOnboardingVersion,
      });
      await tester.pumpWidget(host());

      late bool shown;
      WhatsNewSheet.showIfNeeded(hostContext).then((v) => shown = v);
      await tester.pumpAndSettle();
      expect(shown, isFalse);
      expect(find.text('Fresh new look'), findsNothing);
    });
  });

  group('onboarding', () {
    setUp(() {
      if (getIt.isRegistered<AnalyticsFacade>()) {
        getIt.unregister<AnalyticsFacade>();
      }
      getIt.registerSingleton<AnalyticsFacade>(RecordingAnalyticsFacade());
    });
    tearDown(() => getIt.unregister<AnalyticsFacade>());

    testWidgets('three pages: Skip/Next, then Log in/Get started',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const OnboardingScreen()));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Write it down. Your way.'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.bySemanticsLabel('Page 1 of 3'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Organized, without the effort.'),
          findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Private by default.'), findsOneWidget);
      // The privacy page states the limits of end-to-end encryption.
      expect(
          find.text("Reminder text isn't end-to-end encrypted, and neither "
              'are voice recordings synced before June 2026.'),
          findsOneWidget);
      expect(find.text('Log in'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      expect(find.bySemanticsLabel('Page 3 of 3'), findsOneWidget);
    });
  });

  group('unlock', () {
    setUp(() => EditableText.debugDeterministicCursor = true);
    tearDown(() => EditableText.debugDeterministicCursor = false);

    testWidgets('a wrong passphrase shakes the field and shows the pill',
        (tester) async {
      _phone(tester);
      final attempts = <(String, bool)>[];
      await tester.pumpWidget(_app(UnlockScreen(
        unlockAttempt: (v, recovery) async {
          attempts.add((v, recovery));
          return false;
        },
      )));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'wrong horse');
      await tester.tap(find.text('Unlock'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(attempts, [('wrong horse', false)]);
      expect(find.byType(SketchErrorPill), findsOneWidget);
      expect(
          find.text(
              'Incorrect passphrase. Try again, or use your recovery code.'),
          findsOneWidget);
      // Mid-shake the field is displaced sideways.
      expect(_shakeOffset(tester), isNot(0));

      await tester.pumpAndSettle();
      expect(_shakeOffset(tester), closeTo(0, 0.01));
    });

    testWidgets('no shake under reduced motion', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(
        UnlockScreen(unlockAttempt: (_, __) async => false),
        disableAnimations: true,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'nope');
      await tester.tap(find.text('Unlock'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SketchErrorPill), findsOneWidget);
      expect(_shakeOffset(tester), 0);
    });

    testWidgets('switches to the recovery code', (tester) async {
      _phone(tester);
      final attempts = <(String, bool)>[];
      await tester.pumpWidget(_app(UnlockScreen(
        unlockAttempt: (v, recovery) async {
          attempts.add((v, recovery));
          return false;
        },
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Use recovery code'));
      await tester.pumpAndSettle();
      expect(find.text('Enter recovery code'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ABCD-EFGH');
      await tester.tap(find.text('Recover'));
      await tester.pumpAndSettle();
      expect(attempts, [('ABCD-EFGH', true)]);
      expect(find.text('Use passphrase instead'), findsOneWidget);
    });
  });

  group('goldens', () {
    setUpAll(loadSketchFonts);
    setUp(() {
      EditableText.debugDeterministicCursor = true;
      if (getIt.isRegistered<AnalyticsFacade>()) {
        getIt.unregister<AnalyticsFacade>();
      }
      getIt.registerSingleton<AnalyticsFacade>(RecordingAnalyticsFacade());
    });
    tearDown(() {
      EditableText.debugDeterministicCursor = false;
      getIt.unregister<AnalyticsFacade>();
    });

    Future<void> golden(WidgetTester tester, String name, Widget screen) async {
      _phone(tester);
      for (final b in Brightness.values) {
        await tester.pumpWidget(_app(screen, brightness: b));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/${name}_${b.name}.png'),
        );
      }
    }

    testWidgets('splash (settled frame)', (tester) async {
      await golden(tester, 'splash', const SplashView());
    });

    testWidgets('splash with the late caption', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const SplashView(showLateCaption: true)));
      await tester.pumpAndSettle();
      expect(find.text('Unlocking your notes…'), findsOneWidget);
    });

    testWidgets('onboarding page 1', (tester) async {
      await golden(tester, 'onboarding_page1', const OnboardingScreen());
    });

    testWidgets('unlock', (tester) async {
      await golden(
        tester,
        'unlock',
        UnlockScreen(unlockAttempt: (_, __) async => false),
      );
    });
  });
}

double _shakeOffset(WidgetTester tester) {
  final transform = tester.widget<Transform>(find
      .ancestor(
          of: find.byType(SketchTextField), matching: find.byType(Transform))
      .first);
  return transform.transform.getTranslation().x;
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// A full-screen Sketchbook app around [home].
Widget _app(
  Widget home, {
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: PinpointTheme.light(),
    darkTheme: PinpointTheme.dark(),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    locale: const Locale('en'),
    supportedLocales: LocaleController.supportedLocales,
    localizationsDelegates: const [
      AppL10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      ...material_ui.GlobalMaterialLocalizations.delegates,
    ],
    builder: disableAnimations
        ? (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            )
        : null,
    home: home,
  );
}
