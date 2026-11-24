import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pinpoint/constants/shared_preference_keys.dart';
import 'package:pinpoint/design_system/design_system.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/screens/auth_screen.dart';
import 'package:pinpoint/screens/home_screen.dart';
import 'package:pinpoint/screens/onboarding_screen.dart';
import 'package:pinpoint/screens/splash_screen.dart';
import 'package:pinpoint/screens/terms_acceptance_screen.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/analytics/analytics_client.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';
import 'package:pinpoint/services/analytics/first_note_event.dart';
import 'package:pinpoint/services/encryption_service.dart';
import 'package:pinpoint/services/first_run.dart';
import 'package:pinpoint/services/guest_mode.dart';
import 'package:pinpoint/services/locale_controller.dart';
import 'package:pinpoint/services/onboarding_version.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/analytics_recorder.dart';

/// The write-first first run: the onboarding page's consent line replaces the
/// terms checkbox screen, "Get started" goes straight to a blank note as a
/// guest, "Log in" straight to the sign-in screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordingAnalyticsFacade analytics;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    dotenv.loadFromString(envString: '''
API_BASE_URL_DEV=http://localhost
API_BASE_URL_PROD=http://localhost
''');
    await GuestMode.end();
    analytics = RecordingAnalyticsFacade();
    if (getIt.isRegistered<AnalyticsFacade>()) {
      getIt.unregister<AnalyticsFacade>();
    }
    getIt.registerSingleton<AnalyticsFacade>(analytics);
  });

  tearDown(() async {
    getIt.unregister<AnalyticsFacade>();
    await GuestMode.end();
  });

  group('splash routing', () {
    Future<bool> needs(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      return FirstRun.needsOnboarding(await SharedPreferences.getInstance());
    }

    test('a new install goes to onboarding', () async {
      expect(await needs({}), isTrue);
    });

    test('onboarded but never agreed to the terms: back to onboarding, '
        'not the old checkbox screen', () async {
      expect(await needs({kHasCompletedOnboardingKey: true}), isTrue);
    });

    test('someone who already agreed is untouched', () async {
      expect(
          await needs({
            kHasCompletedOnboardingKey: true,
            kHasAcceptedTermsKey: true,
          }),
          isFalse);
    });
  });

  group('FirstRun', () {
    test('acceptTerms writes the same prefs as the old screen, inline',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final before = DateTime.now();
      await FirstRun.acceptTerms(prefs, analytics);

      expect(prefs.getBool(kHasAcceptedTermsKey), isTrue);
      final date = DateTime.parse(prefs.getString(kTermsAcceptedDateKey)!);
      expect(date.isBefore(before.subtract(const Duration(seconds: 1))),
          isFalse);
      expect(analytics.one('terms_accepted').params, {'method': 'inline'});
    });

    test('startAsGuest starts guest mode with a local key and its source',
        () async {
      await FirstRun.startAsGuest(analytics,
          source: FirstRun.guestFromOnboarding);

      expect(GuestMode.isGuest, isTrue);
      expect(SecureEncryptionService.isInitialized, isTrue);
      expect(await SecureEncryptionService.hasLocalKey(), isTrue);
      expect(analytics.one('guest_started').params, {'source': 'onboarding'});
    });

    test('startAsGuest keeps an existing key', () async {
      await FirstRun.startAsGuest(analytics,
          source: FirstRun.guestFromAuthScreen);
      final key = await SecureEncryptionService.exportDataKeyBytes();
      await FirstRun.startAsGuest(analytics,
          source: FirstRun.guestFromAuthScreen);
      expect(await SecureEncryptionService.exportDataKeyBytes(), key);
      expect(analytics.all('guest_started').map((e) => e.params['source']),
          ['auth_screen', 'auth_screen']);
    });
  });

  group('guest_converted', () {
    test('fires once, with method and entry, for a guest', () {
      final conversion = GuestConversion(
          wasGuest: true, entry: AuthEntry.homeBanner);
      conversion.signedIn(analytics, method: 'google');
      conversion.signedIn(analytics, method: 'google');

      expect(analytics.one('guest_converted').params,
          {'method': 'google', 'entry': 'home_banner'});
    });

    test('never fires for someone who was not a guest', () {
      GuestConversion(wasGuest: false, entry: AuthEntry.paywall)
          .signedIn(analytics, method: 'email');
      expect(analytics.contains('guest_converted'), isFalse);
    });

    test('reads guest mode when created, before sign-in ends it', () async {
      await GuestMode.start();
      final conversion = GuestConversion.now(entry: AuthEntry.backupScreen);
      await GuestMode.end(); // what a successful sign-in does
      conversion.signedIn(analytics, method: 'apple');
      expect(analytics.one('guest_converted').params,
          {'method': 'apple', 'entry': 'backup_screen'});
    });

    test('an unknown entry is reported as other', () {
      expect(AuthEntry.parse(null), 'other');
      expect(AuthEntry.parse('some note title'), 'other');
      expect(AuthEntry.parse('paywall'), 'paywall');
      GuestConversion(wasGuest: true, entry: 'anything')
          .signedIn(analytics, method: 'email');
      expect(analytics.one('guest_converted').params['entry'], 'other');
    });

    test('every sign-in entry point names its entry on the route', () {
      expect(AuthScreen.locationFrom(AuthEntry.homeBanner),
          '/auth?from=home_banner');
    });
  });

  group('onboarding', () {
    late List<String> visited;
    late GoRouter appRouter;

    GoRouter router() {
      visited = [];
      GoRoute stub(String path) => GoRoute(
            path: path,
            builder: (_, state) {
              visited.add(state.uri.toString());
              return Scaffold(body: Text('at ${state.uri}'));
            },
          );
      return appRouter = GoRouter(
        initialLocation: OnboardingScreen.kRouteName,
        routes: [
          GoRoute(
            path: OnboardingScreen.kRouteName,
            builder: (_, __) => const OnboardingScreen(),
          ),
          stub(HomeScreen.kRouteName),
          stub(AuthScreen.kRouteName),
          stub(SplashScreen.kRouteName),
          stub(TermsAcceptanceScreen.kRouteName),
        ],
      );
    }

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp.router(
        theme: PinpointTheme.light(),
        locale: const Locale('en'),
        supportedLocales: LocaleController.supportedLocales,
        localizationsDelegates: const [
          AppL10n.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        routerConfig: router(),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
      await tester.runAsync(() async {
        await tester.tap(finder);
        // The flow awaits prefs, secure storage and auth initialisation.
        for (var i = 0; i < 20 && visited.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
    }

    testWidgets('shows the consent line under both buttons', (tester) async {
      await pump(tester);
      expect(
          find.textContaining(
              'By continuing you agree to the Terms and Privacy Policy',
              findRichText: true),
          findsOneWidget);
      final line = tester.getTopLeft(find.byType(ConsentLine)).dy;
      expect(line, greaterThan(tester.getBottomLeft(find.text('Log in')).dy));
      expect(line,
          greaterThan(tester.getBottomLeft(find.text('Get started')).dy));
    });

    testWidgets(
        'Get started: agrees, starts guest mode and goes home with a blank '
        'note armed', (tester) async {
      await pump(tester);
      await tapAndSettle(tester, find.text('Get started'));

      expect(visited, [HomeScreen.kRouteName]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kHasCompletedOnboardingKey), isTrue);
      expect(prefs.getBool(kHasAcceptedTermsKey), isTrue);
      expect(prefs.getString(kTermsAcceptedDateKey), isNotNull);
      expect(prefs.getInt(kOnboardingVersionKey), OnboardingVersion.current);
      expect(prefs.getBool(FirstNoteEvent.blankNoteKey), isTrue);
      expect(prefs.getBool(FirstNoteEvent.pendingKey), isTrue);
      expect(GuestMode.isGuest, isTrue);

      expect(analytics.names, [
        'onboarding_choice',
        'onboarding_complete',
        'user_property',
        'terms_accepted',
        'guest_started',
      ]);
      expect(analytics.one('onboarding_choice').params,
          {'choice': 'get_started'});
      expect(analytics.one('user_property').params,
          {'first_run_flow': 'write_first'});
      expect(analytics.one('terms_accepted').params, {'method': 'inline'});
      expect(analytics.one('guest_started').params, {'source': 'onboarding'});
    });

    testWidgets('Log in: agrees and goes straight to sign-in, not as a guest',
        (tester) async {
      await pump(tester);
      await tapAndSettle(tester, find.text('Log in'));

      expect(visited, ['/auth?from=onboarding_log_in']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kHasAcceptedTermsKey), isTrue);
      expect(prefs.getString(kTermsAcceptedDateKey), isNotNull);
      expect(GuestMode.isGuest, isFalse);
      expect(analytics.one('onboarding_choice').params, {'choice': 'log_in'});
      expect(analytics.one('terms_accepted').params, {'method': 'inline'});
      expect(analytics.contains('guest_started'), isFalse);
    });

    testWidgets('someone sent back to agree is not counted as onboarding twice',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {kHasCompletedOnboardingKey: true});
      await pump(tester);
      await tapAndSettle(tester, find.text('Get started'));

      expect(visited, [HomeScreen.kRouteName]);
      expect(analytics.contains('onboarding_complete'), isFalse);
      expect(analytics.contains('terms_accepted'), isTrue);
    });

    testWidgets('Terms opens the reader; Privacy Policy opens its tab',
        (tester) async {
      await pump(tester);
      await tester.tapOnText(find.textRange.ofSubstring('Terms'));
      await tester.pumpAndSettle();
      expect(visited, [TermsAcceptanceScreen.kRouteName]);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kHasAcceptedTermsKey), isNull,
          reason: 'reading the terms is not agreeing to them');

      appRouter.pop();
      await tester.pumpAndSettle();
      await tester.tapOnText(find.textRange.ofSubstring('Privacy Policy'));
      await tester.pumpAndSettle();
      expect(visited.last, TermsAcceptanceScreen.privacyLocation);
    });
  });

  group('terms reader', () {
    testWidgets('is view-only and opens on the requested document',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: PinpointTheme.light(),
        locale: const Locale('en'),
        supportedLocales: LocaleController.supportedLocales,
        localizationsDelegates: const [
          AppL10n.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: const TermsAcceptanceScreen(openPrivacy: true),
      ));
      await tester.pumpAndSettle();

      final control = tester.widget<SketchSegmentedControl<Object?>>(
          find.byWidgetPredicate((w) => w is SketchSegmentedControl));
      expect(control.selected.toString(), contains('privacy'));
      expect(find.byType(SketchCheckbox), findsNothing);
    });
  });
}
