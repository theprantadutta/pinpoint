import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:pinpoint/main.dart';
import 'package:pinpoint/screens/archive_screen.dart';
import 'package:pinpoint/screens/sync_screen.dart';
import 'package:pinpoint/screens/trash_screen.dart';
import 'package:pinpoint/screens/subscription_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:pinpoint/services/drift_note_service.dart';
import 'package:pinpoint/services/subscription_manager.dart';
import 'package:pinpoint/services/app_review_service.dart';
import 'package:pinpoint/services/firebase_notification_service.dart';
import 'package:pinpoint/services/backend_auth_service.dart';
import 'package:pinpoint/services/google_sign_in_service.dart';
import 'package:pinpoint/services/logout_service.dart';
import 'package:pinpoint/util/show_a_toast.dart';
import 'package:pinpoint/screens/theme_screen.dart';
import 'package:pinpoint/screens/language_screen.dart';
import 'package:pinpoint/screens/encryption_settings_screen.dart';
import 'package:pinpoint/screens/terms_acceptance_screen.dart';
import 'package:pinpoint/screens/admin_panel_screen.dart';
import 'package:pinpoint/widgets/admin_password_dialog.dart';
import 'package:provider/provider.dart';
import '../design_system/design_system.dart';
import '../generated/l10n/app_localizations.dart';
import '../services/analytics/analytics_facade.dart';
import '../services/locale_controller.dart';
import '../util/localized_dates.dart';
import '../services/premium_service.dart';
import '../constants/premium_limits.dart';
import '../navigation/app_navigation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../sync/sync_manager.dart';
import '../service_locators/init_service_locators.dart';
import '../services/walkthrough_service.dart';

