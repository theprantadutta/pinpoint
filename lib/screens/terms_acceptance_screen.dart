import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/shared_preference_keys.dart';
import '../design_system/design_system.dart';
import '../service_locators/init_service_locators.dart';
import '../services/analytics/analytics_facade.dart';
import '../util/show_a_toast.dart';
import 'auth_screen.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

enum _LegalDoc { terms, privacy }

/// Terms and Privacy acceptance screen
/// Shows terms of service and privacy policy with acceptance requirement
///
/// Sketchbook: a sheet-style panel holding a Terms / Privacy switch, the
/// scrollable legal card and — unless [isViewOnly] — the agreement checkbox
/// and an inverse "I agree" pill.
class TermsAcceptanceScreen extends StatefulWidget {
  const TermsAcceptanceScreen({
    super.key,
    this.isViewOnly = false,
    this.startInSignUp = false,
  });

  static const String kRouteName = '/terms-acceptance';

  /// The query flag the onboarding's "Get started" passes through to the
  /// sign-in screen, so it opens in sign-up mode.
  static const String signUpQuery = 'mode';
  static const String signUpValue = 'signup';
  static const String signUpLocation = '$kRouteName?$signUpQuery=$signUpValue';

  /// If true, shows in view-only mode (no acceptance required, for settings)
  final bool isViewOnly;

  /// Open the sign-in screen in sign-up mode after accepting.
  final bool startInSignUp;

  @override
  State<TermsAcceptanceScreen> createState() => _TermsAcceptanceScreenState();
}

class _TermsAcceptanceScreenState extends State<TermsAcceptanceScreen> {
  _LegalDoc _doc = _LegalDoc.terms;
  bool _hasAccepted = false;
  String _termsContent = '';
  String _privacyContent = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    getIt<AnalyticsFacade>().trackScreenView(screenName: 'Terms');
    _loadLegalDocuments();
  }

  Future<void> _loadLegalDocuments() async {
    try {
      final termsData = await rootBundle.loadString('assets/legal/terms.md');
      final privacyData =
          await rootBundle.loadString('assets/legal/privacy.md');

      if (!mounted) return;
      setState(() {
        _termsContent = termsData;
        _privacyContent = privacyData;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading legal documents: $e');
      if (!mounted) return;
      setState(() {
        _termsContent = '# Error\n\nFailed to load terms of service.';
        _privacyContent = '# Error\n\nFailed to load privacy policy.';
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptTerms() async {
    if (!_hasAccepted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kHasAcceptedTermsKey, true);
      await prefs.setString(
        kTermsAcceptedDateKey,
        DateTime.now().toIso8601String(),
      );

      getIt<AnalyticsFacade>().trackTermsAccepted();

      if (!mounted) return;

      // Navigate to auth screen
      context.go(widget.startInSignUp
          ? AuthScreen.signUpLocation
          : AuthScreen.kRouteName);
    } catch (e) {
      debugPrint('Error saving terms acceptance: $e');
      if (!mounted) return;

      showSketchToast(
        context: context,
        message: AppL10n.of(context).termsSaveFailed,
        tone: ToastTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final l10n = AppL10n.of(context);

    final header = widget.isViewOnly
        ? Padding(
            padding: const EdgeInsets.fromLTRB(SketchSpace.screenX - 1,
                SketchSpace.headerTop, SketchSpace.screenX, 0),
            child: Row(
              children: [
                CircleIconButton.back(context, onPressed: () => context.pop()),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(l10n.setTermsPrivacy,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.sheetTitle),
                  ),
                ),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(
                SketchSpace.screenX, 16, SketchSpace.screenX, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandSticker(size: 44),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: HighlightedText(l10n.auTermsTitle, style: t.pageTitle),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.auTermsBody,
                  style: t.bodyRegular
                      .copyWith(fontSize: 14, height: 1.5, color: s.muted),
                ),
              ],
            ),
          );

    return Scaffold(
      backgroundColor: s.bg,
      body: DoodleBackground(
        top: DoodleBackground.settingsTop,
        child: SafeArea(
          bottom: false,
          child: SketchContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: 18),
                Expanded(child: _buildPanel(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The sheet-style panel: surface, top radius 34, 1.5px top outline and a
  /// grab handle, like a [SketchSheet] docked to the bottom of the screen.
  Widget _buildPanel(BuildContext context) {
    final s = context.sketch;
    final l10n = AppL10n.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(SketchRadius.sheet)),
        border: Border(
          top: BorderSide(color: s.outline, width: SketchStroke.outline),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 12, 18, 16 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: s.hairline,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SketchSegmentedControl<_LegalDoc>(
              expand: true,
              segments: [
                SketchSegment(
                    value: _LegalDoc.terms, label: l10n.termsTabTerms),
                SketchSegment(
                    value: _LegalDoc.privacy, label: l10n.termsTabPrivacy),
              ],
              selected: _doc,
              onChanged: (d) => setState(() => _doc = d),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: s.ink),
                      ),
                    )
                  : _LegalCard(
                      key: ValueKey(_doc),
                      content: _doc == _LegalDoc.terms
                          ? _termsContent
                          : _privacyContent,
                    ),
            ),
            if (!widget.isViewOnly && !_isLoading) ...[
              const SizedBox(height: 14),
              _AgreeRow(
                checked: _hasAccepted,
                label: l10n.termsAgreeCheckbox,
                onChanged: (v) => setState(() => _hasAccepted = v),
              ),
              const SizedBox(height: 12),
              PillButton(
                label: l10n.auTermsAgree,
                onPressed: _hasAccepted ? _acceptTerms : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The scrollable legal text in an outlined card (radius 18).
class _LegalCard extends StatelessWidget {
  const _LegalCard({super.key, required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final body =
        t.bodyRegular.copyWith(fontSize: 14, height: 1.6, color: s.ink);

    return Container(
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(SketchRadius.card),
        border: Border.all(color: s.outline, width: SketchStroke.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Markdown(
        data: content,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          h1: t.emptyTitle,
          h2: t.sectionTitle,
          h3: t.cardTitle,
          h4: t.cardTitle,
          p: body,
          listBullet: body,
          strong: body.copyWith(fontWeight: FontWeight.w800),
          em: body.copyWith(fontStyle: FontStyle.italic),
          a: body.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: s.ink,
          ),
          blockquote: body.copyWith(color: s.muted),
          blockquoteDecoration: BoxDecoration(
            color: s.soft,
            borderRadius: BorderRadius.circular(SketchRadius.bullet),
          ),
          code: t.caption.copyWith(color: s.ink, backgroundColor: s.soft),
          horizontalRuleDecoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: s.hairline, width: SketchStroke.outline),
            ),
          ),
          h1Padding: const EdgeInsets.only(bottom: 4),
          h2Padding: const EdgeInsets.only(top: 12, bottom: 2),
        ),
      ),
    );
  }
}

/// "I have read and agree…" — the whole row toggles the checkbox.
class _AgreeRow extends StatelessWidget {
  const _AgreeRow({
    required this.checked,
    required this.label,
    required this.onChanged,
  });

  final bool checked;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      child: SketchPressable(
        onTap: () => onChanged(!checked),
        scale: 0.99,
        semanticLabel: label,
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: SketchSpace.minTap),
            child: Row(
              children: [
                SketchCheckbox(checked: checked),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: context.type.bodyRegular.copyWith(fontSize: 14),
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
