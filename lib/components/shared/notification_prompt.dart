import '../../services/come_back_nudge.dart';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design_system/design_system.dart';
import '../../service_locators/init_service_locators.dart';
import '../../services/analytics/analytics_facade.dart';
import '../../services/drift_note_service.dart';
import '../../services/notification_service.dart';
import '../../util/localized_dates.dart';

/// The "Enable notifications" ask, as a Sketchbook sheet.
///
/// **When.** Not on arrival. It used to open on the first visit home, before
/// the person had written anything, and nearly everyone who installed saw it
/// there; every gate before the first action costs day-one retention. It now
/// waits for success: right after a *new* note is saved and the person is back
/// on the home shell, once they have at least [minNotes] notes. Two notes,
/// rather than one, because the first note is the blank one opened for every
/// newcomer; a second one is the person choosing to come back to Pinpoint to
/// write, which is when "we'll remind you" means something. Counting notes in
/// the local database (not a counter) also covers people whose notes came back
/// with their account.
///
/// **How often.** "Not now" (the button, a drag or a tap outside) asks once
/// more, no sooner than [reaskAfter] later, and never again after that.
/// "Turn on" ends it whatever the system answers. Anyone already asked by the
/// old version has [askedKey] set and is never asked again.
///
/// **Reminders** do not wait for this: the reminder editor asks the system
/// itself ([requestForReminder]), which also counts as having asked.
///
/// It shows what the user would actually get — a reminder arriving — rather
/// than asking in the abstract, and says plainly that reminders are the only
/// thing Pinpoint notifies about.
class NotificationPrompt {
  NotificationPrompt._();

  /// Set once asking is over. Same key as before, so nobody the old version
  /// asked is asked again.
  static const String askedKey = 'notification_permission_requested';

  /// When "not now" was first answered; present means one ask is left.
  @visibleForTesting
  static const String deferredAtKey = 'notification_prompt_deferred_at_ms';

  static const int minNotes = 2;
  static const Duration reaskAfter = Duration(days: 7);

  /// Pure: whether the sheet is due. [deferredAt] is when "not now" was first
  /// answered, or null if it never was.
  static bool shouldAsk({
    required bool asked,
    required DateTime? deferredAt,
    required int noteCount,
    required DateTime now,
  }) {
    if (asked) return false;
    if (noteCount < minNotes) return false;
    if (deferredAt != null && now.difference(deferredAt) < reaskAfter) {
      return false;
    }
    return true;
  }

  /// Reads the stored state and asks [shouldAsk]. Counts notes only when
  /// the answer could be yes.
  @visibleForTesting
  static Future<bool> isDue(
    SharedPreferences prefs, {
    required Future<int> Function() countNotes,
    required DateTime now,
  }) async {
    final asked = prefs.getBool(askedKey) ?? false;
    final deferredAt = _deferredAt(prefs);
    // Everything but the count first, so the database is not touched for
    // someone who will not be asked anyway.
    if (!shouldAsk(
        asked: asked, deferredAt: deferredAt, noteCount: minNotes, now: now)) {
      return false;
    }
    return shouldAsk(
      asked: asked,
      deferredAt: deferredAt,
      noteCount: await countNotes(),
      now: now,
    );
  }

  static DateTime? _deferredAt(SharedPreferences prefs) {
    final ms = prefs.getInt(deferredAtKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Stores an answer: "Turn on" ends the asking; the first "not now" leaves
  /// one more ask, the second ends it.
  @visibleForTesting
  static Future<void> recordAnswer(
    SharedPreferences prefs, {
    required bool enabled,
    required DateTime now,
  }) async {
    if (enabled || prefs.containsKey(deferredAtKey)) {
      await prefs.setBool(askedKey, true);
      await prefs.remove(deferredAtKey);
    } else {
      await prefs.setInt(deferredAtKey, now.millisecondsSinceEpoch);
    }
  }

  /// Shows the sheet if [isDue]. Returns whether it was shown, so the caller
  /// does not stack another prompt on the same moment.
  static Future<bool> showIfNeeded(
    BuildContext context, {
    Future<int> Function()? countNotes,
    AnalyticsFacade? analytics,
    Future<bool> Function()? requestPermission,
    Future<void> Function(String title, String body)? scheduleNudge,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final due = await isDue(prefs,
          countNotes: countNotes ?? DriftNoteService.countNotes, now: now);
      if (!due || !context.mounted) return false;

      analytics ??= getIt<AnalyticsFacade>();
      final reask = prefs.containsKey(deferredAtKey);
      analytics.trackNotificationPromptShown(
          attempt: reask ? 'reask' : 'first', trigger: 'note_saved');

      final l10n = AppL10n.of(context);
      var nudge = false;
      // Dismissible: a drag or a tap outside is "not now" (null).
      final enable = await showSketchSheet<bool>(
        context: context,
        builder: (ctx) =>
            NotificationPromptSheet(onNudgeChanged: (value) => nudge = value),
      );

      await recordAnswer(prefs, enabled: enable == true, now: now);
      var granted = false;
      if (enable == true) {
        granted = await (requestPermission ??
            NotificationService.requestBasicNotificationPermission)();
        if (granted && nudge) {
          await (scheduleNudge ??
              (t, b) => ComeBackNudge.schedule(title: t, body: b))(
              l10n.nudgeTitle, l10n.nudgeBody);
          analytics.trackNudgeScheduled();
        }
      }
      analytics.trackNotificationPermissionResult(
        granted: granted,
        outcome: switch (enable) {
          true => 'enabled',
          false => 'not_now',
          null => 'dismissed',
        },
      );
      return true;
    } catch (e) {
      debugPrint('❌ Error requesting notification permission: $e');
      return false;
    }
  }

  /// Setting a reminder: if notifications are off, ask the system right
  /// away, in context, whether or not the sheet was ever shown. Counts as
  /// the ask, so the sheet will not repeat the question later. Returns
  /// whether notifications are on afterwards.
  static Future<bool> requestForReminder({
    Future<bool> Function()? areEnabled,
    Future<bool> Function()? request,
    AnalyticsFacade? analytics,
  }) async {
    try {
      if (await (areEnabled ?? NotificationService.areNotificationsEnabled)()) {
        return true;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(askedKey, true);
      await prefs.remove(deferredAtKey);
      final granted =
          await (request ?? NotificationService.requestBasicNotificationPermission)();
      (analytics ?? getIt<AnalyticsFacade>())
          .trackReminderPermissionRequested(granted: granted);
      return granted;
    } catch (e) {
      debugPrint('❌ Error requesting notification permission for a reminder: $e');
      return false;
    }
  }
}

/// The sheet body. Public for widget tests; pops `true` to enable.
class NotificationPromptSheet extends StatefulWidget {
  const NotificationPromptSheet({super.key, this.onNudgeChanged});

  /// Reports the opt-in for the one-time nudge, which starts off.
  final ValueChanged<bool>? onNudgeChanged;

  @override
  State<NotificationPromptSheet> createState() =>
      _NotificationPromptSheetState();
}

class _NotificationPromptSheetState extends State<NotificationPromptSheet> {
  bool _nudge = false;

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
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.notifPromptNudge,
                  style: t.bodyRegular.copyWith(fontSize: 14, color: s.ink),
                ),
              ),
              const SizedBox(width: 12),
              SketchToggle(
                value: _nudge,
                semanticLabel: l10n.notifPromptNudge,
                onChanged: (value) {
                  setState(() => _nudge = value);
                  widget.onNudgeChanged?.call(value);
                },
              ),
            ],
          ),
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
