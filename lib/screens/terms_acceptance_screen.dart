import 'package:material_ui/material_ui.dart';
// flutter_markdown_plus still takes package:flutter/material.dart's ThemeData;
// MaterialUiCompatibilityBridge (main.dart) provides one mapped from ours.
// ignore: deprecated_member_use
import 'package:flutter/material.dart' as legacy show Theme;
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';
import '../design_system/design_system.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

enum _LegalDoc { terms, privacy }

/// The bundled Terms of Service and Privacy Policy, read-only (Settings →
/// Terms & Privacy, the paywall, and the links in the onboarding's consent
/// line).
///
/// Sketchbook: a sheet-style panel holding a Terms / Privacy switch and the
/// scrollable legal card.
///
/// It used to double as a checkbox screen people had to pass before signing
/// in; agreeing is now the onboarding's "By continuing…" line
/// (`FirstRun.acceptTerms`), so the route keeps its old name only.
class TermsAcceptanceScreen extends StatefulWidget {
  const TermsAcceptanceScreen({super.key, this.openPrivacy = false});

  static const String kRouteName = '/terms-acceptance';

  /// The query that opens the Privacy Policy tab instead of the Terms.
  static const String docQuery = 'doc';
  static const String privacyValue = 'privacy';
  static const String privacyLocation = '$kRouteName?$docQuery=$privacyValue';

  /// Open on the Privacy Policy rather than the Terms of Service.
  final bool openPrivacy;

  @override
  State<TermsAcceptanceScreen> createState() => _TermsAcceptanceScreenState();
}

class _TermsAcceptanceScreenState extends State<TermsAcceptanceScreen> {
  late _LegalDoc _doc =
      widget.openPrivacy ? _LegalDoc.privacy : _LegalDoc.terms;
  String _termsContent = '';
  String _privacyContent = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final l10n = AppL10n.of(context);

    final header = Padding(
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
        styleSheet: MarkdownStyleSheet.fromTheme(legacy.Theme.of(context)).copyWith(
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
