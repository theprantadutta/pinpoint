import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:pinpoint/main.dart';
import 'package:pinpoint/screens/archive_screen.dart';
import 'package:pinpoint/screens/sync_screen.dart';
import 'package:pinpoint/screens/trash_screen.dart';
import 'package:pinpoint/screens/subscription_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:pinpoint/services/drift_note_service.dart';
import 'package:pinpoint/services/subscription_manager.dart';
import 'package:pinpoint/services/firebase_notification_service.dart';
import 'package:pinpoint/services/backend_auth_service.dart';
import 'package:pinpoint/services/google_sign_in_service.dart';
import 'package:pinpoint/services/logout_service.dart';
import 'package:pinpoint/util/show_a_toast.dart';
import 'package:pinpoint/screens/theme_screen.dart';
import 'package:pinpoint/screens/terms_acceptance_screen.dart';
import 'package:pinpoint/screens/admin_panel_screen.dart';
import 'package:pinpoint/widgets/admin_password_dialog.dart';
import 'package:provider/provider.dart';
import '../design_system/design_system.dart';
import '../services/premium_service.dart';
import '../constants/premium_limits.dart';
import '../navigation/app_navigation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../sync/sync_manager.dart';
import '../service_locators/init_service_locators.dart';

class SettingsScreen extends StatefulWidget {
  static const String kRouteName = '/settings';
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _openGooglePlaySubscriptions() async {
    try {
      final uri =
          Uri.parse('https://play.google.com/store/account/subscriptions');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch subscriptions page';
      }
    } catch (e) {
      if (mounted) {
        showErrorToast(
          context: context,
          title: 'Error',
          description: 'Unable to open Google Play subscriptions',
        );
      }
    }
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Get package info for version
    final packageInfo = await PackageInfo.fromPlatform();
    final version = packageInfo.version;
    final buildNumber = packageInfo.buildNumber;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(PinpointSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/pinpoint-logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(height: PinpointSpacing.lg),

              // App Name
              Text(
                'Pinpoint',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),

              const SizedBox(height: PinpointSpacing.xs),

              // Version
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: PinpointSpacing.ms,
                  vertical: PinpointSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Version $version ($buildNumber)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: PinpointSpacing.lg),

