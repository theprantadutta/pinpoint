import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/premium_limits.dart';
import '../design_system/design_system.dart';
import '../screens/subscription_screen.dart';
import '../services/premium_service.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

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
    final t = context.type;
    final l10n = AppL10n.of(context);

    if (isPremium) return _buildPremiumCard(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SketchCard(
        radius: SketchRadius.group,
        padding: const EdgeInsets.all(SketchSpace.cardPadLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.usageThisMonth, style: t.cardTitleLarge),
                ),
                SketchTextAction(
                  label: l10n.usageUpgrade,
                  onTap: onUpgrade ??
                      () => context.push(SubscriptionScreen.kRouteName),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _UsageBar(
              label: l10n.stSyncedNotes,
              current: syncedNotes,
              max: PremiumLimits.maxSyncedNotesForFree,
            ),
            const SizedBox(height: 12),
            _UsageBar(
              label: l10n.stOcrScans,
              current: ocrScansUsed,
              max: PremiumLimits.maxOcrScansPerMonthForFree,
            ),
            const SizedBox(height: 12),
            _UsageBar(
              label: l10n.stExports,
              current: exportsUsed,
              max: PremiumLimits.maxExportsPerMonthForFree,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumCard(BuildContext context) {
    final t = context.type;
    final l10n = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SketchCard(
        pastel: SketchPastels.lavender,
        radius: SketchRadius.group,
        padding: const EdgeInsets.all(SketchSpace.cardPadLg),
        child: Row(
          children: [
            const StickerTile(
              color: SketchPastels.yellow,
              size: 44,
              angle: -8,
              icon: Icons.workspace_premium_rounded,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.usagePremiumActive,
                      style: t.cardTitleLarge
                          .copyWith(color: SketchPastels.onPastel)),
                  const SizedBox(height: 2),
                  Text(l10n.usagePremiumBody,
                      style:
                          t.caption.copyWith(color: SketchPastels.onPastel)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  final String label;
  final int current;
  final int max;

  const _UsageBar({
    required this.label,
    required this.current,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final s = context.sketch;
    final l10n = AppL10n.of(context);
    final atLimit = current >= max;

    return Semantics(
      label: l10n.stUsageSemantic(label, current, max),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: t.chip)),
                Text(
                  '$current ${l10n.stUsageLimitSuffix(max)}',
                  style: t.chip.copyWith(
                    color: atLimit ? SketchFunctional.error : s.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            UsageBar(
              fraction: max == 0 ? 0 : current / max,
              fill: atLimit ? SketchFunctional.error : null,
            ),
          ],
        ),
      ),
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
