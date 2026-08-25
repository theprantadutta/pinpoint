import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design_system/design_system.dart';
import '../generated/l10n/app_localizations.dart';
import '../services/refresh_rate_controller.dart';

/// Display settings — how smoothly Pinpoint moves, and what the panel is
/// actually doing about it.
///
/// The live readout is the point of the screen. "Smooth motion" is a promise
/// the app cannot keep on its own: the OS throttles the refresh rate in battery
/// saver and when the device is warm, whatever we request. Showing the real
/// current rate, plus a plain-language reason when it is being held down, is
/// what stops the toggle looking broken.
class DisplayScreen extends StatefulWidget {
  static const String kRouteName = '/display';

  const DisplayScreen({super.key});

  @override
  State<DisplayScreen> createState() => _DisplayScreenState();
}

class _DisplayScreenState extends State<DisplayScreen> {
  @override
  void initState() {
    super.initState();
    // Re-read the platform when the screen opens so the number on screen is
    // current rather than whatever was cached at startup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RefreshRateController>().refreshInfo();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppL10n.of(context);
    final controller = context.watch<RefreshRateController>();
    final info = controller.info;

    return GradientScaffold(
      appBar: GlassAppBar(
        title: Row(
          children: [
            Icon(Icons.monitor_rounded, color: cs.primary, size: 20),
            const SizedBox(width: 8),
            Text(l10n.displayTitle),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _RateCard(controller: controller),
          const SizedBox(height: 16),

          // Only offered when the hardware has more than one rate to pick
          // from — a single-rate panel has nothing to unlock.
          if (controller.deviceSupportsHighRate)
            _SmoothMotionTile(
              value: controller.isEnabled,
              onChanged: (v) =>
                  context.read<RefreshRateController>().setEnabled(v),
            )
          else if (controller.isLoaded && info != null)
            _Note(
              icon: Icons.info_outline_rounded,
              color: cs.primary,
              text: l10n.displaySingleRateNote,
            ),

          if (controller.throttledByBattery) ...[
            const SizedBox(height: 12),
            _Note(
              icon: Icons.battery_saver_rounded,
              color: PinpointColors.warning,
              text: l10n.displayBatterySaverNote,
            ),
          ],
          if (controller.throttledByHeat) ...[
            const SizedBox(height: 12),
            _Note(
              icon: Icons.thermostat_rounded,
              color: PinpointColors.warning,
              text: l10n.displayThermalNote,
            ),
          ],

          if (info != null && info.supportedRates.length > 1) ...[
            const SizedBox(height: 28),
            Text(
              l10n.displaySupportedRates.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _SupportedRates(
              rates: info.supportedRates,
              currentRate: info.currentRate,
            ),
          ],

          const SizedBox(height: 24),
          Text(
            l10n.displayFooterNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Formats a rate for display. Panels commonly report 60.000004 Hz, so the
/// fractional part is dropped unless it is genuinely meaningful.
String _formatRate(BuildContext context, double rate) {
  final rounded = rate.roundToDouble();
  final text = (rate - rounded).abs() < 0.5
      ? rounded.toStringAsFixed(0)
      : rate.toStringAsFixed(1);
  return AppL10n.of(context).displayRateUnit(text);
}

// ─── Live readout ───────────────────────────────────────────────────

class _RateCard extends StatelessWidget {
  const _RateCard({required this.controller});

  final RefreshRateController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppL10n.of(context);
    final info = controller.info;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.14),
            cs.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.displayCurrentRate.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.primary,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  info == null
                      ? l10n.displayUnknownRate
                      : _formatRate(context, info.currentRate),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          if (info != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  l10n.displayMaxRate,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatRate(context, info.maxRate),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Toggle ─────────────────────────────────────────────────────────

class _SmoothMotionTile extends StatelessWidget {
  const _SmoothMotionTile({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppL10n.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? cs.surface.withValues(alpha: 0.7)
            : cs.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.2 : 0.05,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            PinpointHaptics.light();
            onChanged(!value);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.animation_rounded, color: cs.primary, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.displaySmoothMotion,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.displaySmoothMotionSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: value,
                  onChanged: (v) {
                    PinpointHaptics.light();
                    onChanged(v);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Supported rates ────────────────────────────────────────────────

class _SupportedRates extends StatelessWidget {
  const _SupportedRates({required this.rates, required this.currentRate});

  final List<double> rates;
  final double currentRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Ascending and de-duplicated: OEMs frequently report the same rate more
    // than once for different resolutions.
    final unique = rates.map((r) => r.roundToDouble()).toSet().toList()..sort();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: unique.map((rate) {
        final isCurrent = (rate - currentRate).abs() < 1.0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isCurrent
                ? cs.primary.withValues(alpha: 0.14)
                : cs.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCurrent
                  ? cs.primary.withValues(alpha: 0.45)
                  : cs.outline.withValues(alpha: 0.12),
              width: isCurrent ? 1.5 : 1,
            ),
          ),
          child: Text(
            _formatRate(context, rate),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              color: isCurrent ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Inline note ────────────────────────────────────────────────────

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
