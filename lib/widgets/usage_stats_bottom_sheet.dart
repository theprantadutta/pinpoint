import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../design_system/design_system.dart';
import '../services/premium_service.dart';

/// Bottom sheet displaying comprehensive usage statistics
class UsageStatsBottomSheet extends StatefulWidget {
  const UsageStatsBottomSheet({super.key});

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
    try {
      final result = await _premiumService.reconcileUsageWithBackend();

      if (mounted && result != null) {
        final reconciled = result['reconciled'] as bool;
        final oldCount = result['old_count'] as int;
        final newCount = result['new_count'] as int;

        if (reconciled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '✅ Reconciled: Updated from $oldCount to $newCount notes'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Already in sync: $newCount notes'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reconcile: $e'),
            backgroundColor: Colors.red,
          ),
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isPremium = _premiumService.isPremium;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? PinpointGradients.crescentInk
            : PinpointGradients.oceanQuartz,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.analytics_outlined,
                      color: cs.primary,
                      size: 24,
                    ),
                  )
                      .animate()
                      .scale(
                        duration: 500.ms,
                        curve: Curves.elasticOut,
                      )
                      .shimmer(
                          duration: 1500.ms,
                          color: cs.primary.withValues(alpha: 0.3)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Usage Statistics',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? PinpointColors.darkTextPrimary
                                : PinpointColors.lightTextPrimary,
                          ),
                        ),
                        Text(
                          _premiumService.getSubscriptionStatusText(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isPremium
                                ? cs.primary
                                : (isDark
                                    ? PinpointColors.darkTextSecondary
                                    : PinpointColors.lightTextSecondary),
                            fontWeight: isPremium ? FontWeight.w600 : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Refresh button (long-press to reconcile)
                  Tooltip(
                    message: 'Tap to refresh\nLong-press to reconcile',
                    child: InkWell(
                      onTap: _isRefreshing ? null : _refreshUsageStats,
                      onLongPress: _isRefreshing
                          ? null
                          : () => _reconcileUsageStats(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _isRefreshing
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: cs.primary,
                                ),
                              )
                            : Icon(
                                Icons.refresh,
                                color: cs.primary,
                              ),
                      ),
                    ),
                  ),
                ],
              )
                  .animate(delay: 100.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0),

              const SizedBox(height: 32),

              // Usage Cards
              if (isPremium)
                _PremiumUnlimitedCard()
                    .animate(delay: 200.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.2, end: 0)
              else ...[
                // Synced Notes
                _UsageCard(
                  icon: Icons.cloud_sync,
                  title: 'Synced Notes',
                  current: _premiumService.getSyncedNotesCount(),
                  limit: 50,
                  color: cs.primary,
                )
                    .animate(delay: 200.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.2, end: 0),

                const SizedBox(height: 16),

                // OCR Scans
                _UsageCard(
                  icon: Icons.document_scanner,
                  title: 'OCR Scans',
                  current: _premiumService.getOcrScansThisMonth(),
                  limit: 20,
                  color: cs.secondary,
                  resetsMonthly: true,
                )
                    .animate(delay: 300.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.2, end: 0),

                const SizedBox(height: 16),

                // Exports
                _UsageCard(
                  icon: Icons.download,
                  title: 'Exports',
                  current: _premiumService.getExportsThisMonth(),
                  limit: 10,
                  color: cs.tertiary,
                  resetsMonthly: true,
                )
                    .animate(delay: 400.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.2, end: 0),

                const SizedBox(height: 24),

                // Upgrade CTA
                _UpgradeButton()
                    .animate(delay: 500.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.2, end: 0),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Premium unlimited card
class _PremiumUnlimitedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.2),
            cs.primary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.all_inclusive,
            size: 48,
            color: cs.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Unlimited Everything',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark
                  ? PinpointColors.darkTextPrimary
                  : PinpointColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have unlimited access to all features',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? PinpointColors.darkTextSecondary
                  : PinpointColors.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Individual usage card
class _UsageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final int current;
  final int limit;
  final Color color;
  final bool resetsMonthly;

  const _UsageCard({
    required this.icon,
    required this.title,
    required this.current,
    required this.limit,
    required this.color,
    this.resetsMonthly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = limit > 0 ? (current / limit).clamp(0.0, 1.0) : 0.0;
    final remaining = limit - current;
    final isWarning = remaining <= 5 && remaining > 0;
    final isExceeded = remaining <= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExceeded
              ? Colors.red.withValues(alpha: 0.3)
              : (isWarning
                  ? Colors.orange.withValues(alpha: 0.3)
                  : color.withValues(alpha: 0.1)),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? PinpointColors.darkTextPrimary
                            : PinpointColors.lightTextPrimary,
                      ),
                    ),
                    if (resetsMonthly)
                      Text(
                        'Resets monthly',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? PinpointColors.darkTextTertiary
                              : PinpointColors.lightTextTertiary,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '$current / $limit',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isExceeded
                      ? Colors.red
                      : (isWarning
                          ? Colors.orange
                          : (isDark
                              ? PinpointColors.darkTextPrimary
                              : PinpointColors.lightTextPrimary)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(
                isExceeded ? Colors.red : (isWarning ? Colors.orange : color),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Status text
          Text(
            isExceeded
                ? 'Limit reached - Upgrade to continue'
                : (isWarning
                    ? '$remaining remaining - Running low'
                    : '$remaining remaining'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: isExceeded
                  ? Colors.red
                  : (isWarning
                      ? Colors.orange
                      : (isDark
                          ? PinpointColors.darkTextSecondary
                          : PinpointColors.lightTextSecondary)),
              fontWeight: isExceeded || isWarning ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Upgrade button
class _UpgradeButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {
          context.pop();
          context.push('/subscription');
        },
        icon: const Icon(Icons.workspace_premium),
        label: const Text('Upgrade to Premium'),
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
