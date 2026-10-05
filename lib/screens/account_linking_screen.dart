import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinpoint/design_system/design_system.dart';
import 'package:pinpoint/services/api_service.dart';
import 'package:pinpoint/services/backend_auth_service.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/util/api_error_messages.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

/// Screen for linking Google account to existing email/password account
///
/// This screen is shown when a user tries to sign in with Google
/// but an account with that email already exists.
class AccountLinkingScreen extends StatefulWidget {
  static const String kRouteName = '/account-linking';

  /// Firebase ID token from Google Sign-In
  final String firebaseToken;

  const AccountLinkingScreen({
    super.key,
    required this.firebaseToken,
  });

  @override
  State<AccountLinkingScreen> createState() => _AccountLinkingScreenState();
}

class _AccountLinkingScreenState extends State<AccountLinkingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    getIt<AnalyticsFacade>().trackScreenView(screenName: 'AccountLinking');
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLinkAccounts() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final backendAuthService = context.read<BackendAuthService>();

      await backendAuthService.linkGoogleAccount(
        firebaseToken: widget.firebaseToken,
        password: _passwordController.text,
      );

      // Track account link
      getIt<AnalyticsFacade>().trackAccountLink(method: 'google');

      // Success! Navigate to home
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // A coded API error renders in the user's language; anything else
        // falls back to the exception text, as before.
        _errorMessage = e is ApiError
            ? localizedApiError(context, e)
            : e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleCancel() {
    // Go back to auth screen
    context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final l10n = AppL10n.of(context);
    final muted =
        t.bodyRegular.copyWith(fontSize: 14, height: 1.5, color: s.muted);

    return SketchScaffold(
      title: l10n.linkTitle,
      onBack: _isLoading ? () {} : _handleCancel,
      doodleTop: DoodleBackground.settingsTop,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            SketchSpace.screenX, 22, SketchSpace.screenX, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ExcludeSemantics(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: StickerTile(
                  color: SketchPastels.sky,
                  size: 64,
                  angle: -7,
                  icon: Icons.link_rounded,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Semantics(
              header: true,
              child: Text(l10n.linkAccountExists, style: t.pageTitle),
            ),
            const SizedBox(height: 16),

            // Info card
            SketchCard(
              pastel: SketchPastels.lavender,
              radius: SketchRadius.group,
              padding: const EdgeInsets.all(SketchSpace.cardPadLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.linkWhatsHappening,
                          style: t.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: SketchPastels.onPastel),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.linkExplanation,
                    style: t.bodyRegular.copyWith(
                        fontSize: 14,
                        height: 1.5,
                        color: SketchPastels.onPastel),
                  ),
                ],
              ),
            ),

            const SizedBox(height: SketchSpace.section),

            // Password Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.linkEnterPassword, style: t.sectionTitle),
                  const SizedBox(height: 12),
                  SketchTextField(
                    controller: _passwordController,
                    hint: l10n.linkPasswordHint,
                    semanticLabel: l10n.authPasswordLabel,
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: true,
                    revealLabel: l10n.auShowPassword,
                    concealLabel: l10n.auHidePassword,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) {
                      if (!_isLoading) _handleLinkAccounts();
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.authPasswordRequired;
                      }
                      return null;
                    },
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    SketchErrorPill(message: _errorMessage!),
                  ],
                  const SizedBox(height: 20),

                  // Link Button
                  PillButton(
                    label: l10n.auLinkAccountsCta,
                    loading: _isLoading,
                    onPressed: _handleLinkAccounts,
                  ),
                  const SizedBox(height: 10),

                  // Cancel Button
                  PillButton.secondary(
                    label: l10n.commonCancel,
                    onPressed: _isLoading ? null : _handleCancel,
                  ),
                ],
              ),
            ),

            const SizedBox(height: SketchSpace.section),

            // Security Note
            SketchCard(
              color: s.soft,
              borderColor: s.hairline,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: s.muted, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(l10n.linkPasswordNeverStored, style: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
