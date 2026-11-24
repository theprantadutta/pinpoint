import 'package:material_ui/material_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:pinpoint/services/analytics/first_note_event.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/onboarding/onboarding_heroes.dart';
import '../constants/shared_preference_keys.dart';
import '../design_system/design_system.dart';
import '../service_locators/init_service_locators.dart';
import '../services/analytics/analytics_facade.dart';
import '../services/onboarding_version.dart';
import '../services/analytics/analytics_client.dart';
import '../services/backend_auth_service.dart';
import '../services/first_run.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'splash_screen.dart';
import 'terms_acceptance_screen.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

/// First-run onboarding: one Sketchbook page. "Get started" opens a blank
/// note as a guest; "Log in" opens the sign-in screen. The consent line under
/// both buttons replaces the old terms checkbox screen. Kept to one page
/// because every screen before the first note loses people (see [FirstRun]).
///
/// Shown once per [OnboardingVersion]; people who finished an older
/// onboarding get the one-time What's-new sheet on the home screen instead.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const String kRouteName = '/onboarding';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _finishing = false;

  // Where the doodle band sits. It used to be computed from hard-coded guesses
  // about the layout (`(height - 300) / 2 - 110`), but the band scales with
  // screen width while those numbers assumed a phone, so on a tablet it slid
  // below the illustration and ran behind the copy. It is now measured from
  // where the hero actually landed.
  final _backgroundKey = GlobalKey();
  final _heroKey = GlobalKey();
  double? _bandTop;

  /// DoodlePainter draws a band 200 units tall on a 390-unit-wide canvas,
  /// scaled by screen width; its centre runs 10 units above the hero's, as in
  /// the mocks.
  void _measureBand(Duration _) {
    if (!mounted) return;
    final background =
        _backgroundKey.currentContext?.findRenderObject() as RenderBox?;
    final hero = _heroKey.currentContext?.findRenderObject() as RenderBox?;
    if (background == null ||
        hero == null ||
        !background.hasSize ||
        !hero.hasSize) {
      return;
    }
    final centre = hero
        .localToGlobal(hero.size.center(Offset.zero), ancestor: background)
        .dy;
    final scale = background.size.width / 390;
    final top = centre - 110 * scale;
    if (_bandTop == null || (top - _bandTop!).abs() > 0.5) {
      setState(() => _bandTop = top);
    }
  }

  /// Either button is the agreement to the Terms and Privacy Policy (the
  /// consent line sits under both). "Get started" goes straight to a blank
  /// note as a guest; "Log in" goes to the sign-in screen.
  Future<void> _finish({required bool logIn}) async {
    if (_finishing) return;
    _finishing = true;
    final analytics = getIt<AnalyticsFacade>();
    analytics.trackOnboardingChoice(
        choice: logIn ? FirstRun.choiceLogIn : FirstRun.choiceGetStarted);

    final preferences = await SharedPreferences.getInstance();
    // Someone sent back here because they never agreed to the terms has
    // already finished onboarding once; do not count them twice.
    final firstTime =
        !(preferences.getBool(kHasCompletedOnboardingKey) ?? false);
    await preferences.setBool(kHasCompletedOnboardingKey, true);
    // A new user has now seen this generation's onboarding, so the
    // What's-new sheet (meant for upgraders) never shows for them.
    await OnboardingVersion.markSeen(preferences);
    await FirstNoteEvent.arm(preferences);
    if (firstTime) analytics.trackOnboardingComplete();
    analytics.setFirstRunFlow(FirstRun.flowWriteFirst);
    await FirstRun.acceptTerms(preferences, analytics);

    if (!mounted) return;
    if (logIn) {
      context.go(AuthScreen.locationFrom(AuthEntry.onboardingLogIn));
      return;
    }

    // Already signed in (an older install that stopped at the terms screen
    // after signing in): the splash knows the way from here.
    final auth = BackendAuthService();
    await auth.initialize();
    if (!mounted) return;
    if (auth.isAuthenticated) {
      context.go(SplashScreen.kRouteName);
      return;
    }

    await FirstRun.startAsGuest(analytics,
        source: FirstRun.guestFromOnboarding);
    if (!mounted) return;
    // The shell opens the blank note armed above.
    context.go(HomeScreen.kRouteName);
  }

  void _openLegal({required bool privacy}) {
    context.push(privacy
        ? TermsAcceptanceScreen.privacyLocation
        : TermsAcceptanceScreen.kRouteName);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    // Re-measured after every layout, so a rotation, longer copy
    // or a text-scale change all keep the band behind the hero.
    WidgetsBinding.instance.addPostFrameCallback(_measureBand);
    final measured = _bandTop;

    return Scaffold(
      backgroundColor: context.sketch.bg,
      body: KeyedSubtree(
        key: _backgroundKey,
        child: TweenAnimationBuilder<double>(
          // Rough first-frame estimate; the band is still drawing in when the
          // measurement replaces it, so the snap is not visible. After that it
          // eases rather than jumping when the hero moves.
          tween: Tween<double>(
              end: measured ??
                  (MediaQuery.sizeOf(context).height - 300) / 2 - 110),
          duration: measured == null
              ? Duration.zero
              : SketchMotion.of(context, SketchMotion.base),
          curve: SketchMotion.enter,
          builder: (context, top, child) => DoodleBackground(
            top: top,
            squiggle: true,
            animate: true,
            child: child!,
          ),
          child: SafeArea(
            child: SketchContentWidth(
              // Wider on a tablet: at the phone's 560 the art could only reach
              // about half the width of a 13-inch iPad.
              maxWidth:
                  MediaQuery.sizeOf(context).shortestSide >= 600 ? 720 : 560,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: OnboardingPageView(
                      hero: const WriteItDownHero(),
                      heroKey: _heroKey,
                      title: l10n.obWriteTitle,
                      body: '${l10n.obWriteBody}\n\n${l10n.obPrivateBody}',
                      // States the limits of end-to-end encryption.
                      footnote: l10n.obPrivateFootnote,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        SketchSpace.screenX, 20, SketchSpace.screenX, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: PillButton.secondary(
                            label: l10n.obLogIn,
                            onPressed: () => _finish(logIn: true),
                          ),
                        ),
                        const SizedBox(width: SketchSpace.grid),
                        Expanded(
                          child: PillButton(
                            label: l10n.obGetStarted,
                            onPressed: () => _finish(logIn: false),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Under both buttons, so it reads as covering either.
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        SketchSpace.screenX, 4, SketchSpace.screenX, 12),
                    child: ConsentLine(
                      onTerms: () => _openLegal(privacy: false),
                      onPrivacy: () => _openLegal(privacy: true),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "By continuing you agree to the Terms and Privacy Policy", with both
/// names tappable. The sentence is one translated string with the two link
/// labels as placeholders, so each language (RTL included) orders it
/// naturally; the links are found again by splitting on private markers.
class ConsentLine extends StatefulWidget {
  const ConsentLine({
    super.key,
    required this.onTerms,
    required this.onPrivacy,
  });

  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  State<ConsentLine> createState() => _ConsentLineState();
}

class _ConsentLineState extends State<ConsentLine> {
  // Unicode private-use characters: never in a translation.
  static const String _termsMark = '\uE000';
  static const String _privacyMark = '\uE001';

  late final TapGestureRecognizer _terms = TapGestureRecognizer()
    ..onTap = () => widget.onTerms();
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()
    ..onTap = () => widget.onPrivacy();

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final l10n = AppL10n.of(context);
    final base = context.type.caption.copyWith(color: s.muted, height: 1.4);
    final link = base.copyWith(
      color: s.ink,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: s.ink,
    );

    final sentence = l10n.obConsentLine(_termsMark, _privacyMark);
    final spans = <InlineSpan>[];
    var start = 0;
    for (var i = 0; i < sentence.length; i++) {
      final ch = sentence[i];
      if (ch != _termsMark && ch != _privacyMark) continue;
      if (i > start) spans.add(TextSpan(text: sentence.substring(start, i)));
      spans.add(ch == _termsMark
          ? TextSpan(
              text: l10n.obConsentTerms, style: link, recognizer: _terms)
          : TextSpan(
              text: l10n.obConsentPrivacy,
              style: link,
              recognizer: _privacy));
      start = i + 1;
    }
    if (start < sentence.length) {
      spans.add(TextSpan(text: sentence.substring(start)));
    }

    return Text.rich(
      TextSpan(style: base, children: spans),
      textAlign: TextAlign.center,
    );
  }
}

/// One onboarding page: the hero illustration above the highlighted headline
/// and a 14/1.5 muted line (plus an optional caveat), centred as one group.
class OnboardingPageView extends StatelessWidget {
  const OnboardingPageView({
    super.key,
    required this.hero,
    required this.title,
    required this.body,
    this.footnote,
    this.heroKey,
  });

  final Widget hero;

  /// A localized string with the `[[...]]` highlight marker.
  final String title;
  final String body;
  final String? footnote;

  /// Lets the screen find where the hero landed, so the doodle band behind
  /// it can follow instead of guessing.
  final Key? heroKey;

  /// How much to enlarge the copy on a tablet. At phone sizes the headline
  /// read as a caption on a 13-inch screen.
  static const double tabletTypeScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final k = tablet ? tabletTypeScale : 1.0;

    TextStyle scaled(TextStyle style, double fallback) =>
        style.copyWith(fontSize: (style.fontSize ?? fallback) * k);

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: HighlightedText(title, style: scaled(t.screenTitle, 28)),
        ),
        SizedBox(height: 12 * k),
        Text(
          body,
          style: t.bodyRegular
              .copyWith(fontSize: 14 * k, height: 1.5, color: s.muted),
        ),
        if (footnote != null) ...[
          SizedBox(height: 10 * k),
          Text(footnote!, style: scaled(t.caption, 12)),
        ],
      ],
    );

    // The hero and the copy are one group, centred in the page, with a fixed
    // gap between them. Previously the copy was pinned to the bottom and the
    // hero centred in everything left over, so the gap between illustration
    // and headline grew with screen height — a dead band on tall phones and a
    // chasm on a tablet. Spare height now goes above and below the group
    // instead of into the middle of it. The hero is Flexible, so on a short
    // phone it shrinks rather than pushing the copy off screen; the copy only
    // scrolls if a large text scale makes it taller than its 45% band.
    return LayoutBuilder(
      builder: (context, box) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: KeyedSubtree(key: heroKey, child: hero),
              ),
            ),
            SizedBox(height: tablet ? 40 : 28),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: box.maxHeight * 0.45),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: SketchSpace.screenX + 4),
                child: copy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
