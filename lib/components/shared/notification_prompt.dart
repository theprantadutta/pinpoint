import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design_system/design_system.dart';
import '../../service_locators/init_service_locators.dart';
import '../../services/analytics/analytics_facade.dart';
import '../../services/notification_service.dart';
import '../../util/localized_dates.dart';

/// The one-time "Enable notifications" ask, as a Sketchbook sheet.
///
/// Runs in the shell's startup sequence (What's new → this → walkthrough) so
/// no two first-run prompts ever stack. Asked once per install, whatever the
/// answer.
///
/// It shows what the user would actually get — a reminder arriving — rather
/// than asking in the abstract, and says plainly that reminders are the only
/// thing Pinpoint notifies about.
class NotificationPrompt {
  NotificationPrompt._();

  static const String _askedKey = 'notification_permission_requested';

  static Future<void> showIfNeeded(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_askedKey) ?? false) return;
      if (!context.mounted) return;

      final enable = await showSketchSheet<bool>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        builder: (ctx) => const NotificationPromptSheet(),
      );

      // Asked, whatever the answer.
      await prefs.setBool(_askedKey, true);
      if (enable == true) {
        await NotificationService.requestBasicNotificationPermission();
      }
      getIt<AnalyticsFacade>()
          .trackNotificationPermissionResult(granted: enable == true);
    } catch (e) {
      debugPrint('❌ Error requesting notification permission: $e');
    }
  }
}

/// The sheet body. Public for widget tests; pops `true` to enable.
class NotificationPromptSheet extends StatelessWidget {
  const NotificationPromptSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = context.sketch;
    final t = context.type;

    return SketchSheet(
      scrollable: false,
      titleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          const _ReminderPreview(),
          const SizedBox(height: 26),
          Semantics(
            header: true,
            label: HighlightedText.plain(l10n.notifPromptTitle),
            child: ExcludeSemantics(
              child: HighlightedText(l10n.notifPromptTitle, style: t.emptyTitle),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.notifPromptBody,
            style: t.bodyRegular.copyWith(fontSize: 14, color: s.muted),
          ),
          const SizedBox(height: 16),
          _Point(text: l10n.notifPromptPointOnly),
          const SizedBox(height: 10),
          _Point(text: l10n.notifPromptPointSettings),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PillButton(
            label: l10n.notifPromptEnable,
            icon: Icons.notifications_active_outlined,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 10),
          PillButton.secondary(
            label: l10n.homeNotNow,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

/// A mock of the notification a reminder produces, tilted like a sticker,
/// with a bell sticker on its corner.
class _ReminderPreview extends StatelessWidget {
  const _ReminderPreview();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = context.sketch;
    final t = context.type;
    final now = DateTime.now();
    final at = DateTime(now.year, now.month, now.day, 18);
    final rtl = Directionality.of(context) == TextDirection.rtl;

    final card = Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 16, 14),
      decoration: BoxDecoration(
        color: s.surface,
        borderRadius: BorderRadius.circular(SketchRadius.card),
        border: Border.all(color: s.outline, width: SketchStroke.outline),
        boxShadow: SketchShadows.sticker(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const BrandSticker(size: 22, angle: 0),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Pinpoint',
                  style: t.bodyRegular.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                ' · ${l10n.notifPromptPreviewNow}',
                style: t.bodyRegular.copyWith(fontSize: 12.5, color: s.muted),
              ),
              const Spacer(),
              Icon(Icons.alarm_rounded, size: 16, color: s.muted),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l10n.notifPromptPreviewTitle,
            style: t.bodyRegular.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            LocalizedDates.relativeDayTime(context, at),
            style: t.bodyRegular.copyWith(fontSize: 13.5, color: s.muted),
          ),
        ],
      ),
    );

    return ExcludeSemantics(
      child: Padding(
        // Room for the bell to overhang without being clipped.
        padding: const EdgeInsetsDirectional.only(top: 14, end: 14, start: 4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Transform.rotate(angle: (rtl ? 2 : -2) * math.pi / 180, child: card),
            PositionedDirectional(
              top: -18,
              end: -12,
              child: StickerTile(
                color: SketchPastels.yellow,
                size: 46,
                angle: rtl ? -10 : 10,
                shadowOffset: 3,
                icon: Icons.notifications_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: SketchPastels.mint,
            shape: BoxShape.circle,
            border: Border.all(color: SketchPastels.onPastel, width: SketchStroke.outline),
          ),
          child: const Icon(Icons.check_rounded, size: 14, color: SketchPastels.onPastel),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: t.bodyRegular.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
