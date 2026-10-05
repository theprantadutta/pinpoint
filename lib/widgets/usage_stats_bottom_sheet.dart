import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/premium_limits.dart';
import '../design_system/design_system.dart';
import '../services/premium_service.dart';
import '../util/show_a_toast.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

/// The usage sheet: synced notes, OCR scans and exports against the free
/// limits, or "Unlimited" for Pro. Refresh pulls the counts from the server;
/// a long press reconciles the synced-note count.
class UsageStatsBottomSheet extends StatefulWidget {
  const UsageStatsBottomSheet({super.key});

  /// Presents the sheet as a Sketchbook bottom sheet.
  static Future<void> show(BuildContext context) => showSketchSheet<void>(
        context: context,
        builder: (_) => const UsageStatsBottomSheet(),
      );

  @override
  State<UsageStatsBottomSheet> createState() => _UsageStatsBottomSheetState();
}

class _UsageStatsBottomSheetState extends State<UsageStatsBottomSheet> {
  bool _isRefreshing = false;
  final _premiumService = PremiumService();

  @override
  void initState() {
    super.initState();
    // Listen to premium service changes
    _premiumService.addListener(_onPremiumServiceChanged);
  }

  @override
  void dispose() {
    _premiumService.removeListener(_onPremiumServiceChanged);
    super.dispose();
  }

  void _onPremiumServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshUsageStats() async {
    setState(() => _isRefreshing = true);
    try {
      await _premiumService.fetchUsageStatsFromBackend();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _reconcileUsageStats(BuildContext context) async {
    setState(() => _isRefreshing = true);
    final l10n = AppL10n.of(context);
    try {
      final result = await _premiumService.reconcileUsageWithBackend();

      if (context.mounted && result != null) {
        final reconciled = result['reconciled'] as bool;
        final oldCount = result['old_count'] as int;
        final newCount = result['new_count'] as int;

        if (reconciled) {
          showSuccessToast(
            context: context,
            title: l10n.stUsageTitle,
            description: l10n.stUsageReconciled(oldCount, newCount),
          );
        } else {
          showInfoToast(
            context: context,
            title: l10n.stUsageTitle,
            description: l10n.stUsageInSync(newCount),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        showErrorToast(
          context: context,
          title: l10n.setErrorTitle,
          description: l10n.usageReconcileFailed(e.toString()),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final t = context.type;
    final s = context.sketch;
    final isPremium = _premiumService.isPremium;

    final refresh = Tooltip(
      message: l10n.usageRefreshHint,
      child: CircleIconButton(
        icon: Icons.refresh_rounded,
        semanticLabel: l10n.usageRefreshHint,
        onPressed: _isRefreshing ? null : _refreshUsageStats,
        onLongPress:
            _isRefreshing ? null : () => _reconcileUsageStats(context),
        child: _isRefreshing
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: s.ink),
              )
            : null,
      ),
    );

    return SketchSheet(
      titleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.stUsageTitle, style: t.sheetTitle),
          ),
          const SizedBox(height: 4),
          Text(
            isPremium ? l10n.drawerProPlan : l10n.drawerFreePlan,
            style: t.bodySmall,
          ),
        ],
      ),
      action: refresh,
      footer: isPremium ? null : const _UpgradeButton(),
      child: isPremium
          ? const _PremiumUnlimitedCard()
          : SketchGroup(
              margin: EdgeInsets.zero,
              children: [
                _UsageRow(
                  title: l10n.stSyncedNotes,
                  current: _premiumService.getSyncedNotesCount(),
                  limit: PremiumLimits.maxSyncedNotesForFree,
                ),
                _UsageRow(
                  title: l10n.stOcrScans,
                  current: _premiumService.getOcrScansThisMonth(),
                  limit: PremiumLimits.maxOcrScansPerMonthForFree,
                  resetsMonthly: true,
                ),
                _UsageRow(
                  title: l10n.stExports,
                  current: _premiumService.getExportsThisMonth(),
                  limit: PremiumLimits.maxExportsPerMonthForFree,
                  resetsMonthly: true,
                ),
              ],
            ),
    );
  }
}

/// Premium unlimited card
class _PremiumUnlimitedCard extends StatelessWidget {
  const _PremiumUnlimitedCard();

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final l10n = AppL10n.of(context);
    return SketchCard(
      pastel: SketchPastels.lavender,
      radius: SketchRadius.group,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const StickerTile(
            color: SketchPastels.yellow,
            size: 52,
            angle: -8,
            icon: Icons.all_inclusive_rounded,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.usageUnlimitedEverything,
                  style: t.cardTitleLarge
                      .copyWith(color: SketchPastels.onPastel),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.usageUnlimitedBody,
                  style: t.caption.copyWith(color: SketchPastels.onPastel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One usage row: label, "used / limit", a bar and what is left.
class _UsageRow extends StatelessWidget {
  final String title;
  final int current;
  final int limit;
  final bool resetsMonthly;

  const _UsageRow({
    required this.title,
    required this.current,
    required this.limit,
    this.resetsMonthly = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final s = context.sketch;
    final l10n = AppL10n.of(context);
    final progress = limit > 0 ? (current / limit).clamp(0.0, 1.0) : 0.0;
    final remaining = limit - current;
    final isExceeded = remaining <= 0;

    final status = isExceeded
        ? l10n.usageLimitReached
        : resetsMonthly
            ? '${l10n.stRemaining(remaining)} · ${l10n.usageResetsMonthly}'
            : l10n.stRemaining(remaining);

    return Semantics(
      container: true,
      label: '${l10n.stUsageSemantic(title, current, limit)}. $status',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: t.body)),
                  Text.rich(TextSpan(children: [
                    TextSpan(
                      text: '$current',
                      style: t.cardTitle.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isExceeded ? SketchFunctional.error : s.ink,
                      ),
                    ),
                    TextSpan(
                      text: ' ${l10n.stUsageLimitSuffix(limit)}',
                      style: t.chip.copyWith(color: s.muted),
                    ),
                  ])),
                ],
              ),
              const SizedBox(height: 10),
              UsageBar(
                fraction: progress,
                fill: isExceeded ? SketchFunctional.error : null,
              ),
              const SizedBox(height: 8),
              Text(
                status,
                style: t.caption.copyWith(
                  color: isExceeded ? SketchFunctional.error : s.muted,
                  fontWeight: isExceeded ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Upgrade button
class _UpgradeButton extends StatelessWidget {
  const _UpgradeButton();

  @override
  Widget build(BuildContext context) {
    return PillButton(
      label: AppL10n.of(context).usageUpgradeToPremium,
      icon: Icons.workspace_premium_rounded,
      onPressed: () {
        // This sheet is presented with showModalBottomSheet, so it is a
        // Navigator route — not a GoRouter one. context.pop() asks GoRouter
        // to pop its OWN stack instead: with StatefulShellRoute.indexedStack
        // in the tree that walks into ShellRouteMatch and dereferences
        // `walker.navigatorKey.currentState!` on a branch navigator that is
        // not currently mounted, throwing "Null check operator used on a
        // null value" (go_router delegate.dart:126).
        //
        // Resolve the router BEFORE popping: afterwards this element is
        // deactivated and looking anything up from its context is unsafe.
        final router = GoRouter.of(context);
        Navigator.of(context).pop();
        router.push('/subscription');
      },
    );
  }
}
