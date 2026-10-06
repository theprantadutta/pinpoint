import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../design_system/design_system.dart';
import '../screens/subscription_screen.dart';
import '../service_locators/init_service_locators.dart';
import '../services/analytics/analytics_facade.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/constants/premium_limits.dart';

/// The sheet shown when a free user hits a limit: one sticker, a title such
/// as "You've used 5 of 5 folders", one line of copy, an inverse "See Pro"
/// and an outline "Not now".
///
/// Use the static `show*` entry points; each records `premium_gate_shown`
/// with its feature, exactly as before the redesign.
class PremiumGateDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  /// Overrides the "See Pro" label.
  final String? ctaText;

  /// The sticker's pastel.
  final Color pastel;

  /// A short label drawn on the sticker instead of [icon] ("OCR").
  final String? glyph;

  const PremiumGateDialog({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.ctaText,
    this.pastel = SketchPastels.yellow,
    this.glyph,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final s = context.sketch;
    final l10n = AppL10n.of(context);

    return SketchSheet(
      scrollable: false,
      titleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // Room for the tilt and the hard shadow.
            padding: const EdgeInsetsDirectional.only(start: 4, top: 4),
            child: StickerTile(
              color: pastel,
              size: glyph == null ? 60 : 64,
              height: glyph == null ? null : 46,
              angle: -8,
              icon: glyph == null ? icon : null,
              glyph: glyph,
            ),
          ),
          const SizedBox(height: 18),
          Semantics(
            header: true,
            child: Text(title, style: t.emptyTitle),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: t.bodyRegular.copyWith(fontSize: 14, color: s.muted),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PillButton(
            label: ctaText ?? l10n.pwSeePro,
            onPressed: () {
              // Resolve the router before popping: the sheet is a Navigator
              // route, and its context is unsafe once it is gone.
              final router = GoRouter.maybeOf(context);
              Navigator.of(context).pop();
              router?.push(SubscriptionScreen.kRouteName);
            },
          ),
          const SizedBox(height: 10),
          PillButton.secondary(
            label: l10n.pwNotNow,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  static Future<void> _show(BuildContext context, WidgetBuilder builder) =>
      showSketchSheet<void>(context: context, builder: builder);

  /// Show premium gate dialog for sync limit
  static Future<void> showSyncLimit(BuildContext context, int remaining) {
    getIt<AnalyticsFacade>().trackPremiumGateShown(feature: 'sync');
    return _show(
      context,
      (context) => PremiumGateDialog(
        title: AppL10n.of(context)
            .pwGateSyncTitle(PremiumLimits.maxSyncedNotesForFree),
        message: AppL10n.of(context).pwGateSyncBody,
        icon: Icons.cloud_sync_rounded,
        pastel: SketchPastels.sky,
      ),
    );
  }

  /// Show premium gate dialog for OCR limit
  static Future<void> showOcrLimit(BuildContext context, int remaining) {
    getIt<AnalyticsFacade>().trackPremiumGateShown(feature: 'ocr');
    return _show(
      context,
      (context) => PremiumGateDialog(
        title: AppL10n.of(context)
            .pwGateOcrTitle(PremiumLimits.maxOcrScansPerMonthForFree),
        message: AppL10n.of(context).pwGateOcrBody,
        icon: Icons.document_scanner_rounded,
        glyph: 'OCR',
        pastel: SketchPastels.sky,
      ),
    );
  }

  /// Show premium gate dialog for export limit
  static Future<void> showExportLimit(BuildContext context) {
    getIt<AnalyticsFacade>().trackPremiumGateShown(feature: 'export');
    return _show(
      context,
      (context) => PremiumGateDialog(
        title: AppL10n.of(context)
            .pwGateExportTitle(PremiumLimits.maxExportsPerMonthForFree),
        message: AppL10n.of(context).pwGateExportBody,
        icon: Icons.file_download_rounded,
        pastel: SketchPastels.mint,
      ),
    );
  }

  /// Show premium gate dialog for voice recording duration
  static Future<void> showVoiceRecordingLimit(BuildContext context) {
    getIt<AnalyticsFacade>().trackPremiumGateShown(feature: 'voice_recording');
    return _show(
      context,
      (context) => PremiumGateDialog(
        title: AppL10n.of(context).pwGateVoiceTitle(
            PremiumLimits.maxVoiceRecordingDurationForFree ~/ 60),
        message: AppL10n.of(context).pwGateVoiceBody,
        icon: Icons.mic_rounded,
        pastel: SketchPastels.pink,
      ),
    );
  }

  /// Show premium gate dialog for folder limit
  static Future<void> showFolderLimit(BuildContext context) {
    getIt<AnalyticsFacade>().trackPremiumGateShown(feature: 'folders');
    return _show(
      context,
      (context) => PremiumGateDialog(
        title: AppL10n.of(context)
            .pwGateFolderTitle(PremiumLimits.maxFoldersForFree),
        message: AppL10n.of(context).pwGateFolderBody,
        icon: Icons.folder_rounded,
        pastel: SketchPastels.yellow,
      ),
    );
  }

  /// Show premium gate dialog for theme color
  static Future<void> showThemeLimit(BuildContext context) {
    getIt<AnalyticsFacade>().trackPremiumGateShown(feature: 'theme');
    return _show(
      context,
      (context) => PremiumGateDialog(
        title: AppL10n.of(context).pwGateThemeTitle,
        message: AppL10n.of(context)
            .pwGateThemeBody(PremiumLimits.totalThemeColors),
        icon: Icons.palette_rounded,
        pastel: SketchPastels.lavender,
      ),
    );
  }

  /// Show premium gate dialog for file attachment limit
  static Future<void> showFileAttachmentLimit(
      BuildContext context, int current, int max) {
    getIt<AnalyticsFacade>().trackPremiumGateShown(feature: 'file_attachment');
    return _show(
      context,
      (context) => PremiumGateDialog(
        title: AppL10n.of(context).pwGateAttachTitle(max),
        message: AppL10n.of(context).pwGateAttachBody,
        icon: Icons.attach_file_rounded,
        pastel: SketchPastels.yellow,
      ),
    );
  }

  // Removed: showMarkdownExportPremium / showEncryptedSharingPremium.
  // Both had zero call sites and both were untrue — Markdown export ships free
  // under the monthly export quota (see canExport), and encrypted sharing is
  // not implemented at all (the editor menu entry is disabled and marked SOON).
  // Their strings (gatePremiumFeature, gateMarkdown*, gateSharing*) were dropped
  // from all nine .arb files with them.
}
