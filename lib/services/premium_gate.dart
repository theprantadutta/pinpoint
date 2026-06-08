import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/subscription_screen.dart';
import 'premium_service.dart';

/// Lightweight gate for premium-only features (images, drawing, audio, etc.).
///
/// In the Keep clone, free users can see these entry points but tapping one
/// shows a short explainer and routes to the subscription screen. Full feature
/// implementation lands later — this just enforces the tier boundary in the UI.
class PremiumGate {
  PremiumGate._();

  /// Returns true if the user may use [feature] now. If not, shows a sheet and
  /// (optionally) routes to the subscription screen, returning false.
  static bool require(BuildContext context, String feature) {
    if (PremiumService().isPremium) return true;
    _showUpsell(context, feature);
    return false;
  }

  static void _showUpsell(BuildContext context, String feature) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, color: cs.primary),
                    const SizedBox(width: 10),
                    Text(
                      '$feature is a Premium feature',
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Upgrade to Pinpoint Premium to add ${feature.toLowerCase()} '
                  'to your notes, plus more power-user features.',
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      context.push(SubscriptionScreen.kRouteName);
                    },
                    child: const Text('See Premium'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
