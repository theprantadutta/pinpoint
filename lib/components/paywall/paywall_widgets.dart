import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../../constants/premium_limits.dart';
import '../../design_system/design_system.dart';

// ─── Sticker collage ────────────────────────────────────────────────

/// The paywall's sticker collage (h170): a big yellow ∞, a lavender star, a
/// mint check, a pink "Aa" and a sky "OCR". On first build the stickers drop
/// in with a staggered spring, 40ms apart; under reduced motion they are
/// simply there.
///
/// ∞, ★ and ✓ are icons — the bundled UI fonts have none of those glyphs.
class PaywallStickerCollage extends StatefulWidget {
  const PaywallStickerCollage({super.key, this.animate = true});

  /// Set false for goldens.
  final bool animate;

  @override
  State<PaywallStickerCollage> createState() => _PaywallStickerCollageState();
}

class _PaywallStickerCollageState extends State<PaywallStickerCollage>
    with SingleTickerProviderStateMixin {
  static const int _count = 5;
  static const int _staggerMs = 40;
  static const int _eachMs = 600;

  late final AnimationController _drop = AnimationController(
    vsync: this,
    duration: const Duration(
        milliseconds: _eachMs + _staggerMs * (_count - 1)),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.animate && SketchMotion.enabled(context)) {
      _drop.forward();
    } else {
      _drop.value = 1;
    }
  }

  @override
  void dispose() {
    _drop.dispose();
    super.dispose();
  }

  Animation<double> _slot(int i) {
    final total = _drop.duration!.inMilliseconds;
    final start = i * _staggerMs / total;
    final end = (i * _staggerMs + _eachMs) / total;
    return CurvedAnimation(
      parent: _drop,
      curve: Interval(start, end, curve: const _StickerSpring()),
    );
  }

  Widget _dropIn(int i, Widget child) {
    final a = _slot(i);
    return AnimatedBuilder(
      animation: a,
      builder: (_, c) {
        final v = a.value;
        return Opacity(
          opacity: (v * 2).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * -48),
            child: Transform.scale(scale: 0.6 + 0.4 * v, child: c),
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    TextStyle glyph(double size) => t.cardTitle
        .copyWith(fontSize: size, fontWeight: FontWeight.w800, height: 1);

    // Coordinates from the mock, inside a 350×170 box.
    final stickers = <(double, double, Widget)>[
      (
        112,
        20,
        const StickerTile(
          color: SketchPastels.yellow,
          size: 112,
          angle: -8,
          shadowOffset: 4,
          child: Icon(Icons.all_inclusive_rounded,
              size: 62, color: SketchPastels.onPastel),
        ),
      ),
      (
        22,
        54,
        const StickerTile(
          color: SketchPastels.lavender,
          size: 62,
          angle: 10,
          radiusFactor: 0.29,
          icon: Icons.star_rounded,
        ),
      ),
      (
        250,
        12,
        const StickerTile(
          color: SketchPastels.mint,
          size: 56,
          angle: 12,
          icon: Icons.check_rounded,
        ),
      ),
      (
        262,
        96,
        StickerTile(
          color: SketchPastels.pink,
          size: 60,
          height: 46,
          angle: -6,
          glyph: 'Aa',
          glyphStyle: glyph(18),
        ),
      ),
      (
        58,
        8,
        StickerTile(
          color: SketchPastels.sky,
          size: 44,
          height: 30,
          angle: -12,
          shadowOffset: 0,
          glyph: 'OCR',
          glyphStyle: glyph(10),
        ),
      ),
    ];

    return ExcludeSemantics(
      child: SizedBox(
        height: 170,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 350,
            height: 170,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < stickers.length; i++)
                  Positioned(
                    left: stickers[i].$1,
                    top: stickers[i].$2,
                    child: _dropIn(i, stickers[i].$3),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An under-damped spring (≈19% overshoot) settled within the interval.
class _StickerSpring extends Curve {
  const _StickerSpring();

  static final SpringSimulation _sim = SpringSimulation(
    const SpringDescription(mass: 1, stiffness: 300, damping: 16),
    0,
    1,
    0,
  );

  @override
  double transformInternal(double t) => _sim.x(t * 0.6);
}

// ─── Limits table ───────────────────────────────────────────────────

/// One row of the limits table: the free allowance struck through, then the
/// Pro value (∞ unless [pro] is given).
class PaywallLimitRow {
  const PaywallLimitRow({required this.label, required this.free, this.pro});

  final String label;
  final String free;

  /// Null means unlimited (drawn as ∞).
  final String? pro;
}

/// The rows, built from [PremiumLimits] so the paywall can never quote a
/// number the app doesn't enforce.
List<PaywallLimitRow> paywallLimitRows(AppL10n l10n) => [
      PaywallLimitRow(
        label: l10n.stSyncedNotes,
        free: '${PremiumLimits.maxSyncedNotesForFree}',
      ),
      PaywallLimitRow(
        label: l10n.pwRowFolders,
        free: '${PremiumLimits.maxFoldersForFree}',
      ),
      PaywallLimitRow(
        label: l10n.stOcrScans,
        free: l10n.pwPerMonth(PremiumLimits.maxOcrScansPerMonthForFree),
      ),
      PaywallLimitRow(
        label: l10n.pwRowExports,
        free: l10n.pwPerMonth(PremiumLimits.maxExportsPerMonthForFree),
      ),
      PaywallLimitRow(
        label: l10n.pwRowVoice,
        free: l10n
            .pwMinutes(PremiumLimits.maxVoiceRecordingDurationForFree ~/ 60),
      ),
      PaywallLimitRow(
        label: l10n.pwRowAccents,
        free: '${PremiumLimits.maxThemeColorsForFree}',
        pro: l10n.pwAll(PremiumLimits.totalThemeColors),
      ),
    ];

class PaywallLimitsTable extends StatelessWidget {
  const PaywallLimitsTable({super.key, required this.rows});

  final List<PaywallLimitRow> rows;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final l10n = AppL10n.of(context);

    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      if (i > 0) {
        children.add(Container(height: SketchStroke.outline, color: s.hairline));
      }
      children.add(Semantics(
        container: true,
        label: l10n.pwRowSemantic(r.label, r.free, r.pro ?? l10n.stUnlimited),
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Row(
              children: [
                Expanded(
                  child: Text(r.label,
                      style: t.chip.copyWith(fontSize: 14, color: s.ink)),
                ),
                Text(
                  r.free,
                  style: t.bodyRegular.copyWith(
                    fontSize: 14,
                    color: s.muted,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: s.muted,
                  ),
                ),
                const SizedBox(width: 12),
                if (r.pro == null)
                  Icon(Icons.all_inclusive_rounded, size: 20, color: s.ink)
                else
                  Text(r.pro!,
                      style: t.chip.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: s.ink)),
              ],
            ),
          ),
        ),
      ));
    }

    return SketchCard(
      radius: SketchRadius.group,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

// ─── Plan card ──────────────────────────────────────────────────────

/// A plan choice: outlined, or — selected — yellow with a 2px ink border.
/// [badge] ("SAVE 44%") sits on the top edge in an ink pill.
class PaywallPlanCard extends StatelessWidget {
  const PaywallPlanCard({
    super.key,
    required this.title,
    required this.price,
    required this.selected,
    required this.onTap,
    this.badge,
    this.caption,
  });

  final String title;

  /// Exactly as the store formatted it.
  final String price;
  final bool selected;
  final VoidCallback? onTap;
  final String? badge;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final l10n = AppL10n.of(context);
    final fg = selected ? SketchPastels.onPastel : s.ink;
    final dur = SketchMotion.of(context, SketchMotion.base);

    final card = AnimatedContainer(
      duration: dur,
      curve: SketchMotion.enter,
      padding: EdgeInsets.symmetric(
          horizontal: selected ? 13.5 : 14, vertical: selected ? 11.5 : 12),
      decoration: BoxDecoration(
        color: selected ? SketchPastels.yellow : Colors.transparent,
        borderRadius: BorderRadius.circular(SketchRadius.card),
        border: Border.all(
          color: selected ? SketchPastels.onPastel : s.outline,
          width: selected ? 2 : SketchStroke.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: t.chip.copyWith(
              color: fg,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              price,
              style: t.cardTitle.copyWith(
                  fontSize: 20, fontWeight: FontWeight.w800, color: fg),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!,
                style: t.caption.copyWith(
                    color: selected ? SketchPastels.onPastel : s.muted)),
          ],
        ],
      ),
    );

    return SketchPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: [
        l10n.pwPlanSemantic(title, price),
        if (badge != null) badge!,
        if (caption != null) caption!,
      ].join(', '),
      child: ExcludeSemantics(
        child: Stack(
          clipBehavior: Clip.none,
          // Fill the slot the parent gives (two cards share a row).
          fit: StackFit.passthrough,
          children: [
            card,
            if (badge != null)
              PositionedDirectional(
                top: -10,
                end: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: SketchPastels.onPastel,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge!,
                    style: t.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: SketchPastels.yellow,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
