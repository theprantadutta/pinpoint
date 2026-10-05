import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../../design_system/design_system.dart';
import '../../navigation/app_navigation.dart';
import '../../screens/sync_screen.dart';
import '../../service_locators/init_service_locators.dart';
import '../../services/pending_changes_service.dart';
import '../../services/user_profile.dart';
import '../../sync/sync_manager.dart';
import '../../sync/sync_service.dart';
import '../../util/show_a_toast.dart';
import 'settings_format.dart';

/// Where the account card's status line stands.
enum AccountSyncState { synced, syncing, failed, never }

/// The lavender account card at the top of Settings: avatar, name, provider,
/// an ink "Sync now" pill, a dashed rule and a status line.
///
/// Purely presentational — [SettingsAccountSection] feeds it from
/// [SyncManager] — so it can be golden-tested without a sync stack.
class SettingsAccountCard extends StatelessWidget {
  const SettingsAccountCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.state,
    required this.statusText,
    required this.onSyncNow,
    this.onTap,
    this.onRetry,
    this.photoUrl,
  });

  final String name;
  final String subtitle;
  final AccountSyncState state;
  final String statusText;
  final VoidCallback? onSyncNow;
  final VoidCallback? onTap;

  /// Tapping the status line when the last sync failed.
  final VoidCallback? onRetry;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final l10n = AppL10n.of(context);
    final syncing = state == AccountSyncState.syncing;

    final dot = switch (state) {
      AccountSyncState.synced => SketchFunctional.successOnPastel,
      AccountSyncState.syncing => SketchPastels.yellow,
      AccountSyncState.failed => SketchPastels.pink,
      AccountSyncState.never => SketchPastels.lavender,
    };

    final status = Row(
      children: [
        StatusDot(color: dot),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            statusText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: SketchPastels.onPastel,
            ),
          ),
        ),
      ],
    );

    return SketchPressable(
      onTap: onTap,
      scale: 0.985,
      semanticLabel: '$name, $statusText',
      child: Container(
        padding: const EdgeInsets.all(SketchSpace.cardPadLg),
        decoration: BoxDecoration(
          color: SketchPastels.lavender,
          borderRadius: BorderRadius.circular(SketchRadius.banner),
          border: Border.all(
              color: SketchPastels.onPastel, width: SketchStroke.outline),
        ),
        child: OnPastel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ExcludeSemantics(
                    child: SketchAvatar(name: name, imageUrl: photoUrl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.cardTitle.copyWith(
                                fontSize: 16, color: SketchPastels.onPastel),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.caption
                                .copyWith(color: SketchPastels.onPastel),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SyncPill(
                    label: syncing ? l10n.stSyncing : l10n.stSyncNow,
                    busy: syncing,
                    onTap: syncing ? null : onSyncNow,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _DashedRule(),
              const SizedBox(height: 12),
              if (state == AccountSyncState.failed && onRetry != null)
                SketchPressable(
                  onTap: onRetry,
                  semanticLabel: statusText,
                  child: ExcludeSemantics(child: status),
                )
              else
                ExcludeSemantics(child: status),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncPill extends StatelessWidget {
  const _SyncPill({required this.label, required this.busy, this.onTap});

  final String label;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // The pill sits on a pastel, so it is ink on cream in both themes.
    final fg = SketchColors.light.onInverse;
    return SketchPressable(
      onTap: onTap,
      enabled: !busy,
      semanticLabel: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: SketchSpace.minTap),
        child: Center(
          widthFactor: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: SketchPastels.onPastel,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy) ...[
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.8, color: fg),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: context.type.chip
                        .copyWith(fontWeight: FontWeight.w700, color: fg),
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

class _DashedRule extends StatelessWidget {
  const _DashedRule();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1.2,
      width: double.infinity,
      child: CustomPaint(painter: _DashedLinePainter()),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SketchPastels.onPastel.withValues(alpha: 0.4)
      ..strokeWidth = size.height;
    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      final end = (x + SketchStroke.dashGap).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x += SketchStroke.dashGap * 2;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) => false;
}

/// The lavender card for a signed-out user: a short pitch and a Sign in pill.
class SettingsSignInCard extends StatelessWidget {
  const SettingsSignInCard({super.key, required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final l10n = AppL10n.of(context);
    return SketchCard(
      pastel: SketchPastels.lavender,
      radius: SketchRadius.banner,
      padding: const EdgeInsets.all(SketchSpace.cardPadLg),
      onTap: onSignIn,
      semanticLabel: '${l10n.stSignInTitle}. ${l10n.stSignInBody}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            const SketchAvatar(name: null),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.stSignInTitle,
                      style: t.cardTitle.copyWith(
                          fontSize: 16, color: SketchPastels.onPastel)),
                  const SizedBox(height: 2),
                  Text(l10n.stSignInBody,
                      style:
                          t.caption.copyWith(color: SketchPastels.onPastel)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _SyncPill(label: l10n.stSignInAction, busy: false, onTap: onSignIn),
          ],
        ),
      ),
    );
  }
}

/// [SettingsAccountCard] wired to the signed-in profile and [SyncManager].
///
/// "Sync now" runs the same manual sync the old Settings tile did, and the
/// outcome is reported as a toast; the status line follows the manager.
class SettingsAccountSection extends StatefulWidget {
  const SettingsAccountSection({super.key});

  @override
  State<SettingsAccountSection> createState() => _SettingsAccountSectionState();
}

class _SettingsAccountSectionState extends State<SettingsAccountSection> {
  final SyncManager _sync = getIt<SyncManager>();
  late final Stream<int> _pending = PendingChangesService.watchCount();
  bool _manualSyncing = false;
  bool _lastManualFailed = false;

  Future<void> _syncNow() async {
    if (_manualSyncing || _sync.isSyncing) return;
    final l10n = AppL10n.of(context);
    setState(() {
      _manualSyncing = true;
      _lastManualFailed = false;
    });

    try {
      if (!await _sync.isConfigured()) {
        if (!mounted) return;
        showWarningToast(
          context: context,
          title: l10n.setSyncFailed,
          description: l10n.setSyncServiceNotReady,
        );
        return;
      }

      final result = await _sync.sync();
      if (!mounted) return;

      if (result.success) {
        PinpointHaptics.success();
        final total =
            result.notesSynced + result.foldersSynced + result.remindersSynced;
        showSuccessToast(
          context: context,
          title: l10n.setSyncComplete,
          description: l10n.stSyncedItems(total),
        );
      } else {
        PinpointHaptics.error();
        setState(() => _lastManualFailed = true);
        showErrorToast(
          context: context,
          title: l10n.setSyncFailed,
          description: result.message,
        );
      }
    } catch (e) {
      if (!mounted) return;
      PinpointHaptics.error();
      setState(() => _lastManualFailed = true);
      showErrorToast(
        context: context,
        title: l10n.setSyncFailed,
        description: l10n.setSyncFailedWithError(e.toString()),
      );
    } finally {
      if (mounted) setState(() => _manualSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final profile = UserProfile.current();
    final subtitle = switch (profile.provider) {
      SignInProvider.google => l10n.signedInWithGoogle,
      SignInProvider.apple => l10n.signedInWithApple,
      SignInProvider.email => profile.email ?? '',
      SignInProvider.none => l10n.notSignedIn,
    };

    return ListenableBuilder(
      listenable: _sync,
      builder: (context, _) {
        return StreamBuilder<int>(
          stream: _pending,
          builder: (context, snap) {
            final pending = snap.data ?? 0;
            final syncing = _manualSyncing || _sync.isSyncing;
            final last = _sync.lastSyncDateTime;

            final AccountSyncState state;
            final String text;
            if (syncing) {
              state = AccountSyncState.syncing;
              text = pending > 0
                  ? l10n.stSyncingChanges(pending)
                  : l10n.stSyncing;
            } else if (_lastManualFailed ||
                _sync.status == SyncStatus.error) {
              state = AccountSyncState.failed;
              text = l10n.stSyncFailedRetry;
            } else if (last != null) {
              state = AccountSyncState.synced;
              text = l10n.stSyncedAgo(relativeAgo(context, last.toLocal()));
            } else {
              state = AccountSyncState.never;
              text = l10n.stNotSyncedYet;
            }

            return SettingsAccountCard(
              name: profile.displayName ??
                  profile.email ??
                  l10n.setAccountFallbackName,
              subtitle: subtitle,
              state: state,
              statusText: text,
              onSyncNow: _syncNow,
              onRetry: _syncNow,
              onTap: () {
                PinpointHaptics.light();
                AppNavigation.router.push(SyncScreen.kRouteName);
              },
            );
          },
        );
      },
    );
  }
}
