import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../../design_system/design_system.dart';
import '../../navigation/app_navigation.dart';
import '../../services/backend_auth_service.dart';
import '../../services/google_sign_in_service.dart';
import '../../services/logout_service.dart';
import '../../util/show_a_toast.dart';
import 'secret_input_sheet.dart';

/// ACCOUNT (linked sign-in methods), the Sign out row and the Danger zone.
///
/// The flows are the pre-redesign ones — validation, the audio-notes block,
/// sync-before-sign-out with a force option, linking Google behind a
/// password check, and account deletion — presented as Sketchbook sheets.
class SettingsAccountActions extends StatefulWidget {
  const SettingsAccountActions({super.key, required this.backendAuth});

  final BackendAuthService backendAuth;

  @override
  State<SettingsAccountActions> createState() => _SettingsAccountActionsState();
}

class _SettingsAccountActionsState extends State<SettingsAccountActions> {
  // ── linked accounts ──────────────────────────────────────────────
  bool _linking = false;
  Map<String, dynamic>? _providers;

  // ── sign out / delete ────────────────────────────────────────────
  bool _isLoggingOut = false;
  bool _isDeleting = false;
  String _logoutStatus = '';
  LogoutService? _logoutService;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  @override
  void didUpdateWidget(SettingsAccountActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.backendAuth.isAuthenticated !=
        oldWidget.backendAuth.isAuthenticated) {
      _loadProviders();
    }
  }

  Future<void> _loadProviders() async {
    if (!widget.backendAuth.isAuthenticated) return;
    try {
      final providers = await widget.backendAuth.getAuthProviders();
      if (mounted) setState(() => _providers = providers);
    } catch (e) {
      debugPrint('Error loading auth providers: $e');
    }
  }

  Future<void> _linkGoogleAccount() async {
    setState(() => _linking = true);

    // Resolved before the awaits below: these strings are read off the
    // BuildContext, which may be defunct by the time a failure surfaces.
    final l10n = AppL10n.of(context);
    final cancelledMessage = l10n.setGoogleSignInCancelled;
    final tokenFailedMessage = l10n.authFirebaseTokenFailed;

    try {
      final googleSignInService = GoogleSignInService();
      final userCredential = await googleSignInService.signInWithGoogle();
      if (userCredential == null) throw Exception(cancelledMessage);

      final firebaseToken = await googleSignInService.getFirebaseIdToken();
      if (firebaseToken == null) throw Exception(tokenFailedMessage);

      if (!mounted) return;

      final password = await showSecretInputSheet(
        context: context,
        title: l10n.setVerifyPasswordTitle,
        message: l10n.setVerifyPasswordPrompt,
        fieldLabels: [l10n.authPasswordLabel],
        confirmLabel: l10n.setVerify,
      );
      if (password == null || password.isEmpty) return;

      await widget.backendAuth.linkGoogleAccount(
        firebaseToken: firebaseToken,
        password: password,
      );
      await _loadProviders();

      if (mounted) {
        PinpointHaptics.success();
        showSuccessToast(
          context: context,
          title: l10n.setAccountLinked,
          description: l10n.setAccountLinkedBody,
        );
      }
    } catch (e) {
      if (mounted) {
        PinpointHaptics.error();
        showErrorToast(
          context: context,
          title: l10n.setLinkingFailed,
          description: e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  Future<void> _unlinkGoogleAccount() async {
    final l10n = AppL10n.of(context);
    final confirm = await showSketchConfirm(
      context: context,
      title: l10n.setUnlinkGoogleTitle,
      message: l10n.setUnlinkGoogleConfirm,
      confirmLabel: l10n.setUnlink,
      cancelLabel: l10n.commonCancel,
    );
    if (!confirm || !mounted) return;

    setState(() => _linking = true);
    try {
      await widget.backendAuth.unlinkGoogleAccount();
      await _loadProviders();
      if (mounted) {
        PinpointHaptics.success();
        showSuccessToast(
          context: context,
          title: l10n.setAccountUnlinked,
          description: l10n.setAccountUnlinkedBody,
        );
      }
    } catch (e) {
      if (mounted) {
        PinpointHaptics.error();
        showErrorToast(
          context: context,
          title: l10n.setUnlinkingFailed,
          description: e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  Future<void> _handleDeleteAccount() async {
    if (_isDeleting || _isLoggingOut) return;
    final l10n = AppL10n.of(context);

    final confirm = await showSketchConfirm(
      context: context,
      title: l10n.stDeleteAccount,
      message: l10n.setDeleteAccountConfirm,
      confirmLabel: l10n.stDeleteAccount,
      cancelLabel: l10n.commonCancel,
      sticker: const StickerTile(
        color: SketchPastels.pink,
        size: 52,
        angle: -8,
        icon: Icons.delete_forever_rounded,
      ),
    );
    if (!confirm || !mounted) return;

    // Resolved up front: deletion ends with this screen being replaced, and a
    // lookup against a torn-down context is exactly how the outcome message
    // used to get lost.
    final deletedTitle = l10n.setAccountDeleted;
    final deletedBody = l10n.setAccountDeletedBody;
    final failedTitle = l10n.setDeletionFailed;
    final failedBody = l10n.setDeletionFailedBody;

    setState(() => _isDeleting = true);
    try {
      final logoutService = LogoutService.fromServiceLocator(
        backendAuthService: widget.backendAuth,
        googleSignInService: GoogleSignInService(),
      );
      await logoutService.performAccountDeletion();

      PinpointHaptics.success();
      // Toast first, navigate second. The overlay entry lives in the root
      // navigator and survives the route change, whereas the old
      // navigate-then-toast-after-500ms order always found this screen
      // unmounted and silently showed nothing at all.
      if (mounted) {
        showSuccessToast(
          context: context,
          title: deletedTitle,
          description: deletedBody,
        );
      }
      AppNavigation.router.go('/auth');
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        PinpointHaptics.error();
        showErrorToast(
          context: context,
          title: failedTitle,
          description: failedBody,
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;
    final l10n = AppL10n.of(context);

    final confirm = await showSketchConfirm(
      context: context,
      title: l10n.stSignOut,
      message: l10n.setSignOutConfirm,
      confirmLabel: l10n.stSignOut,
      cancelLabel: l10n.commonCancel,
    );
    if (!confirm || !mounted) return;

    _logoutService = LogoutService.fromServiceLocator(
      backendAuthService: widget.backendAuth,
      googleSignInService: GoogleSignInService(),
    );
    _logoutService!.onPhaseChanged = (phase) {
      if (mounted) setState(() => _logoutStatus = _phaseMessage(phase));
    };

    setState(() {
      _isLoggingOut = true;
      _logoutStatus = l10n.setLogoutValidating;
    });

    try {
      final validation = await _logoutService!.validateLogout();
      if (!validation.canProceed) {
        if (mounted) {
          await _showValidationError(validation);
          if (mounted) setState(() => _isLoggingOut = false);
        }
        return;
      }

      final unsyncedCount = await _logoutService!.getUnsyncedNotesCount();
      // Guarded: this runs after an await, and the status string reads
      // Localizations off the context.
      if (unsyncedCount > 0 && mounted) {
        setState(() =>
            _logoutStatus = AppL10n.of(context).syncingNotes(unsyncedCount));
      }

      final success = await _logoutService!.performLogout();

      if (success) {
        PinpointHaptics.success();
        // Toast first: the overlay lives on the root navigator and survives
        // the route change below.
        if (mounted) {
          showSuccessToast(
            context: context,
            title: l10n.setSignedOut,
            description: l10n.setSignedOutBody,
          );
        }
        AppNavigation.router.go('/auth');
      } else if (mounted) {
        // This shouldn't normally happen since validation is done before
        // performLogout(), but handle it for safety
        PinpointHaptics.error();
        showErrorToast(
          context: context,
          title: l10n.setSignOutFailed,
          description: l10n.setSignOutFailedBody,
        );
      }
    } catch (e) {
      if (!mounted) return;
      final text = e.toString();
      if (text.contains('Sync failed') ||
          text.contains('sync') ||
          text.contains('network')) {
        final forceLogout = await showSketchConfirm(
          context: context,
          title: l10n.setSyncFailed,
          message: l10n
              .setSyncFailedBeforeSignOut(text.replaceAll('Exception: ', '')),
          confirmLabel: l10n.setForceSignOut,
          cancelLabel: l10n.commonCancel,
        );
        if (forceLogout) {
          PinpointHaptics.warning();
          if (mounted) {
            showWarningToast(
              context: context,
              title: l10n.setSignedOut,
              description: l10n.setSignedOutUnsynced,
            );
          }
          AppNavigation.router.go('/auth');
        }
      } else {
        PinpointHaptics.error();
        showErrorToast(
          context: context,
          title: l10n.setSignOutFailed,
          description: text.replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
          _logoutStatus = AppL10n.of(context).setLogoutPreparing;
        });
      }
    }
  }

  String _phaseMessage(LogoutPhase phase) {
    final l10n = AppL10n.of(context);
    return switch (phase) {
      LogoutPhase.validating => l10n.setLogoutValidating,
      LogoutPhase.syncing => l10n.setLogoutSyncing,
      LogoutPhase.signingOut => l10n.setLogoutServer,
      LogoutPhase.cleaningData => l10n.setLogoutClearing,
      LogoutPhase.completed => l10n.setLogoutCompleted,
    };
  }

  Future<void> _showValidationError(LogoutValidationResult validation) {
    final l10n = AppL10n.of(context);
    return showSketchSheet<void>(
      context: context,
      builder: (ctx) => SketchSheet(
        scrollable: false,
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StickerTile(
              color: SketchPastels.yellow,
              size: 52,
              angle: -8,
              icon: Icons.warning_amber_rounded,
            ),
            const SizedBox(height: 14),
            Semantics(
              header: true,
              child: Text(l10n.setCannotSignOut, style: ctx.type.emptyTitle),
            ),
            const SizedBox(height: 8),
            Text(
              validation.blockReason == LogoutBlockReason.audioNotesExist
                  ? l10n.logoutAudioWarningDetailed(validation.audioNotesCount!)
                  : validation.errorMessage ?? l10n.setCannotSignOutGeneric,
              style: ctx.type.bodyRegular
                  .copyWith(fontSize: 14, color: ctx.sketch.muted),
            ),
          ],
        ),
        child: PillButton(
          label: l10n.commonOk,
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = context.sketch;
    final t = context.type;
    final hasGoogle = (_providers?['has_google'] ?? false) == true;

    Widget busy() => SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: s.ink),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SketchOverline(l10n.stSectionAccount),
        SketchGroup(
          children: [
            SketchRow(
              icon: Icons.mail_outline_rounded,
              label: l10n.setProviderEmail,
              subtitle:
                  widget.backendAuth.userEmail ?? l10n.setProviderEmailSubtitle,
              trailing: SketchTag(
                label: l10n.setLinkedBadge,
                pastel: SketchPastels.mint,
              ),
            ),
            if (_providers != null)
              SketchRow(
                icon: Icons.g_mobiledata_rounded,
                label: l10n.setProviderGoogle,
                subtitle: hasGoogle
                    ? l10n.setProviderLinked
                    : l10n.setProviderLinkPrompt,
                value: hasGoogle || _linking ? null : l10n.stLink,
                onTap: _linking || hasGoogle ? null : _linkGoogleAccount,
                trailing: _linking
                    ? busy()
                    : hasGoogle
                        ? CircleIconButton(
                            icon: Icons.link_off_rounded,
                            size: 36,
                            iconSize: 18,
                            semanticLabel: l10n.setUnlinkTooltip,
                            onPressed: _unlinkGoogleAccount,
                          )
                        : null,
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Sign out: an outline row with error-coloured text.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SketchSpace.screenX),
          child: SketchCard(
            radius: SketchRadius.group,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onTap: _isLoggingOut || _isDeleting ? null : _handleLogout,
            semanticLabel: _isLoggingOut ? _logoutStatus : l10n.stSignOut,
            child: ExcludeSemantics(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Row(
                  children: [
                    if (_isLoggingOut)
                      busy()
                    else
                      const Icon(Icons.logout_rounded,
                          size: 20, color: SketchFunctional.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isLoggingOut ? l10n.setSigningOut : l10n.stSignOut,
                            style:
                                t.body.copyWith(color: SketchFunctional.error),
                          ),
                          if (_isLoggingOut && _logoutStatus.isNotEmpty)
                            Text(_logoutStatus, style: t.caption),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Danger zone.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SketchSpace.screenX),
          child: SketchCard(
            radius: SketchRadius.group,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            borderColor: SketchFunctional.error,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.stDangerZone.toUpperCase(),
                    style: t.overline.copyWith(color: SketchFunctional.error),
                  ),
                ),
                SketchPressable(
                  onTap: _isDeleting || _isLoggingOut
                      ? null
                      : _handleDeleteAccount,
                  semanticLabel: _isDeleting
                      ? l10n.setDeletingAccount
                      : l10n.stDeleteAccount,
                  child: ExcludeSemantics(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Row(
                        children: [
                          if (_isDeleting)
                            busy()
                          else
                            const Icon(Icons.delete_forever_rounded,
                                size: 20, color: SketchFunctional.error),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isDeleting
                                      ? l10n.setDeletingAccount
                                      : l10n.stDeleteAccount,
                                  style: t.body
                                      .copyWith(color: SketchFunctional.error),
                                ),
                                Text(
                                  _isDeleting
                                      ? l10n.setPleaseWait
                                      : l10n.setDeleteAccountSubtitle,
                                  style: t.caption,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              size: 20, color: s.muted),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