              // Description
              Text(
                'Your thoughts, perfectly organized. Capture notes, record audio, manage todos, and set reminders - all in one beautiful, secure app.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: PinpointSpacing.lg),

              // Divider
              Divider(
                color: cs.outline.withValues(alpha: 0.2),
                thickness: 1,
              ),

              const SizedBox(height: PinpointSpacing.lg),

              // Developer Info
              Column(
                children: [
                  Text(
                    'Developed & Maintained By',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: PinpointSpacing.sm),
                  InkWell(
                    onTap: () async {
                      PinpointHaptics.light();
                      final uri = Uri.parse('https://pranta.dev');
                      try {
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showErrorToast(
                            context: context,
                            title: 'Error',
                            description: 'Unable to open portfolio',
                          );
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: PinpointSpacing.md,
                        vertical: PinpointSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Pranta Dutta',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: PinpointSpacing.sm),
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 16,
                            color: cs.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: PinpointSpacing.lg),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    PinpointHaptics.light();
                    Navigator.of(context).pop();
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: PinpointSpacing.ms,
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GradientScaffold(
      appBar: GlassAppBar(
        title: Row(
          children: [
            Icon(Icons.settings_rounded, color: cs.primary, size: 20),
            const SizedBox(width: PinpointSpacing.sm),
            const Text('Settings'),
          ],
        ),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          left: PinpointSpacing.md,
          right: PinpointSpacing.md,
          top: PinpointSpacing.screenEdge,
          bottom: 100, // Extra space for floating navigation bar
        ),
        children: [
          // Premium/Subscription Section
          Consumer<SubscriptionManager>(
            builder: (context, subscriptionManager, child) {
              return _PremiumSection(
                subscriptionManager: subscriptionManager,
                onManageSubscription: _openGooglePlaySubscriptions,
              );
            },
          ),

          const SizedBox(height: PinpointSpacing.xl),

          // Account & Sync Section
          Consumer<BackendAuthService>(
            builder: (context, backendAuth, _) {
              if (!backendAuth.isAuthenticated) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(title: 'ACCOUNT'),
                    const SizedBox(height: PinpointSpacing.md),
                    _SettingsTile(
                      title: 'Sign In',
                      subtitle: 'Sign in to sync your notes',
                      icon: Icons.login_rounded,
                      onTap: () {
                        PinpointHaptics.medium();
                        AppNavigation.router.push('/auth');
                      },
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: 'ACCOUNT & SYNC'),
                  const SizedBox(height: PinpointSpacing.md),
                  _ProfileCard(backendAuth: backendAuth),
                  const SizedBox(height: PinpointSpacing.md),
                  _ManualSyncButton(),
                  const SizedBox(height: PinpointSpacing.md),

                  // Sync Debug Info - only in debug mode
                  if (kDebugMode) ...[
                    _SettingsTile(
                      title: 'Sync Debug Info',
                      subtitle: 'View sync status and troubleshoot issues',
                      icon: Icons.bug_report_outlined,
                      onTap: () {
                        PinpointHaptics.medium();
                        AppNavigation.router.push('/sync-debug');
                      },
                    ),
                    const SizedBox(height: PinpointSpacing.md),
                  ],

                  _LinkedAccountsSection(backendAuth: backendAuth),
                  const SizedBox(height: PinpointSpacing.md),
                  _LogoutButton(backendAuth: backendAuth),
                ],
              );
            },
          ),

          const SizedBox(height: PinpointSpacing.xl),

          // Usage Limits Section (Free Users Only)
          Consumer<SubscriptionManager>(
            builder: (context, subscriptionManager, child) {
              if (subscriptionManager.isPremium) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: 'USAGE'),
                  const SizedBox(height: PinpointSpacing.md),
                  const _UsageLimitsCard(),
                  const SizedBox(height: PinpointSpacing.xl),
                ],
              );
            },
          ),

          // Appearance Section
          _SectionHeader(title: 'APPEARANCE'),
          const SizedBox(height: PinpointSpacing.md),
          _SettingsTile(
            title: 'Theme',
            subtitle: 'Customize your theme',
            icon: Icons.color_lens_rounded,
            onTap: () {
              PinpointHaptics.medium();
              AppNavigation.router.push(ThemeScreen.kRouteName);
            },
          ),

          const SizedBox(height: PinpointSpacing.xl),

          // Content Section
          _SectionHeader(title: 'CONTENT'),
          const SizedBox(height: PinpointSpacing.md),
          _SettingsTile(
            title: 'My Folders',
            icon: Icons.folder_rounded,
            onTap: () {
              PinpointHaptics.medium();
              AppNavigation.router.push('/my-folders');
            },
          ),
          const SizedBox(height: PinpointSpacing.md),
          _SettingsTile(
            title: 'Archive',
            icon: Icons.archive_rounded,
            onTap: () {
              PinpointHaptics.medium();
              AppNavigation.router.push(ArchiveScreen.kRouteName);
            },
          ),
          const SizedBox(height: PinpointSpacing.md),
          _SettingsTile(
            title: 'Trash',
            icon: Icons.delete_rounded,
            onTap: () {
              PinpointHaptics.medium();
              AppNavigation.router.push(TrashScreen.kRouteName);
            },
          ),
          const SizedBox(height: PinpointSpacing.md),
          _SettingsTile(
            title: 'Sync Settings',
            icon: Icons.sync_rounded,
            onTap: () {
              PinpointHaptics.medium();
              AppNavigation.router.push(SyncScreen.kRouteName);
            },
          ),

          const SizedBox(height: PinpointSpacing.xl),

          // Security Section
          _SectionHeader(title: 'SECURITY'),
          const SizedBox(height: PinpointSpacing.md),
          _SettingsTile(
            title: 'Biometric Lock',
            subtitle:
                MyApp.of(context).isBiometricEnabled ? 'Enabled' : 'Disabled',
            icon: Icons.fingerprint_rounded,
            trailing: Switch(
              value: MyApp.of(context).isBiometricEnabled,
              onChanged: (value) {
                PinpointHaptics.light();
                MyApp.of(context).changeBiometricEnabledEnabled(value);
              },
            ),
            onTap: () {
              PinpointHaptics.light();
              final current = MyApp.of(context).isBiometricEnabled;
              MyApp.of(context).changeBiometricEnabledEnabled(!current);
            },
          ),

          const SizedBox(height: PinpointSpacing.xl),

          // Advanced Section
          _SectionHeader(title: 'ADVANCED'),
          const SizedBox(height: PinpointSpacing.md),
          _SettingsTile(
            title: 'Import Note',
            subtitle: 'Import from .pinpoint-note file',
            icon: Icons.file_upload_rounded,
            onTap: () async {
              PinpointHaptics.medium();
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['pinpoint-note'],
              );
              if (result != null) {
                final file = File(result.files.single.path!);
                final jsonString = await file.readAsString();
                await DriftNoteService.importNoteFromJson(jsonString);
                final ctx = context;
                if (ctx.mounted) {
                  PinpointHaptics.success();
                  showSuccessToast(
                    context: ctx,
                    title: 'Note Imported',
                    description: 'The note has been successfully imported.',
                  );
                }
              }
            },
          ),

          // Test notification - only in debug mode
          if (kDebugMode) ...[
            const SizedBox(height: PinpointSpacing.md),
            _SettingsTile(
              title: 'Test Notification',
              subtitle: 'Send a test push notification',
              icon: Icons.notifications_active_rounded,
              onTap: () async {
                PinpointHaptics.medium();
                try {
                  final notificationService = FirebaseNotificationService();
                  await notificationService.sendTestNotification();
                  final ctx = context;
                  if (ctx.mounted) {
                    showSuccessToast(
                      context: ctx,
                      title: '🔔 Test Notification Sent!',
                      description: 'Check your notification tray',
                    );
                  }
                } catch (e) {
                  final ctx = context;
                  if (ctx.mounted) {
                    showErrorToast(
                      context: ctx,
                      title: 'Failed',
                      description: 'Error: ${e.toString()}',
                    );
                  }
                }
              },
            ),
          ],

          // Admin Panel - only visible to admin email
          if (context.read<BackendAuthService>().userEmail ==
              'prantadutta1997@gmail.com') ...[
            const SizedBox(height: PinpointSpacing.md),
            _SettingsTile(
              title: 'Admin Panel',
              subtitle: 'Debug sync issues',
              icon: Icons.admin_panel_settings,
              onTap: () async {
                PinpointHaptics.medium();
                final authenticated = await showDialog<bool>(
                  context: context,
                  builder: (context) => const AdminPasswordDialog(),
                );
                if (authenticated == true && mounted) {
                  AppNavigation.router.push(AdminPanelScreen.kRouteName);
                }
              },
            ),
          ],

          const SizedBox(height: PinpointSpacing.xl),

          // About Section
          _SectionHeader(title: 'ABOUT'),
          const SizedBox(height: PinpointSpacing.md),
          _SettingsTile(
            title: 'About Pinpoint',
            subtitle: 'App info, version & developer',
            icon: Icons.info_rounded,
            onTap: () {
              PinpointHaptics.medium();
              _showAboutDialog(context);
            },
          ),
          const SizedBox(height: PinpointSpacing.md),
          _SettingsTile(
            title: 'Terms & Privacy',
            icon: Icons.policy_rounded,
            onTap: () {
              PinpointHaptics.medium();
              AppNavigation.router.push(
                TermsAcceptanceScreen.kRouteName,
                extra: true, // isViewOnly = true
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Section Header Widget
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

/// Premium Section with enhanced design
class _PremiumSection extends StatelessWidget {
  final SubscriptionManager subscriptionManager;
  final VoidCallback onManageSubscription;

  const _PremiumSection({
    required this.subscriptionManager,
    required this.onManageSubscription,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isPremium = subscriptionManager.isPremium;
    final isInGracePeriod = subscriptionManager.isInGracePeriod;
    final gracePeriodMessage = isInGracePeriod ? PremiumService().getGracePeriodMessage() : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grace Period Warning Banner
        if (isInGracePeriod && gracePeriodMessage != null) ...[
          Container(
              padding: const EdgeInsets.all(PinpointSpacing.md),
              margin: const EdgeInsets.only(bottom: PinpointSpacing.md),
              decoration: BoxDecoration(
                color: PinpointColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: PinpointColors.warning.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: PinpointColors.warning,
                    size: 24,
                  ),
                  const SizedBox(width: PinpointSpacing.ms),
                  Expanded(
                    child: Text(
                      gracePeriodMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: PinpointColors.warningDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],

        // Premium Card
        BrutalistCard(
          variant: BrutalistCardVariant.layered,
          customColor: isPremium
              ? cs.primaryContainer.withValues(alpha: 0.3)
              : cs.surface,
          customBorderColor: isPremium
              ? cs.primary.withValues(alpha: 0.3)
              : cs.outline.withValues(alpha: 0.1),
          onTap: () {
            PinpointHaptics.medium();
            AppNavigation.router.push(SubscriptionScreen.kRouteName);
          },
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isPremium
                      ? PinpointColors.mint.withValues(alpha: 0.2)
                      : cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPremium ? Icons.workspace_premium : Icons.star_outline,
                  color: isPremium ? PinpointColors.mint : cs.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: PinpointSpacing.md),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPremium
                          ? isInGracePeriod
                              ? 'Premium (Grace Period)'
                              : 'Premium Active'
                          : 'Upgrade to Premium',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPremium
                          ? isInGracePeriod
                              ? 'Update payment method'
                              : 'Thank you for your support!'
                          : 'Unlock unlimited features',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),

              // Badge or Arrow
              if (isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isInGracePeriod
                        ? PinpointColors.warning
                        : PinpointColors.mint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    subscriptionManager.subscriptionTier.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
            ],
          ),
        ),

        // Manage Subscription button (only for premium users)
        if (isPremium) ...[
          const SizedBox(height: PinpointSpacing.md),
          _SettingsTile(
            title: 'Manage Subscription',
            subtitle: 'View in Google Play Store',
            icon: Icons.manage_accounts_rounded,
            onTap: () {
              PinpointHaptics.medium();
              onManageSubscription();
            },
          ),
        ],
      ],
    );
  }
}

/// Compact Usage Limits Card
class _UsageLimitsCard extends StatelessWidget {
  const _UsageLimitsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final premiumService = PremiumService();

    final syncedNotes = premiumService.getSyncedNotesCount();
    final ocrScans = premiumService.getOcrScansThisMonth();
    final exports = premiumService.getExportsThisMonth();

    return BrutalistCard(
      variant: BrutalistCardVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Usage Limits',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: PinpointSpacing.lg),

          // Cloud Sync (Total limit - doesn't reset)
          _UsageLimitRow(
            icon: Icons.cloud_sync_rounded,
            label: 'Cloud Sync',
            used: syncedNotes,
            limit: PremiumLimits.maxSyncedNotesForFree,
            isMonthly: false,
          ),
          const SizedBox(height: PinpointSpacing.xs),
          // Note about Cloud Sync not resetting
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              'Total limit (doesn\'t reset)',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: PinpointSpacing.md),

          // Monthly Limits Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly Limits',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary.withValues(alpha: 0.8),
                ),
              ),
              _MonthlyResetIndicator(),
            ],
          ),
          const SizedBox(height: PinpointSpacing.ms),

