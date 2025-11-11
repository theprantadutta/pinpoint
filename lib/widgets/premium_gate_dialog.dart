import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../design_system/design_system.dart';
import '../screens/subscription_screen_revcat.dart';

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
                    context.push(SubscriptionScreenRevCat.kRouteName);
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
                          ctaText ?? 'Upgrade to Premium',
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
                  'Maybe Later',
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
    return showDialog(
      context: context,
      builder: (context) => PremiumGateDialog(
        title: 'Sync Limit Reached',
        message:
            'You\'ve reached the limit of 50 synced notes on the free plan. '
            'Upgrade to Premium for unlimited cloud sync across all your devices.',
        icon: Icons.cloud_off_rounded,
        ctaText: 'Unlock Unlimited Sync',
      ),
    );
  }

  /// Show premium gate dialog for OCR limit
  static Future<void> showOcrLimit(BuildContext context, int remaining) {
    return showDialog(
      context: context,
      builder: (context) => PremiumGateDialog(
        title: 'OCR Limit Reached',
        message: 'You\'ve used all 20 OCR scans this month. '
            'Upgrade to Premium for unlimited text recognition from images.',
        icon: Icons.document_scanner_rounded,
        ctaText: 'Unlock Unlimited OCR',
      ),
    );
  }

  /// Show premium gate dialog for export limit
  static Future<void> showExportLimit(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const PremiumGateDialog(
        title: 'Export Limit Reached',
        message: 'You\'ve used all 10 exports this month. '
            'Upgrade to Premium for unlimited exports to PDF and Markdown.',
        icon: Icons.file_download_off_rounded,
        ctaText: 'Unlock Unlimited Exports',
      ),
    );
  }

  /// Show premium gate dialog for voice recording duration
  static Future<void> showVoiceRecordingLimit(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const PremiumGateDialog(
        title: 'Recording Limit',
        message: 'Free plan recordings are limited to 2 minutes. '
            'Upgrade to Premium for unlimited voice recording duration.',
        icon: Icons.mic_off_rounded,
        ctaText: 'Unlock Unlimited Recording',
      ),
    );
  }

  /// Show premium gate dialog for folder limit
  static Future<void> showFolderLimit(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const PremiumGateDialog(
        title: 'Folder Limit Reached',
        message: 'You\'ve reached the limit of 5 folders on the free plan. '
            'Upgrade to Premium for unlimited folders and better organization.',
        icon: Icons.folder_off_rounded,
        ctaText: 'Unlock Unlimited Folders',
      ),
    );
  }

  /// Show premium gate dialog for theme color
  static Future<void> showThemeLimit(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const PremiumGateDialog(
        title: 'Premium Theme',
        message: 'This theme color is exclusive to Premium members. '
            'Upgrade to unlock all 5 beautiful accent colors.',
        icon: Icons.palette_rounded,
        ctaText: 'Unlock All Themes',
      ),
    );
  }

  /// Show premium gate dialog for file attachment limit
  static Future<void> showFileAttachmentLimit(
      BuildContext context, int current, int max) {
    return showDialog(
      context: context,
      builder: (context) => PremiumGateDialog(
        title: 'Attachment Limit Reached',
        message: 'You\'ve reached the limit of $max attachments per note. '
            'Upgrade to Premium for unlimited file attachments.',
        icon: Icons.attach_file_rounded,
        ctaText: 'Unlock Unlimited Attachments',
      ),
    );
  }

  /// Show premium gate for markdown export
  static Future<void> showMarkdownExportPremium(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const PremiumGateDialog(
        title: 'Premium Feature',
        message: 'Markdown export is a Premium-only feature. '
            'Export your notes in beautiful, portable markdown format.',
        icon: Icons.code_rounded,
        ctaText: 'Unlock Markdown Export',
      ),
    );
  }

  /// Show premium gate for encrypted sharing
  static Future<void> showEncryptedSharingPremium(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const PremiumGateDialog(
        title: 'Premium Feature',
        message: 'Encrypted sharing is a Premium-only feature. '
            'Share your notes securely with end-to-end encryption.',
        icon: Icons.shield_rounded,
        ctaText: 'Unlock Secure Sharing',
      ),
    );
  }
}
