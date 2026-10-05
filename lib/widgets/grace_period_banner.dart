import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../design_system/design_system.dart';
import '../screens/subscription_screen.dart';
import '../services/subscription_manager.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

/// A prominent banner shown when the user's subscription is in the grace period
class GracePeriodBanner extends StatelessWidget {
  const GracePeriodBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionManager>(
      builder: (context, subscriptionManager, child) {
        if (!subscriptionManager.isInGracePeriod) {
          return const SizedBox.shrink();
        }

        return GracePeriodBannerContent(
          daysRemaining: subscriptionManager.gracePeriodDaysRemaining,
        );
      },
    );
  }
}

/// The banner itself: a yellow pastel card, pink once three days or fewer
/// remain. Tapping it opens the paywall to renew.
class GracePeriodBannerContent extends StatelessWidget {
  final int daysRemaining;
  final VoidCallback? onTap;

  const GracePeriodBannerContent({
    super.key,
    required this.daysRemaining,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final isUrgent = daysRemaining <= 3;
    final l10n = AppL10n.of(context);
    final title = isUrgent ? l10n.graceExpiringSoon : l10n.graceperiod;
    final message = _getMessage(context, daysRemaining);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SketchSpace.screenX),
      child: SketchCard(
        pastel: isUrgent ? SketchPastels.pink : SketchPastels.yellow,
        radius: SketchRadius.group,
        padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 10, 14),
        semanticLabel: '$title. $message',
        onTap: onTap ?? () => context.push(SubscriptionScreen.kRouteName),
        child: ExcludeSemantics(
          child: Row(
            children: [
              Icon(
                isUrgent
                    ? Icons.warning_amber_rounded
                    : Icons.schedule_rounded,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: t.body.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: SketchPastels.onPastel,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: t.caption.copyWith(color: SketchPastels.onPastel),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                textDirection: Directionality.of(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMessage(BuildContext context, int days) {
    if (days <= 0) {
      return AppL10n.of(context).graceEndsToday;
    } else if (days == 1) {
      return AppL10n.of(context).graceEndsTomorrow;
    } else if (days <= 3) {
      return AppL10n.of(context).graceDaysUrgent(days);
    } else {
      return AppL10n.of(context).graceDaysRemaining(days);
    }
  }
}

/// Extension to get grace period days remaining
extension GracePeriodDays on SubscriptionManager {
  int get gracePeriodDaysRemaining {
    if (!isInGracePeriod || gracePeriodEndsAt == null) {
      return 0;
    }
    final now = DateTime.now();
    final remaining = gracePeriodEndsAt!.difference(now).inDays;
    return remaining > 0 ? remaining : 0;
  }
}
