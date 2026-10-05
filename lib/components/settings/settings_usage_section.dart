import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../constants/premium_limits.dart';
import '../../design_system/design_system.dart';
import '../../navigation/app_navigation.dart';
import '../../screens/subscription_screen.dart';
import '../../services/premium_service.dart';
import '../../services/subscription_manager.dart';
import '../../util/localized_dates.dart';
import '../../util/show_a_toast.dart';
import '../../widgets/grace_period_banner.dart';
import '../../widgets/usage_stats_bottom_sheet.dart';
import 'settings_format.dart';

/// One usage card: "Synced notes", "38 / 50" and a 6px bar. Pro users see
/// "Unlimited" and no bar.
class UsageCountCard extends StatelessWidget {
  const UsageCountCard({
    super.key,
    required this.label,
    required this.used,
    required this.limit,
    this.unlimited = false,
    this.onTap,
  });

  final String label;
  final int used;
  final int limit;
  final bool unlimited;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final l10n = AppL10n.of(context);
    final big = t.cardTitle.copyWith(fontSize: 20, fontWeight: FontWeight.w800);

    return SketchCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      semanticLabel: unlimited
          ? '$label: ${l10n.stUnlimited}'
          : l10n.stUsageSemantic(label, used, limit),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.caption.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (unlimited)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(l10n.stUnlimited, style: big),
              )
            else
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: '$used', style: big),
                  TextSpan(
                    text: ' ${l10n.stUsageLimitSuffix(limit)}',
                    style: t.chip.copyWith(fontSize: 14, color: s.muted),
                  ),
                ]),
                maxLines: 1,
              ),
            const SizedBox(height: 8),
            UsageBar(fraction: unlimited ? 1 : (limit == 0 ? 0 : used / limit)),
          ],
        ),
      ),
    );
  }
}

/// USAGE (synced notes and OCR scans, opening the usage sheet) and PLAN (the
/// upgrade banner for free users, plan and store management for Pro).
class SettingsUsageSection extends StatelessWidget {
  const SettingsUsageSection({super.key});

  String _planName(AppL10n l10n, SubscriptionManager m) {
    if (m.isInGracePeriod) return l10n.setPremiumGracePeriod;
    return switch (m.subscriptionType) {
      'monthly' => l10n.setPlanMonthly,
      'yearly' => l10n.setPlanYearly,
      'lifetime' => l10n.setPlanLifetime,
      _ => l10n.setPlanPremium,
    };
  }

  String _expiry(BuildContext context, SubscriptionManager m) {
    final l10n = AppL10n.of(context);
    if (m.isInGracePeriod) return l10n.setUpdatePaymentMethod;
    if (m.subscriptionType == 'lifetime') return l10n.subscriptionNeverExpires;
    final expiry = m.expirationDate;
    if (expiry == null) return '';
    final date = LocalizedDates.mediumDate(context, expiry);
    if (expiry.isBefore(DateTime.now()))
      return l10n.subscriptionExpiredOn(date);
    if (m.isCancelledButActive) {
      return l10n.subscriptionCancelledAccessUntil(date);
    }
    return l10n.subscriptionRenews(date);
  }

  void _openPaywall() {
    PinpointHaptics.medium();
    AppNavigation.router.push(SubscriptionScreen.kRouteName);
  }

  Future<void> _manage(BuildContext context) async {
    PinpointHaptics.medium();
    final l10n = AppL10n.of(context);
    final ok = await openManageSubscriptions();
    if (!ok && context.mounted) {
      showErrorToast(
        context: context,
        title: l10n.setErrorTitle,
        description: Platform.isIOS
            ? l10n.setCannotOpenAppStoreSubs
            : l10n.setCannotOpenPlaySubs,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final manager = context.watch<SubscriptionManager>();
    final premium = PremiumService();

    return ListenableBuilder(
      listenable: premium,
      builder: (context, _) {
        final isPro = manager.isPremium || premium.isPremium;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SketchOverline(l10n.setSectionUsage),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: SketchSpace.screenX),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: UsageCountCard(
                        label: l10n.stSyncedNotes,
                        used: premium.getSyncedNotesCount(),
                        limit: PremiumLimits.maxSyncedNotesForFree,
                        unlimited: isPro,
                        onTap: () => UsageStatsBottomSheet.show(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: UsageCountCard(
                        label: l10n.stOcrScans,
                        used: premium.getOcrScansThisMonth(),
                        limit: PremiumLimits.maxOcrScansPerMonthForFree,
                        unlimited: isPro,
                        onTap: () => UsageStatsBottomSheet.show(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SketchOverline(l10n.stSectionPlan),
            if (manager.isInGracePeriod)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: GracePeriodBanner(),
              ),
            if (!isPro)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: SketchSpace.screenX),
                child: UpgradeBanner(
                  title: l10n.drawerFreePlan,
                  message: l10n.stFreePlanBody,
                  actionLabel: l10n.usageUpgrade,
                  onAction: _openPaywall,
                ),
              )
            else
              SketchGroup(
                children: [
                  SketchRow(
                    label: _planName(l10n, manager),
                    subtitle: _expiry(context, manager).isEmpty
                        ? null
                        : _expiry(context, manager),
                    onTap: _openPaywall,
                    trailing: SketchTag(
                      label: l10n.drawerProBadge,
                      pastel: manager.isInGracePeriod
                          ? SketchPastels.yellow
                          : SketchPastels.lavender,
                    ),
                  ),
                  SketchRow(
                    label: l10n.stManageSubscription,
                    value: storeName,
                    onTap: () => _manage(context),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}
