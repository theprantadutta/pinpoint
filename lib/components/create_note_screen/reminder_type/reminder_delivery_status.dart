import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../design_system/design_system.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../../services/notification_service.dart';

/// Whether this phone will ring for a reminder.
enum ReminderDelivery { blocked, inexact, exact }

/// Pure, for testing.
ReminderDelivery reminderDelivery({required bool notificationsOn, required bool exactAllowed}) =>
    !notificationsOn
        ? ReminderDelivery.blocked
        : exactAllowed
            ? ReminderDelivery.exact
            : ReminderDelivery.inexact;

/// Under the reminder's date: will it ring here, and if not, the fix.
///
/// Notifications off: the reminder cannot ring on this phone, with a button
/// to turn them on. Exact alarms refused: it rings, possibly a few minutes
/// late, with a button to allow exact timing. Otherwise: it rings on time,
/// even offline. Re-checked when the user comes back from system settings.
class ReminderDeliveryStatus extends StatefulWidget {
  const ReminderDeliveryStatus({super.key});

  @override
  State<ReminderDeliveryStatus> createState() => _ReminderDeliveryStatusState();
}

class _ReminderDeliveryStatusState extends State<ReminderDeliveryStatus> with WidgetsBindingObserver {
  ReminderDelivery? _delivery;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final on = await NotificationService.areNotificationsEnabled();
    final exact = await NotificationService.canScheduleExactAlarms();
    if (mounted) setState(() => _delivery = reminderDelivery(notificationsOn: on, exactAllowed: exact));
  }

  Future<void> _fix() async {
    switch (_delivery) {
      case ReminderDelivery.blocked:
        final granted = await NotificationService.requestBasicNotificationPermission();
        // Denied before: Android and iOS only let the user change it in settings.
        if (!granted) await openAppSettings();
      case ReminderDelivery.inexact:
        await NotificationService.requestScheduleExactAlarmPermission();
      case ReminderDelivery.exact || null:
        break;
    }
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    final delivery = _delivery;
    if (delivery == null) return const SizedBox.shrink();
    final s = context.sketch;
    final t = context.type;
    final l10n = AppL10n.of(context);
    final (icon, text, action) = switch (delivery) {
      ReminderDelivery.blocked => (Icons.notifications_off_outlined, l10n.remStatusBlocked, l10n.remStatusTurnOn),
      ReminderDelivery.inexact => (Icons.schedule_rounded, l10n.remStatusInexact, l10n.remStatusAllowExact),
      ReminderDelivery.exact => (Icons.notifications_active_outlined, l10n.remStatusExact, null),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: delivery == ReminderDelivery.blocked ? s.ink : s.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: t.bodySmall.copyWith(
                      color: delivery == ReminderDelivery.blocked ? s.ink : s.muted)),
            ),
            if (action != null) SketchTextAction(label: action, onTap: _fix),
          ],
        ),
      ),
    );
  }
}
