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
        title: l10n.obWriteTitle,
        body: l10n.obWriteBody,
      ),
      OnboardingPageView(
        hero: const OrganizedHero(),
        title: l10n.obOrganizedTitle,
        body: l10n.obOrganizedBody,
      ),
      OnboardingPageView(
        hero: const PrivateHero(),
        title: l10n.obPrivateTitle,
        body: l10n.obPrivateBody,
        footnote: l10n.obPrivateFootnote,
      ),
    ];
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

    return Scaffold(
      backgroundColor: context.sketch.bg,
      body: DoodleBackground(
        // The 200px doodle band runs behind the hero, which centres in the
        // space above the copy, dots and buttons (~300px).
        top: (MediaQuery.sizeOf(context).height - 300) / 2 - 110,
        squiggle: true,
        animate: true,
        child: SafeArea(
          child: SketchContentWidth(
            maxWidth: 560,
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
    );
  }
}

/// One onboarding page: the hero illustration in the top 55%, then the
/// highlighted headline and a 14/1.5 muted line (plus an optional caveat).
class OnboardingPageView extends StatelessWidget {
  const OnboardingPageView({
    super.key,
    required this.hero,
    required this.title,
    required this.body,
    this.footnote,
  });

  final Widget hero;

  /// A localized string with the `[[...]]` highlight marker.
  final String title;
  final String body;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: HighlightedText(title, style: t.screenTitle),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          style:
              t.bodyRegular.copyWith(fontSize: 14, height: 1.5, color: s.muted),
        ),
        if (footnote != null) ...[
          const SizedBox(height: 10),
          Text(footnote!, style: t.caption),
        ],
      ],
    );

    // The hero takes the space the copy leaves (at least the top 55%) and
    // centres in it; the copy sits right above the dots and only scrolls if
    // a large text scale makes it taller than its 45% band.
    return LayoutBuilder(
      builder: (context, box) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
              child: hero,
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: box.maxHeight * 0.45),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  SketchSpace.screenX + 4, 12, SketchSpace.screenX + 4, 8),
              child: copy,
            ),
          ),
        ],
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