          // OCR Scans
          _UsageLimitRow(
            icon: Icons.document_scanner_rounded,
            label: 'OCR Scans',
            used: ocrScans,
            limit: PremiumLimits.maxOcrScansPerMonthForFree,
            isMonthly: true,
          ),
          const SizedBox(height: PinpointSpacing.md),

          // Exports
          _UsageLimitRow(
            icon: Icons.file_download_rounded,
            label: 'Exports',
            used: exports,
            limit: PremiumLimits.maxExportsPerMonthForFree,
            isMonthly: true,
          ),
        ],
      ),
    );
  }
}

/// Usage Limit Row Component
class _UsageLimitRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int used;
  final int limit;
  final bool isMonthly;

  const _UsageLimitRow({
    required this.icon,
    required this.label,
    required this.used,
    required this.limit,
    required this.isMonthly,
  });

  Color _getProgressColor(double percentage) {
    if (percentage >= 0.9) return PinpointColors.rose;
    if (percentage >= 0.7) return PinpointColors.amber;
    return PinpointColors.mint;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final percentage = (used / limit).clamp(0.0, 1.0);
    final progressColor = _getProgressColor(percentage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: cs.primary, size: 18),
            const SizedBox(width: PinpointSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$used / $limit',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: progressColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: PinpointSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 6,
            backgroundColor: cs.outline.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
      ],
    );
  }
}

