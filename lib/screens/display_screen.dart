import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design_system/design_system.dart';
import '../generated/l10n/app_localizations.dart';
import '../services/refresh_rate_controller.dart';
import '../services/theme_controller.dart';

/// Display settings — the background doodles, how smoothly Pinpoint moves,
/// and what the panel is actually doing about it.
///
/// The live readout is the point of the motion section. "Smooth motion" is a
/// promise the app cannot keep on its own: the OS throttles the refresh rate
/// in battery saver and when the device is warm, whatever we request. Showing
/// the real current rate, plus a plain-language reason when it is being held
/// down, is what stops the toggle looking broken.
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
    final l10n = AppL10n.of(context);
    final t = context.type;
    final controller = context.watch<RefreshRateController>();
    final theme = context.watch<ThemeController>();
    final info = controller.info;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SketchScaffold(
      title: l10n.displayTitle,
      doodleTop: DoodleBackground.settingsTop,
      body: ListView(
        padding: EdgeInsets.only(top: 6, bottom: 40 + bottom),
        children: [
          SketchOverline(l10n.stSectionLooks),
          SketchGroup(
            children: [
              SketchRow(
                label: l10n.stBackgroundDoodles,
                subtitle: l10n.stBackgroundDoodlesSubtitle,
                onTap: () => context
                    .read<ThemeController>()
                    .setDoodlesEnabled(!theme.doodlesEnabled),
                trailing: SketchToggle(
                  value: theme.doodlesEnabled,
                  semanticLabel: l10n.stBackgroundDoodles,
                  onChanged: (v) =>
                      context.read<ThemeController>().setDoodlesEnabled(v),
                ),
              ),
            ],
          ),
          SketchOverline(l10n.stSectionMotion),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: SketchSpace.screenX),
            child: _RateCard(controller: controller),
          ),
          const SizedBox(height: 12),

          // Only offered when the hardware has more than one rate to pick
          // from — a single-rate panel has nothing to unlock.
          if (controller.deviceSupportsHighRate)
            SketchGroup(
              children: [
                SketchRow(
                  label: l10n.displaySmoothMotion,
                  subtitle: l10n.displaySmoothMotionSubtitle,
                  onTap: () {
                    PinpointHaptics.light();
                    context
                        .read<RefreshRateController>()
                        .setEnabled(!controller.isEnabled);
                  },
                  trailing: SketchToggle(
                    value: controller.isEnabled,
                    semanticLabel: l10n.displaySmoothMotion,
                    onChanged: (v) =>
                        context.read<RefreshRateController>().setEnabled(v),
                  ),
                ),
              ],
            )
          else if (controller.isLoaded && info != null)
            _Note(
              icon: Icons.info_outline_rounded,
              pastel: SketchPastels.sky,
              text: l10n.displaySingleRateNote,
            ),

          if (controller.throttledByBattery) ...[
            const SizedBox(height: 12),
            _Note(
              icon: Icons.battery_saver_rounded,
              pastel: SketchPastels.yellow,
              text: l10n.displayBatterySaverNote,
            ),
          ],
          if (controller.throttledByHeat) ...[
            const SizedBox(height: 12),
            _Note(
              icon: Icons.thermostat_rounded,
              pastel: SketchPastels.yellow,
              text: l10n.displayThermalNote,
            ),
          ],

          if (info != null && info.supportedRates.length > 1) ...[
            SketchOverline(l10n.displaySupportedRates),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: SketchSpace.screenX),
              child: _SupportedRates(
                rates: info.supportedRates,
                currentRate: info.currentRate,
              ),
            ),
          ],

          Padding(
            padding: const EdgeInsets.fromLTRB(
                SketchSpace.screenX + 4, 20, SketchSpace.screenX + 4, 0),
            child: Text(l10n.displayFooterNote, style: t.caption),
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
    final t = context.type;
    final l10n = AppL10n.of(context);
    final info = controller.info;

    return SketchCard(
      pastel: SketchPastels.mint,
      radius: SketchRadius.group,
      padding: const EdgeInsets.all(SketchSpace.cardPadLg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.displayCurrentRate.toUpperCase(),
                  style:
                      t.overline.copyWith(color: SketchPastels.onPastel),
                ),
                const SizedBox(height: 6),
                Text(
                  info == null
                      ? l10n.displayUnknownRate
                      : _formatRate(context, info.currentRate),
                  style: t.displayNumber
                      .copyWith(fontSize: 34, color: SketchPastels.onPastel),
                ),
              ],
            ),
          ),
          if (info != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(l10n.displayMaxRate,
                    style: t.caption.copyWith(color: SketchPastels.onPastel)),
                const SizedBox(height: 2),
                Text(
                  _formatRate(context, info.maxRate),
                  style: t.sectionTitle
                      .copyWith(color: SketchPastels.onPastel),
                ),
              ],
            ),
        ],
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
    // Ascending and de-duplicated: OEMs frequently report the same rate more
    // than once for different resolutions.
    final unique = rates.map((r) => r.roundToDouble()).toSet().toList()..sort();

    return Wrap(
      spacing: SketchSpace.chip,
      runSpacing: SketchSpace.chip,
      children: [
        for (final rate in unique)
          SketchChip(
            label: _formatRate(context, rate),
            selected: (rate - currentRate).abs() < 1.0,
          ),
      ],
    );
  }
}

// ─── Inline note ────────────────────────────────────────────────────

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.pastel, required this.text});

  final IconData icon;
  final Color pastel;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SketchSpace.screenX),
      child: SketchCard(
        pastel: pastel,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: context.type.bodySmall
                    .copyWith(color: SketchPastels.onPastel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
