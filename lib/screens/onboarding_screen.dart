import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/onboarding/onboarding_heroes.dart';
import '../constants/shared_preference_keys.dart';
import '../design_system/design_system.dart';
import '../service_locators/init_service_locators.dart';
import '../services/analytics/analytics_facade.dart';
import '../services/onboarding_version.dart';
import 'terms_acceptance_screen.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

/// First-run onboarding: three Sketchbook pages, then on to the terms and the
/// sign-in screen (which is the "Get started" step).
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
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _finishing = false;

  static const int _pageCount = 3;

  // Where the doodle band sits. It used to be computed from hard-coded guesses
  // about the layout (`(height - 300) / 2 - 110`), but the band scales with
  // screen width while those numbers assumed a phone, so on a tablet it slid
  // below the illustration and ran behind the copy. It is now measured from
  // where the current page's hero actually landed.
  final _backgroundKey = GlobalKey();
  final _heroKeys = List.generate(_pageCount, (_) => GlobalKey());
  double? _bandTop;

  @override
  void initState() {
    super.initState();
    getIt<AnalyticsFacade>().trackScreenView(screenName: 'Onboarding');
  }

  // Built per-call rather than stored in a field: the copy needs
  // Localizations, which a field initializer cannot reach.
  List<OnboardingPageView> _buildPages(BuildContext context) {
    final l10n = AppL10n.of(context);
    return [
      OnboardingPageView(
        hero: const WriteItDownHero(),
        heroKey: _heroKeys[0],
        title: l10n.obWriteTitle,
        body: l10n.obWriteBody,
      ),
      OnboardingPageView(
        hero: const OrganizedHero(),
        heroKey: _heroKeys[1],
        title: l10n.obOrganizedTitle,
        body: l10n.obOrganizedBody,
      ),
      OnboardingPageView(
        hero: const PrivateHero(),
        heroKey: _heroKeys[2],
        title: l10n.obPrivateTitle,
        body: l10n.obPrivateBody,
        footnote: l10n.obPrivateFootnote,
      ),
    ];
  }

  /// DoodlePainter draws a band 200 units tall on a 390-unit-wide canvas,
  /// scaled by screen width; its centre runs 10 units above the hero's, as in
  /// the mocks.
  void _measureBand(Duration _) {
    if (!mounted) return;
    final background =
        _backgroundKey.currentContext?.findRenderObject() as RenderBox?;
    final hero = _heroKeys[_currentPage].currentContext?.findRenderObject()
        as RenderBox?;
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

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  /// [signUp] picks the mode the sign-in screen opens in: "Get started" is
  /// for new people, "Log in" (and Skip) for returning ones.
  Future<void> _completeOnboarding({bool signUp = false}) async {
    if (_finishing) return;
    _finishing = true;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(kHasCompletedOnboardingKey, true);
    // A new user has now seen this generation's onboarding, so the
    // What's-new sheet (meant for upgraders) never shows for them.
    await OnboardingVersion.markSeen(preferences);

    getIt<AnalyticsFacade>().trackOnboardingComplete();

    if (!mounted) return;
    context.go(signUp
        ? TermsAcceptanceScreen.signUpLocation
        : TermsAcceptanceScreen.kRouteName);
  }

  void _nextPage() {
    if (_currentPage < _pageCount - 1) {
      _pageController.nextPage(
        duration: SketchMotion.of(context, SketchMotion.slow),
        curve: SketchMotion.enter,
      );
    } else {
      _completeOnboarding(signUp: true);
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final pages = _buildPages(context);
    final isLast = _currentPage == pages.length - 1;

    // Re-measured after every layout, so a rotation, a page with longer copy
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
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      itemCount: pages.length,
                      itemBuilder: (context, index) => pages[index],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        SketchSpace.screenX, 8, SketchSpace.screenX, 0),
                    child: OnboardingDots(
                      count: pages.length,
                      current: _currentPage,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        SketchSpace.screenX, 20, SketchSpace.screenX, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: PillButton.secondary(
                            label: isLast ? l10n.obLogIn : l10n.obSkip,
                            onPressed: _skipOnboarding,
                          ),
                        ),
                        const SizedBox(width: SketchSpace.grid),
                        Expanded(
                          child: PillButton(
                            label: isLast ? l10n.obGetStarted : l10n.obNext,
                            onPressed: _nextPage,
                          ),
                        ),
                      ],
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

/// Progress dots: the active one is a 20×6 ink pill, the rest 6×6 hairline.
class OnboardingDots extends StatelessWidget {
  const OnboardingDots({super.key, required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final dur = SketchMotion.of(context, SketchMotion.base);
    return Semantics(
      label: AppL10n.of(context).obPageIndicator(current + 1, count),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 4),
        child: Row(
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: dur,
                curve: SketchMotion.enter,
                margin: const EdgeInsetsDirectional.only(end: 6),
                width: i == current ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == current ? s.ink : s.hairline,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