/// Monthly Reset Indicator
class _MonthlyResetIndicator extends StatelessWidget {
  const _MonthlyResetIndicator();

  String _getResetCountdown() {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final difference = nextMonth.difference(now);

    if (difference.inDays > 0) {
      return 'Resets in ${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return 'Resets in ${difference.inHours}h';
    } else {
      return 'Resets soon';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PinpointSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.refresh_rounded,
            size: 12,
            color: cs.primary,
          ),
          const SizedBox(width: 4),
          Text(
            _getResetCountdown(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// Settings Tile Component
class _SettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return BrutalistCard(
      variant: BrutalistCardVariant.elevated,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: ListTile(
        leading: Icon(icon, color: cs.primary, size: 22),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              )
            : null,
        trailing: trailing ??
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: PinpointSpacing.md,
          vertical: 4,
        ),
      ),
    );
  }
}

/// Profile Card
class _ProfileCard extends StatelessWidget {
  final BackendAuthService backendAuth;

  const _ProfileCard({required this.backendAuth});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Consumer<SubscriptionManager>(
      builder: (context, subscriptionManager, child) {
        return BrutalistCard(
          variant: BrutalistCardVariant.elevated,
          customColor: cs.primaryContainer.withValues(alpha: 0.2),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: cs.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: PinpointSpacing.md),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      backendAuth.userEmail ?? 'User',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          subscriptionManager.isPremium
                              ? Icons.workspace_premium
                              : Icons.account_circle_outlined,
                          size: 14,
                          color: subscriptionManager.isPremium
                              ? PinpointColors.mint
                              : cs.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          subscriptionManager.isPremium
                              ? 'Premium Member'
                              : 'Free Account',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: subscriptionManager.isPremium
                                ? PinpointColors.mint
                                : cs.onSurface.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Manual Sync Button
class _ManualSyncButton extends StatefulWidget {
  const _ManualSyncButton();

  @override
  State<_ManualSyncButton> createState() => _ManualSyncButtonState();
}

class _ManualSyncButtonState extends State<_ManualSyncButton> {
  bool _isSyncing = false;

  Future<void> _performManualSync() async {
    setState(() => _isSyncing = true);

    try {
      final syncManager = getIt<SyncManager>();
      final result = await syncManager.sync();

      if (!mounted) return;

      // Show result dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.error,
                color: result.success ? PinpointColors.success : PinpointColors.error,
              ),
              const SizedBox(width: PinpointSpacing.sm),
              Expanded(
                child: Text(result.success ? 'Sync Complete' : 'Sync Failed'),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.success) ...[
                if (result.notesSynced > 0)
                  _buildSyncStat('Notes', result.notesSynced, Icons.note),
                if (result.foldersSynced > 0) ...[
                  const SizedBox(height: PinpointSpacing.sm),
                  _buildSyncStat('Folders', result.foldersSynced, Icons.folder),
                ],
                if (result.remindersSynced > 0) ...[
                  const SizedBox(height: PinpointSpacing.sm),
                  _buildSyncStat('Reminders', result.remindersSynced, Icons.alarm),
                ],
                if (result.notesSynced == 0 &&
                    result.foldersSynced == 0 &&
                    result.remindersSynced == 0)
                  const Text('Everything is already up to date.'),
              ] else
                Text(result.message),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: PinpointColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Widget _buildSyncStat(String label, int count, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: PinpointColors.info),
        const SizedBox(width: PinpointSpacing.sm),
        Text('$label: '),
        Text(
          '$count',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: PinpointColors.success,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      title: 'Sync Now',
      subtitle: 'Pull latest data from server',
      icon: _isSyncing ? Icons.sync : Icons.cloud_download_rounded,
      trailing: _isSyncing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: _isSyncing ? () {} : _performManualSync,
    );
  }
}

/// Logout Button
class _LogoutButton extends StatefulWidget {
  final BackendAuthService backendAuth;

  const _LogoutButton({required this.backendAuth});

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _isLoggingOut = false;
  String _logoutStatus = 'Preparing...';
  LogoutService? _logoutService;

  Future<void> _handleLogout(BuildContext context) async {
    if (_isLoggingOut) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out? Your notes will remain synced in the cloud.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: PinpointColors.rose,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    _logoutService = LogoutService.fromServiceLocator(
      backendAuthService: widget.backendAuth,
      googleSignInService: GoogleSignInService(),
    );

    _logoutService!.onPhaseChanged = (phase) {
      if (mounted) {
        setState(() {
          _logoutStatus = _getPhaseMessage(phase);
        });
      }
    };

    setState(() {
      _isLoggingOut = true;
      _logoutStatus = 'Validating...';
    });

    try {
      final validation = await _logoutService!.validateLogout();

      if (!validation.canProceed) {
        if (mounted) {
          await _showValidationErrorDialog(context, validation);
          setState(() {
            _isLoggingOut = false;
          });
        }
        return;
      }

      final unsyncedCount = await _logoutService!.getUnsyncedNotesCount();
      if (unsyncedCount > 0) {
        setState(() {
          _logoutStatus =
              'Syncing $unsyncedCount note${unsyncedCount > 1 ? 's' : ''}...';
        });
      }

      final success = await _logoutService!.performLogout();

      if (success && context.mounted) {
        PinpointHaptics.success();
        AppNavigation.router.go('/auth');

        Future.delayed(const Duration(milliseconds: 500), () {
          if (context.mounted) {
            showSuccessToast(
              context: context,
              title: 'Signed Out',
              description: 'You have been signed out successfully.',
            );
          }
        });
      }
    } catch (e) {
      if (context.mounted) {
        if (e.toString().contains('Sync failed') ||
            e.toString().contains('sync') ||
            e.toString().contains('network')) {
          final forceLogout = await _showSyncErrorDialog(context, e.toString());

          if (forceLogout == true) {
            PinpointHaptics.warning();
            AppNavigation.router.go('/auth');

            Future.delayed(const Duration(milliseconds: 500), () {
              if (context.mounted) {
                showWarningToast(
                  context: context,
                  title: 'Signed Out',
                  description: 'Signed out with unsynced changes.',
                );
              }
            });
          }
        } else {
          PinpointHaptics.error();
          showErrorToast(
            context: context,
            title: 'Sign Out Failed',
            description: e.toString().replaceAll('Exception: ', ''),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
          _logoutStatus = 'Preparing...';
        });
      }
    }
  }

  String _getPhaseMessage(LogoutPhase phase) {
    switch (phase) {
      case LogoutPhase.validating:
        return 'Validating...';
      case LogoutPhase.syncing:
        return 'Syncing notes...';
      case LogoutPhase.signingOut:
        return 'Signing out from server...';
      case LogoutPhase.cleaningData:
        return 'Clearing local data...';
      case LogoutPhase.completed:
        return 'Completed';
    }
  }

  Future<void> _showValidationErrorDialog(
    BuildContext context,
    LogoutValidationResult validation,
  ) async {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: PinpointColors.amber,
          size: 48,
        ),
        title: const Text('Cannot Sign Out'),
        content: Text(
          validation.blockReason == LogoutBlockReason.audioNotesExist
              ? 'You have ${validation.audioNotesCount} audio recording${validation.audioNotesCount! > 1 ? 's' : ''} that are stored locally only and will be lost forever.\n\nPlease backup or delete your audio recordings before signing out.'
              : validation.errorMessage ?? 'Unable to sign out at this time.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showSyncErrorDialog(BuildContext context, String error) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.sync_problem_rounded,
          color: PinpointColors.rose,
          size: 48,
        ),
        title: const Text('Sync Failed'),
        content: Text(
          'Failed to sync your notes:\n\n${error.replaceAll('Exception: ', '')}\n\nYour unsynced changes will be lost if you sign out now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: PinpointColors.rose,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Force Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return BrutalistCard(
      variant: BrutalistCardVariant.outlined,
      customBorderColor: PinpointColors.rose.withValues(alpha: 0.3),
      padding: EdgeInsets.zero,
      onTap: _isLoggingOut ? null : () => _handleLogout(context),
      child: ListTile(
        leading: _isLoggingOut
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                Icons.logout_rounded,
                color: PinpointColors.rose,
                size: 22,
              ),
        title: Text(
          _isLoggingOut ? 'Signing Out...' : 'Sign Out',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: PinpointColors.rose,
          ),
        ),
        subtitle: Text(
          _isLoggingOut ? _logoutStatus : 'Sign out of your account',
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: _isLoggingOut
            ? null
            : Icon(
                Icons.chevron_right_rounded,
                color: PinpointColors.rose.withValues(alpha: 0.6),
              ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: PinpointSpacing.md,
          vertical: 4,
        ),
      ),
    );
  }
}

/// Linked Accounts Section
class _LinkedAccountsSection extends StatefulWidget {
  final BackendAuthService backendAuth;

