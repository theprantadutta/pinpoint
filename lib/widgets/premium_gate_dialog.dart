import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../design_system/design_system.dart';
import '../screens/subscription_screen.dart';
import '../service_locators/init_service_locators.dart';
import '../services/analytics/analytics_facade.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/constants/premium_limits.dart';

/// Dialog shown when user hits a premium limit
class PremiumGateDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? ctaText;

  const PremiumGateDialog({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.ctaText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          gradient: isDark
              ? PinpointGradients.crescentInk
              : PinpointGradients.oceanQuartz,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: cs.primary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: cs.primary,
                ),
              )
                  .animate()
                  .scale(
                    duration: 500.ms,
                    curve: Curves.elasticOut,
                  )
                  .shimmer(
                      duration: 1500.ms,
                      color: cs.primary.withValues(alpha: 0.3)),

              const SizedBox(height: 24),

              // Title
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? PinpointColors.darkTextPrimary
                      : PinpointColors.lightTextPrimary,
                ),
                textAlign: TextAlign.center,
              )
                  .animate(delay: 100.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0),

              const SizedBox(height: 12),

              // Message
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? PinpointColors.darkTextSecondary
                      : PinpointColors.lightTextSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              )
                  .animate(delay: 200.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0),

              const SizedBox(height: 32),

              // CTA Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push(SubscriptionScreen.kRouteName);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars_rounded, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          ctaText ?? AppL10n.of(context).gateUpgradeCta,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate(delay: 300.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0),

              const SizedBox(height: 12),

              // Maybe Later button
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  AppL10n.of(context).gateMaybeLater,
                  style: TextStyle(
                    color: isDark
                        ? PinpointColors.darkTextSecondary
                        : PinpointColors.lightTextSecondary,
                  ),
                ),
              ).animate(delay: 400.ms).fadeIn(duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }

  /// Show premium gate dialog for sync limit
  static Future<void> showSyncLimit(BuildContext context, int remaining) {
    getIt<AnalyticsFacade>().trackPremiumGateShown(feature: 'sync');
    return showDialog(
      context: context,
      builder: (context) => PremiumGateDialog(
        title: AppL10n.of(context).gateSyncTitle,
        message: AppL10n.of(context).gateSyncMessage(PremiumLimits.maxSyncedNotesForFree),
        icon: Icons.cloud_off_rounded,
        ctaText: AppL10n.of(context).gateSyncCta,
      ),
    );
  }

  /// Show premium gate dialog for OCR limit
  static Future<void> showOcrLimit(BuildContext context, int remaining) {
    getIt<AnalyticsFacade>().trackPremiumGateShown(feature: 'ocr');
    return showDialog(
      context: context,
      builder: (context) => PremiumGateDialog(
        title: AppL10n.of(context).gateOcrTitle,
        message: AppL10n.of(context).gateOcrMessage(PremiumLimits.maxOcrScansPerMonthForFree),
        icon: Icons.document_scanner_rounded,
        ctaText: AppL10n.of(context).gateOcrCta,
      ),
    );
  }

  /// Show premium gate dialog for export limit
  static Future<void> showExportLimit(BuildContext context) {
    getIt<AnalyticsFacade>().trackPremiumGateShown(feature: 'export');
    return showDialog(
      context: context,
      builder: (context) => PremiumGateDialog(
        title: AppL10n.of(context).gateExportTitle,
        message: AppL10n.of(context).gateExportMessage(PremiumLimits.maxExportsPerMonthForFree),
        icon: Icons.file_download_off_rounded,
        ctaText: AppL10n.of(context).gateExportCta,
      ),
    );
  }

  /// Show premium gate dialog for voice recording duration
  static Future<void> showVoiceRecordingLimit(BuildContext context) {
    getIt<AnalyticsFacade>().trackPremiumGateShown(feature: 'voice_recording');
    return showDialog(
      context: context,
      builder: (context) => PremiumGateDialog(
        title: AppL10n.of(context).gateRecordingTitle,
        message: AppL10n.of(context).gateRecordingMessage(PremiumLimits.maxVoiceRecordingDurationForFree ~/ 60),
        icon: Icons.mic_off_rounded,
        ctaText: AppL10n.of(context).gateRecordingCta,
      ),
    );
  }

  /// Show premium gate dialog for folder limit
  static Future<void> showFolderLimit(BuildContext context) {
    getIt<AnalyticsFacade>().trackPremiumGateShown(feature: 'folders');
    return showDialog(
      context: context,
      builder: (context) => PremiumGateDialog(
        title: AppL10n.of(context).gateFolderTitle,
        message: AppL10n.of(context).gateFolderMessage(PremiumLimits.maxFoldersForFree),
        icon: Icons.folder_off_rounded,
        ctaText: AppL10n.of(context).gateFolderCta,
      ),
    );
  }

  /// Show premium gate dialog for theme color
  static Future<void> showThemeLimit(BuildContext context) {
    getIt<AnalyticsFacade>().trackPremiumGateShown(feature: 'theme');
    return showDialog(
      context: context,
      builder: (context) => PremiumGateDialog(
        title: AppL10n.of(context).gateThemeTitle,
        message: AppL10n.of(context).gateThemeMessage(PremiumLimits.totalThemeColors),
        icon: Icons.palette_rounded,
        ctaText: AppL10n.of(context).gateThemeCta,
      ),
    );
  }

  /// Show premium gate dialog for file attachment limit
  static Future<void> showFileAttachmentLimit(
      BuildContext context, int current, int max) {
    getIt<AnalyticsFacade>().trackPremiumGateShown(feature: 'file_attachment');
    return showDialog(
      context: context,
      builder: (context) => PremiumGateDialog(
        title: AppL10n.of(context).gateAttachmentTitle,
        message: AppL10n.of(context).gateAttachmentMessage(max),
        icon: Icons.attach_file_rounded,
        ctaText: AppL10n.of(context).gateAttachmentCta,
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
