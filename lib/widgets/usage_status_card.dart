import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:go_router/go_router.dart';
import '../constants/premium_limits.dart';
import '../screens/subscription_screen.dart';
import '../services/premium_service.dart';

/// Card showing current usage limits and premium status
class UsageStatusCard extends StatelessWidget {
  final int syncedNotes;
  final int ocrScansUsed;
  final int exportsUsed;
  final bool isPremium;
  final VoidCallback? onUpgrade;

  const UsageStatusCard({
    super.key,
    required this.syncedNotes,
    required this.ocrScansUsed,
    required this.exportsUsed,
    required this.isPremium,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (isPremium) {
      return _buildPremiumCard(context, theme, cs);
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Symbols.monitoring,
                color: cs.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Usage This Month',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onUpgrade ?? () => context.push(SubscriptionScreen.kRouteName),
                icon: const Icon(Symbols.workspace_premium, size: 18),
                label: const Text('Upgrade'),
                style: TextButton.styleFrom(
                  foregroundColor: cs.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Usage bars
          _UsageBar(
            icon: Symbols.cloud_sync,
            label: 'Synced Notes',
            current: syncedNotes,
            max: PremiumLimits.maxSyncedNotesForFree,
            color: cs.primary,
          ),

          const SizedBox(height: 12),

          _UsageBar(
            icon: Symbols.document_scanner,
            label: 'OCR Scans',
            current: ocrScansUsed,
            max: PremiumLimits.maxOcrScansPerMonthForFree,
            color: cs.secondary,
          ),

          const SizedBox(height: 12),

          _UsageBar(
            icon: Symbols.download,
            label: 'Exports',
            current: exportsUsed,
            max: PremiumLimits.maxExportsPerMonthForFree,
            color: cs.tertiary,
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumCard(BuildContext context, ThemeData theme, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.1),
            cs.secondary.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Symbols.workspace_premium,
              color: cs.primary,
              size: 28,
              fill: 1,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Premium Active',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Unlimited notes, OCR, and exports',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Symbols.check_circle,
            color: cs.primary,
            size: 28,
            fill: 1,
          ),
        ],
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  final IconData icon;
  final String label;
  final int current;
  final int max;
  final Color color;

  const _UsageBar({
    required this.icon,
    required this.label,
    required this.current,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final progress = (current / max).clamp(0.0, 1.0);
    final isNearLimit = progress >= 0.8;
    final isAtLimit = current >= max;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              '$current / $max',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isAtLimit
                    ? cs.error
                    : isNearLimit
                        ? cs.tertiary
                        : cs.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: cs.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              isAtLimit
                  ? cs.error
                  : isNearLimit
                      ? cs.tertiary
                      : color,
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

/// Helper widget to load and display usage status
class UsageStatusLoader extends StatelessWidget {
  const UsageStatusLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: PremiumService().fetchUsageStatsFromBackend(),
      builder: (context, snapshot) {
        final premiumService = PremiumService();

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final stats = snapshot.data;
        if (stats == null) {
          // Show cached/default data
          return UsageStatusCard(
            syncedNotes: 0,
            ocrScansUsed: 0,
            exportsUsed: 0,
            isPremium: premiumService.isPremium,
          );
        }

        return UsageStatusCard(
          syncedNotes: stats['synced_notes']?['current'] ?? 0,
          ocrScansUsed: stats['ocr_scans']?['current'] ?? 0,
          exportsUsed: stats['exports']?['current'] ?? 0,
          isPremium: premiumService.isPremium,
        );
      },
    );
  }
}
