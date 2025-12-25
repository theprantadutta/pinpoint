import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:provider/provider.dart';
import '../screens/subscription_screen.dart';
import '../services/subscription_manager.dart';

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

        return _GracePeriodBannerContent(
          daysRemaining: subscriptionManager.gracePeriodDaysRemaining,
        );
      },
    );
  }
}

class _GracePeriodBannerContent extends StatelessWidget {
  final int daysRemaining;

  const _GracePeriodBannerContent({
    required this.daysRemaining,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isUrgent = daysRemaining <= 3;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUrgent
              ? [
                  cs.error.withValues(alpha: 0.9),
                  cs.error.withValues(alpha: 0.7),
                ]
              : [
                  cs.tertiary.withValues(alpha: 0.9),
                  cs.tertiary.withValues(alpha: 0.7),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isUrgent ? cs.error : cs.tertiary).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push(SubscriptionScreen.kRouteName),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isUrgent ? Symbols.warning : Symbols.schedule,
                    color: Colors.white,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 12),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isUrgent
                            ? 'Subscription Expiring Soon!'
                            : 'Subscription Grace Period',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getMessage(daysRemaining),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow
                Icon(
                  Symbols.arrow_forward,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getMessage(int days) {
    if (days <= 0) {
      return 'Your premium access ends today. Renew now to keep your features.';
    } else if (days == 1) {
      return 'Your premium access ends tomorrow. Renew to keep your features.';
    } else if (days <= 3) {
      return 'Only $days days left! Renew now to avoid losing premium features.';
    } else {
      return 'You have $days days to renew your subscription.';
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