class SettingsScreen extends StatefulWidget {
  static const String kRouteName = '/settings';
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    getIt<AnalyticsFacade>().trackScreenView(screenName: 'Settings');
  }

  Future<void> _openManageSubscriptions() async {
    try {
      // App Store on iOS, Google Play on Android — store policy requires the
      // correct destination for managing/cancelling a subscription.
      final uri = Uri.parse(
        Platform.isIOS
            ? 'https://apps.apple.com/account/subscriptions'
            : 'https://play.google.com/store/account/subscriptions',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch subscriptions page';
      }
    } catch (e) {
      if (mounted) {
        showErrorToast(
          context: context,
          title: AppL10n.of(context).setErrorTitle,
          description: Platform.isIOS
              ? AppL10n.of(context).setCannotOpenAppStoreSubs
              : AppL10n.of(context).setCannotOpenPlaySubs,
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
                  AppL10n.of(context).setAboutVersion(version, buildNumber),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: PinpointSpacing.lg),

              // Description
              Text(
                AppL10n.of(context).setAboutTagline,
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
                    AppL10n.of(context).setAboutDevelopedBy,
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
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showErrorToast(
                            context: context,
                            title: AppL10n.of(context).setErrorTitle,
                            description: AppL10n.of(context).setUnableToOpenPortfolio,
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
                  child: Text(AppL10n.of(context).commonClose),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Subtitle for the Language row: the chosen language's own name, or the
  /// "system default" wording when the user hasn't pinned one.
  String _currentLanguageLabel(BuildContext context) {
    final locale = context.watch<LocaleController>().locale;
    return locale == null
        ? AppL10n.of(context).languageSystemDefault
        : LocaleController.displayName(locale);
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
            Text(AppL10n.of(context).setTitle),
          ],
        ),
      ),
      body: ResponsiveCenter(
        child: ListView(
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
                  onManageSubscription: _openManageSubscriptions,
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
                      _SectionHeader(title: AppL10n.of(context).setSectionAccount),
                      const SizedBox(height: PinpointSpacing.md),
                      _SettingsTile(
                        title: AppL10n.of(context).setSignIn,
                        subtitle: AppL10n.of(context).setSignInSubtitle,
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
                    _SectionHeader(title: AppL10n.of(context).setSectionAccountSync),
                    const SizedBox(height: PinpointSpacing.md),
                    _ProfileCard(backendAuth: backendAuth),
                    const SizedBox(height: PinpointSpacing.md),
                    _ManualSyncButton(),
                    const SizedBox(height: PinpointSpacing.md),

                    // Sync Debug Info - only in debug mode
                    if (kDebugMode) ...[
                      _SettingsTile(
                        title: AppL10n.of(context).setSyncDebug,
                        subtitle: AppL10n.of(context).setSyncDebugSubtitle,
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
                    _SectionHeader(title: AppL10n.of(context).setSectionUsage),
                    const SizedBox(height: PinpointSpacing.md),
                    const _UsageLimitsCard(),
                    const SizedBox(height: PinpointSpacing.xl),
                  ],
                );
              },
            ),

            // Appearance Section
            _SectionHeader(title: AppL10n.of(context).setSectionAppearance),
            const SizedBox(height: PinpointSpacing.md),
            _SettingsTile(
              title: AppL10n.of(context).setTheme,
              subtitle: AppL10n.of(context).setThemeSubtitle,
              icon: Icons.color_lens_rounded,
              onTap: () {
                PinpointHaptics.medium();
                AppNavigation.router.push(ThemeScreen.kRouteName);
              },
            ),
            const SizedBox(height: PinpointSpacing.md),
            _SettingsTile(
              title: AppL10n.of(context).settingsLanguageTitle,
              subtitle: _currentLanguageLabel(context),
              icon: Icons.translate_rounded,
              onTap: () {
                PinpointHaptics.medium();
                AppNavigation.router.push(LanguageScreen.kRouteName);
              },
            ),

            const SizedBox(height: PinpointSpacing.xl),

            // Content Section
            _SectionHeader(title: AppL10n.of(context).setSectionContent),
            const SizedBox(height: PinpointSpacing.md),
            _SettingsTile(
              title: AppL10n.of(context).setMyFolders,
              icon: Icons.folder_rounded,
              onTap: () {
                PinpointHaptics.medium();
                AppNavigation.router.push('/my-folders');
              },
            ),
            const SizedBox(height: PinpointSpacing.md),
            _SettingsTile(
              title: AppL10n.of(context).setArchive,
              icon: Icons.archive_rounded,
              onTap: () {
                PinpointHaptics.medium();
                AppNavigation.router.push(ArchiveScreen.kRouteName);
              },
            ),
            const SizedBox(height: PinpointSpacing.md),
            _SettingsTile(
              title: AppL10n.of(context).setTrash,
              icon: Icons.delete_rounded,
              onTap: () {
                PinpointHaptics.medium();
                AppNavigation.router.push(TrashScreen.kRouteName);
              },
            ),
            const SizedBox(height: PinpointSpacing.md),
            _SettingsTile(
              title: AppL10n.of(context).setSyncSettings,
              icon: Icons.sync_rounded,
              onTap: () {
                PinpointHaptics.medium();
                AppNavigation.router.push(SyncScreen.kRouteName);
              },
            ),

            const SizedBox(height: PinpointSpacing.xl),

            // Security Section
            _SectionHeader(title: AppL10n.of(context).setSectionSecurity),
            const SizedBox(height: PinpointSpacing.md),
            _SettingsTile(
              title: AppL10n.of(context).setBiometricLock,
              subtitle:
                  MyApp.of(context).isBiometricEnabled ? AppL10n.of(context).commonEnabled : AppL10n.of(context).commonDisabled,
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
            const SizedBox(height: PinpointSpacing.md),
            _SettingsTile(
              title: AppL10n.of(context).setEncryption,
              subtitle: AppL10n.of(context).setEncryptionSubtitle,
              icon: Icons.enhanced_encryption_rounded,
              onTap: () {
                PinpointHaptics.light();
                AppNavigation.router.push(EncryptionSettingsScreen.kRouteName);
              },
            ),

            const SizedBox(height: PinpointSpacing.xl),

            // Advanced Section
            _SectionHeader(title: AppL10n.of(context).setSectionAdvanced),
            const SizedBox(height: PinpointSpacing.md),
            _SettingsTile(
              title: AppL10n.of(context).setImportNote,
              subtitle: AppL10n.of(context).setImportNoteSubtitle,
              icon: Icons.file_upload_rounded,
              onTap: () async {
                PinpointHaptics.medium();
                final result = await FilePicker.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pinpoint-note'],
                );
                if (result != null && result.files.isNotEmpty) {
                  final picked = result.files.first;
                  final path = picked.path;
                  if (path == null) {
                    return;
                  }
                  // Android's system picker does not reliably honor
                  // allowedExtensions, so users can select any file. Guard
                  // against non-.pinpoint-note files (e.g. an audio recording)
                  // whose binary contents can't be decoded as UTF-8 text.
                  final isValidExtension =
                      picked.extension?.toLowerCase() == 'pinpoint-note' ||
                          path.toLowerCase().endsWith('.pinpoint-note');
                  if (!isValidExtension) {
                    final ctx = context;
                    if (ctx.mounted) {
                      PinpointHaptics.error();
                      showErrorToast(
                        context: ctx,
                        title: AppL10n.of(context).setUnsupportedFile,
                        description:
                            AppL10n.of(context).setUnsupportedFileBody,
                      );
                    }
                    return;
                  }
                  try {
                    final file = File(path);
                    final jsonString = await file.readAsString();
                    await DriftNoteService.importNoteFromJson(jsonString);
                    final ctx = context;
                    if (ctx.mounted) {
                      PinpointHaptics.success();
                      showSuccessToast(
                        context: ctx,
                        title: AppL10n.of(context).setNoteImported,
                        description: AppL10n.of(context).setNoteImportedBody,
                      );
                    }
                  } catch (e) {
                    final ctx = context;
                    if (ctx.mounted) {
                      PinpointHaptics.error();
                      showErrorToast(
                        context: ctx,
                        title: AppL10n.of(context).setImportFailed,
                        description:
                            "This file couldn't be imported. Make sure it's a valid .pinpoint-note file.",
                      );
                    }
                  }
                }
              },
            ),

            // Test notification - only in debug mode
            if (kDebugMode) ...[
              const SizedBox(height: PinpointSpacing.md),
              _SettingsTile(
                title: AppL10n.of(context).setTestNotification,
                subtitle: AppL10n.of(context).setTestNotificationSubtitle,
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
                        description: AppL10n.of(context).setCheckNotificationTray,
                      );
                    }
                  } catch (e) {
                    final ctx = context;
                    if (ctx.mounted) {
                      showErrorToast(
                        context: ctx,
                        title: AppL10n.of(context).setFailedTitle,
                        description: e.toString(),
                      );
                    }
                  }
                },
              ),
            ],

            // Test Crash - only in debug mode
            if (kDebugMode) ...[
              const SizedBox(height: PinpointSpacing.md),
              _SettingsTile(
                title: AppL10n.of(context).setTestCrash,
                subtitle: AppL10n.of(context).setTestCrashSubtitle,
                icon: Icons.bug_report_rounded,
                onTap: () {
                  PinpointHaptics.medium();
                  FirebaseCrashlytics.instance.crash();
                },
              ),
            ],

            // Admin Panel - only visible to admin email
            if (context.read<BackendAuthService>().userEmail ==
                'prantadutta1997@gmail.com') ...[
              const SizedBox(height: PinpointSpacing.md),
              _SettingsTile(
                title: AppL10n.of(context).setAdminPanel,
                subtitle: AppL10n.of(context).setAdminPanelSubtitle,
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
            _SectionHeader(title: AppL10n.of(context).setSectionAbout),
            const SizedBox(height: PinpointSpacing.md),
            _SettingsTile(
              title: AppL10n.of(context).setAboutApp,
              subtitle: AppL10n.of(context).setAboutAppSubtitle,
              icon: Icons.info_rounded,
              onTap: () {
                PinpointHaptics.medium();
                _showAboutDialog(context);
              },
            ),
            const SizedBox(height: PinpointSpacing.md),
            _SettingsTile(
              title: AppL10n.of(context).setRateApp,
              subtitle: AppL10n.of(context).setRateAppSubtitle,
              icon: Icons.star_rounded,
              onTap: () {
                PinpointHaptics.medium();
                AppReviewService().openStoreListing();
              },
            ),
            const SizedBox(height: PinpointSpacing.md),
            _SettingsTile(
              title: AppL10n.of(context).setReplayTutorial,
              subtitle: AppL10n.of(context).setReplayTutorialSubtitle,
              icon: Icons.help_outline_rounded,
              onTap: () async {
                PinpointHaptics.medium();

                // Reset walkthrough so it will show again
                await WalkthroughService().resetWalkthrough();

                if (!context.mounted) return;

                // Return to the home screen first (settings is a pushed route)
                Navigator.of(context).pop();

                // Delay then show walkthrough
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (context.mounted) {
                    WalkthroughService().showWalkthrough(context);
                  }
                });
              },
            ),
            const SizedBox(height: PinpointSpacing.md),
            _SettingsTile(
              title: AppL10n.of(context).setTermsPrivacy,
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

  String _getPlanDisplayName(BuildContext context, String? subscriptionType) {
    switch (subscriptionType) {
      case 'monthly':
        return AppL10n.of(context).setPlanMonthly;
      case 'yearly':
        return AppL10n.of(context).setPlanYearly;
      case 'lifetime':
        return AppL10n.of(context).setPlanLifetime;
      default:
        return AppL10n.of(context).setPlanPremium;
    }
  }

  String _getExpiryText(BuildContext context, SubscriptionManager manager) {
    final l10n = AppL10n.of(context);
    if (manager.subscriptionType == 'lifetime') {
      return l10n.subscriptionNeverExpires;
    }

    final expiryDate = manager.expirationDate;
    if (expiryDate == null) return '';

    final now = DateTime.now();
    final difference = expiryDate.difference(now);

    final formattedDate = LocalizedDates.mediumDate(context, expiryDate);

    if (difference.isNegative) {
      return l10n.subscriptionExpiredOn(formattedDate);
    } else if (manager.isInGracePeriod) {
      return l10n.subscriptionPaymentPending(formattedDate);
    } else {
      return l10n.subscriptionRenews(formattedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isPremium = subscriptionManager.isPremium;
    final isInGracePeriod = subscriptionManager.isInGracePeriod;
    final gracePeriodMessage =
        isInGracePeriod ? PremiumService().getGracePeriodMessage() : null;

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
                              ? AppL10n.of(context).setPremiumGracePeriod
                              : _getPlanDisplayName(
                                  context, subscriptionManager.subscriptionType)
                          : AppL10n.of(context).setUpgradeToPremium,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPremium
                          ? isInGracePeriod
                              ? AppL10n.of(context).setUpdatePaymentMethod
                              : _getExpiryText(context, subscriptionManager)
                          : AppL10n.of(context).setUnlockUnlimited,
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
            title: AppL10n.of(context).setManageSubscription,
            subtitle: Platform.isIOS
                ? AppL10n.of(context).setViewInAppStore
                : AppL10n.of(context).setViewInPlayStore,
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
            AppL10n.of(context).setUsageLimits,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: PinpointSpacing.lg),

          // Cloud Sync (Total limit - doesn't reset)
          _UsageLimitRow(
            icon: Icons.cloud_sync_rounded,
            label: AppL10n.of(context).setUsageCloudSync,
            used: syncedNotes,
            limit: PremiumLimits.maxSyncedNotesForFree,
            isMonthly: false,
          ),
          const SizedBox(height: PinpointSpacing.xs),
          // Note about Cloud Sync not resetting
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 26),
            child: Text(
              AppL10n.of(context).setUsageTotalLimit,
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
                AppL10n.of(context).setUsageMonthlyLimits,
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
            label: AppL10n.of(context).setUsageOcrScans,
            used: ocrScans,
            limit: PremiumLimits.maxOcrScansPerMonthForFree,
            isMonthly: true,
          ),
          const SizedBox(height: PinpointSpacing.md),

          // Exports
          _UsageLimitRow(
            icon: Icons.file_download_rounded,
            label: AppL10n.of(context).setUsageExports,
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

  String _getResetCountdown(BuildContext context) {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final difference = nextMonth.difference(now);

    if (difference.inDays > 0) {
      return AppL10n.of(context).setResetsInDays(difference.inDays);
    } else if (difference.inHours > 0) {
      return AppL10n.of(context).setResetsInHours(difference.inHours);
    } else {
      return AppL10n.of(context).setResetsSoon;
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
            _getResetCountdown(context),
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
                      backendAuth.userEmail ?? AppL10n.of(context).setAccountFallbackName,
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
                              ? AppL10n.of(context).setPremiumMember
                              : AppL10n.of(context).setFreeAccount,
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

      // Check if sync service is configured
      final isConfigured = await syncManager.isConfigured();
      if (!isConfigured) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppL10n.of(context).setSyncServiceNotReady),
            backgroundColor: PinpointColors.warning,
          ),
        );
        return;
      }

      final result = await syncManager.sync();

      if (!mounted) return;

      // Determine the message to show
      String contentMessage;
      if (result.success) {
        final totalSynced =
            result.notesSynced + result.foldersSynced + result.remindersSynced;
        if (totalSynced == 0) {
          // Use the actual message from sync result (e.g., "No changes", "Sync already in progress")
          contentMessage = result.message.isNotEmpty
              ? result.message
              : AppL10n.of(context).setAlreadyUpToDate;
        } else {
          contentMessage = ''; // Will show stats instead
        }
      } else {
        contentMessage = result.message;
      }

      // Show result dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.error,
                color: result.success
                    ? PinpointColors.success
                    : PinpointColors.error,
              ),
              const SizedBox(width: PinpointSpacing.sm),
              Expanded(
                child: Text(result.success ? AppL10n.of(context).setSyncComplete : AppL10n.of(context).setSyncFailed),
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
                  _buildSyncStat(
                      'Reminders', result.remindersSynced, Icons.alarm),
                ],
                if (contentMessage.isNotEmpty) Text(contentMessage),
              ] else
                Text(result.message),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppL10n.of(context).commonOk),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppL10n.of(context).setSyncFailedWithError(e.toString())),
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
      title: AppL10n.of(context).setSyncNow,
      subtitle: AppL10n.of(context).setSyncNowSubtitle,
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
  bool _isDeleting = false;
  String _logoutStatus = '';
  LogoutService? _logoutService;

  Future<void> _handleDeleteAccount(BuildContext context) async {
    if (_isDeleting || _isLoggingOut) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppL10n.of(context).setDeleteAccount),
        content: Text(AppL10n.of(context).setDeleteAccountConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppL10n.of(context).commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: PinpointColors.rose),
            child: Text(AppL10n.of(context).setDeleteAccount),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    try {
      final logoutService = LogoutService.fromServiceLocator(
        backendAuthService: widget.backendAuth,
        googleSignInService: GoogleSignInService(),
      );
      await logoutService.performAccountDeletion();

      PinpointHaptics.success();
      AppNavigation.router.go('/auth');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (context.mounted) {
          showSuccessToast(
            context: context,
            title: AppL10n.of(context).setAccountDeleted,
            description:
                AppL10n.of(context).setAccountDeletedBody,
          );
        }
      });
    } catch (e) {
      if (mounted) setState(() => _isDeleting = false);
      if (context.mounted) {
        PinpointHaptics.error();
        showErrorToast(
          context: context,
          title: AppL10n.of(context).setDeletionFailed,
          description: AppL10n.of(context).setDeletionFailedBody,
        );
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    if (_isLoggingOut) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppL10n.of(context).setSignOut),
        content: Text(
          AppL10n.of(context).setSignOutConfirm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppL10n.of(context).commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: PinpointColors.rose,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppL10n.of(context).setSignOut),
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
      _logoutStatus = AppL10n.of(context).setLogoutValidating;
    });

    try {
      final validation = await _logoutService!.validateLogout();

      if (!validation.canProceed) {
        if (context.mounted) {
          await _showValidationErrorDialog(context, validation);
          if (mounted) {
            setState(() {
              _isLoggingOut = false;
            });
          }
        }
        return;
      }

      final unsyncedCount = await _logoutService!.getUnsyncedNotesCount();
      // Guarded like the branches above: this runs after an await, and the
      // status string now reads Localizations off the context.
      if (unsyncedCount > 0 && mounted) {
        setState(() {
          _logoutStatus = AppL10n.of(context).syncingNotes(unsyncedCount);
        });
      }

      final success = await _logoutService!.performLogout();

      if (success) {
        PinpointHaptics.success();
        // Navigate using static router - doesn't require context.mounted
        // because AppNavigation.router is a global singleton
        AppNavigation.router.go('/auth');

        // Only show toast if context is still mounted after navigation
        Future.delayed(const Duration(milliseconds: 500), () {
          if (context.mounted) {
            showSuccessToast(
              context: context,
              title: AppL10n.of(context).setSignedOut,
              description: AppL10n.of(context).setSignedOutBody,
            );
          }
        });
      } else if (context.mounted) {
        // This shouldn't normally happen since validation is done before
        // performLogout(), but handle it for safety
        PinpointHaptics.error();
        showErrorToast(
          context: context,
          title: AppL10n.of(context).setSignOutFailed,
          description: AppL10n.of(context).setSignOutFailedBody,
        );
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
                  title: AppL10n.of(context).setSignedOut,
                  description: AppL10n.of(context).setSignedOutUnsynced,
                );
              }
            });
          }
        } else {
          PinpointHaptics.error();
          showErrorToast(
            context: context,
            title: AppL10n.of(context).setSignOutFailed,
            description: e.toString().replaceAll('Exception: ', ''),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
          _logoutStatus = AppL10n.of(context).setLogoutPreparing;
        });
      }
    }
  }

  String _getPhaseMessage(LogoutPhase phase) {
    switch (phase) {
      case LogoutPhase.validating:
        return AppL10n.of(context).setLogoutValidating;
      case LogoutPhase.syncing:
        return AppL10n.of(context).setLogoutSyncing;
      case LogoutPhase.signingOut:
        return AppL10n.of(context).setLogoutServer;
      case LogoutPhase.cleaningData:
        return AppL10n.of(context).setLogoutClearing;
      case LogoutPhase.completed:
        return AppL10n.of(context).setLogoutCompleted;
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
        title: Text(AppL10n.of(context).setCannotSignOut),
        content: Text(
          validation.blockReason == LogoutBlockReason.audioNotesExist
              ? AppL10n.of(context)
                  .logoutAudioWarningDetailed(validation.audioNotesCount!)
              : validation.errorMessage ?? AppL10n.of(context).setCannotSignOutGeneric,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppL10n.of(context).commonOk),
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
        title: Text(AppL10n.of(context).setSyncFailed),
        content: Text(
          AppL10n.of(context).setSyncFailedBeforeSignOut(error.replaceAll('Exception: ', '')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(AppL10n.of(context).commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: PinpointColors.rose,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppL10n.of(context).setForceSignOut),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrutalistCard(
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
              _isLoggingOut ? AppL10n.of(context).setSigningOut : AppL10n.of(context).setSignOut,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: PinpointColors.rose,
              ),
            ),
            subtitle: Text(
              _isLoggingOut ? _logoutStatus : AppL10n.of(context).setSignOutSubtitle,
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
        ),
        const SizedBox(height: PinpointSpacing.sm),
        _buildDeleteAccountCard(context, theme, cs),
      ],
    );
  }

  Widget _buildDeleteAccountCard(
      BuildContext context, ThemeData theme, ColorScheme cs) {
    return BrutalistCard(
      variant: BrutalistCardVariant.outlined,
      customBorderColor: PinpointColors.rose.withValues(alpha: 0.3),
      padding: EdgeInsets.zero,
      onTap: (_isDeleting || _isLoggingOut)
          ? null
          : () => _handleDeleteAccount(context),
      child: ListTile(
        leading: _isDeleting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                Icons.delete_forever_rounded,
                color: PinpointColors.rose,
                size: 22,
              ),
        title: Text(
          _isDeleting ? AppL10n.of(context).setDeletingAccount : AppL10n.of(context).setDeleteAccount,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: PinpointColors.rose,
          ),
        ),
        subtitle: Text(
          _isDeleting
              ? AppL10n.of(context).setPleaseWait
              : AppL10n.of(context).setDeleteAccountSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: _isDeleting
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

    // Resolved before the awaits below: these strings are read off the
    // BuildContext, which may be defunct by the time a failure surfaces.
    final l10n = AppL10n.of(context);
    final cancelledMessage = l10n.setGoogleSignInCancelled;
    final tokenFailedMessage = l10n.authFirebaseTokenFailed;

    try {
      final googleSignInService = GoogleSignInService();
      final userCredential = await googleSignInService.signInWithGoogle();

      if (userCredential == null) {
        throw Exception(cancelledMessage);
      }

      final firebaseToken = await googleSignInService.getFirebaseIdToken();

      if (firebaseToken == null) {
        throw Exception(tokenFailedMessage);
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
          title: AppL10n.of(context).setAccountLinked,
          description: AppL10n.of(context).setAccountLinkedBody,
        );
      }
    } catch (e) {
      if (mounted) {
        PinpointHaptics.error();
        showErrorToast(
          context: context,
          title: AppL10n.of(context).setLinkingFailed,
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
        title: Text(AppL10n.of(context).setUnlinkGoogleTitle),
        content: Text(
          AppL10n.of(context).setUnlinkGoogleConfirm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppL10n.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppL10n.of(context).setUnlink),
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
          title: AppL10n.of(context).setAccountUnlinked,
          description: AppL10n.of(context).setAccountUnlinkedBody,
        );
      }
    } catch (e) {
      if (mounted) {
        PinpointHaptics.error();
        showErrorToast(
          context: context,
          title: AppL10n.of(context).setUnlinkingFailed,
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
          title: AppL10n.of(context).setProviderEmail,
          subtitle: widget.backendAuth.userEmail ?? AppL10n.of(context).setProviderEmailSubtitle,
          isLinked: true,
          isLoading: false,
        ),
        const SizedBox(height: PinpointSpacing.md),

        // Google Provider
        _AuthProviderTile(
          icon: Icons.g_mobiledata_rounded,
          title: AppL10n.of(context).setProviderGoogle,
          subtitle:
              hasGoogle ? AppL10n.of(context).setProviderLinked : AppL10n.of(context).setProviderLinkPrompt,
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
                          AppL10n.of(context).setLinkedBadge,
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
              tooltip: AppL10n.of(context).setUnlinkTooltip,
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
      title: Text(AppL10n.of(context).setVerifyPasswordTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppL10n.of(context).setVerifyPasswordPrompt,
          ),
          const SizedBox(height: PinpointSpacing.md),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofocus: true,
            decoration: InputDecoration(
              labelText: AppL10n.of(context).authPasswordLabel,
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
          child: Text(AppL10n.of(context).commonCancel),
        ),
        FilledButton(
          onPressed: () {
            final password = _passwordController.text;
            if (password.isNotEmpty) {
              Navigator.of(context).pop(password);
            }
          },
          child: Text(AppL10n.of(context).setVerify),
        ),
      ],
    );
  }
}