  const _LinkedAccountsSection({required this.backendAuth});

  @override
  State<_LinkedAccountsSection> createState() => _LinkedAccountsSectionState();
}

class _LinkedAccountsSectionState extends State<_LinkedAccountsSection> {
  bool _isLoading = false;
  Map<String, dynamic>? _providers;
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    _loadProviders(showLoading: true);
  }

  @override
  void didUpdateWidget(_LinkedAccountsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.backendAuth.isAuthenticated !=
        oldWidget.backendAuth.isAuthenticated) {
      _loadProviders(showLoading: true);
    }
  }

  Future<void> _loadProviders({bool showLoading = false}) async {
    if (!widget.backendAuth.isAuthenticated) return;

    if (_hasLoadedOnce && !showLoading) {
      try {
        final providers = await widget.backendAuth.getAuthProviders();
        if (mounted) {
          setState(() {
            _providers = providers;
          });
        }
      } catch (e) {
        debugPrint('Error loading auth providers: $e');
      }
      return;
    }

    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final providers = await widget.backendAuth.getAuthProviders();
      if (mounted) {
        setState(() {
          _providers = providers;
          _isLoading = false;
          _hasLoadedOnce = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading auth providers: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _linkGoogleAccount() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final googleSignInService = GoogleSignInService();
      final userCredential = await googleSignInService.signInWithGoogle();

      if (userCredential == null) {
        throw Exception('Google Sign-In was cancelled');
      }

      final firebaseToken = await googleSignInService.getFirebaseIdToken();

      if (firebaseToken == null) {
        throw Exception('Failed to get Firebase token');
      }

      if (!mounted) return;

      final password = await showDialog<String>(
        context: context,
        builder: (context) => _PasswordDialog(),
      );

      if (password == null || password.isEmpty) {
        return;
      }

      await widget.backendAuth.linkGoogleAccount(
        firebaseToken: firebaseToken,
        password: password,
      );

      await _loadProviders(showLoading: false);

      if (mounted) {
        PinpointHaptics.success();
        showSuccessToast(
          context: context,
          title: 'Account Linked',
          description: 'Your Google account has been linked successfully.',
        );
      }
    } catch (e) {
      if (mounted) {
        PinpointHaptics.error();
        showErrorToast(
          context: context,
          title: 'Linking Failed',
          description: e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _unlinkGoogleAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlink Google Account'),
        content: const Text(
          'Are you sure you want to unlink your Google account? '
          'You can always link it again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.backendAuth.unlinkGoogleAccount();
      await _loadProviders(showLoading: false);

      if (mounted) {
        PinpointHaptics.success();
        showSuccessToast(
          context: context,
          title: 'Account Unlinked',
          description: 'Your Google account has been unlinked.',
        );
      }
    } catch (e) {
      if (mounted) {
        PinpointHaptics.error();
        showErrorToast(
          context: context,
          title: 'Unlinking Failed',
          description: e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_providers == null) {
      return const SizedBox.shrink();
    }

    final hasGoogle = _providers!['has_google'] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Email Provider
        _AuthProviderTile(
          icon: Icons.email_rounded,
          title: 'Email',
          subtitle: widget.backendAuth.userEmail ?? 'Email authentication',
          isLinked: true,
          isLoading: false,
        ),
        const SizedBox(height: PinpointSpacing.md),

        // Google Provider
        _AuthProviderTile(
          icon: Icons.g_mobiledata_rounded,
          title: 'Google',
          subtitle: hasGoogle ? 'Linked to your account' : 'Link for easy sign-in',
          isLinked: hasGoogle,
          isLoading: _isLoading,
          onTap: _isLoading ? null : (hasGoogle ? null : _linkGoogleAccount),
          onUnlink: hasGoogle && !_isLoading ? _unlinkGoogleAccount : null,
        ),
      ],
    );
  }
}

/// Auth Provider Tile
class _AuthProviderTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLinked;
  final bool isLoading;
  final VoidCallback? onTap;
  final VoidCallback? onUnlink;

  const _AuthProviderTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isLinked,
    required this.isLoading,
    this.onTap,
    this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return BrutalistCard(
      variant: BrutalistCardVariant.elevated,
      customBorderColor: isLinked
          ? PinpointColors.mint.withValues(alpha: 0.3)
          : cs.outline.withValues(alpha: 0.1),
      padding: const EdgeInsets.all(PinpointSpacing.md),
      onTap: onTap,
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isLinked
                  ? PinpointColors.mint.withValues(alpha: 0.2)
                  : cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isLinked ? PinpointColors.mint : cs.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: PinpointSpacing.ms),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isLinked) ...[
                      const SizedBox(width: PinpointSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: PinpointColors.mint.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Linked',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: PinpointColors.mint,
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Actions
          if (isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (onUnlink != null)
            IconButton(
              icon: Icon(
                Icons.link_off_rounded,
                color: PinpointColors.rose,
                size: 20,
              ),
              onPressed: onUnlink,
              tooltip: 'Unlink account',
            )
          else if (onTap != null && !isLinked)
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
        ],
      ),
    );
  }
}

/// Password Dialog for account linking
class _PasswordDialog extends StatefulWidget {
  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Verify Your Password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter your password to link your Google account:',
          ),
          const SizedBox(height: PinpointSpacing.md),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final password = _passwordController.text;
            if (password.isNotEmpty) {
              Navigator.of(context).pop(password);
            }
          },
          child: const Text('Verify'),
        ),
      ],
    );
  }
}
