import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design_system/design_system.dart';
import '../../service_locators/init_service_locators.dart';
import '../../services/analytics/analytics_facade.dart';
import '../../services/notification_service.dart';

/// The one-time "Enable notifications" ask, as a Sketchbook sheet.
///
/// Runs in the shell's startup sequence (What's new → this → walkthrough) so
/// no two first-run prompts ever stack. Asked once per install, whatever the
/// answer.
class NotificationPrompt {
  NotificationPrompt._();

  static const String _askedKey = 'notification_permission_requested';

  static Future<void> showIfNeeded(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_askedKey) ?? false) return;
      if (!context.mounted) return;

      final l10n = AppL10n.of(context);
      final enable = await showSketchSheet<bool>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        builder: (ctx) => SketchSheet(
          scrollable: false,
          titleWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StickerTile(
                color: SketchPastels.lavender,
                size: 52,
                angle: -6,
                icon: Icons.alarm_rounded,
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child:
                    Text(l10n.homeEnableNotifTitle, style: ctx.type.emptyTitle),
              ),
              const SizedBox(height: 8),
              Text(l10n.homeEnableNotifBody,
                  style: ctx.type.bodyRegular
                      .copyWith(fontSize: 14, color: ctx.sketch.muted)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PillButton(
                label: l10n.homeEnable,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
              const SizedBox(height: 10),
              PillButton.secondary(
                label: l10n.homeNotNow,
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
            ],
          ),
        ),
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
