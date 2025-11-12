import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:pinpoint/constants/shared_preference_keys.dart';
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
import 'package:pinpoint/util/show_a_toast.dart';
import 'package:pinpoint/screens/theme_screen.dart';
import 'package:pinpoint/screens/terms_acceptance_screen.dart';
import 'package:pinpoint/screens/admin_panel_screen.dart';
import 'package:pinpoint/widgets/admin_password_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../design_system/design_system.dart';
import '../services/premium_service.dart';
import '../constants/premium_limits.dart';
import '../navigation/app_navigation.dart';
import 'package:url_launcher/url_launcher.dart';

class AccountScreen extends StatefulWidget {
  static const String kRouteName = '/account';
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  String _viewType = 'list';
  String _sortType = 'updatedAt';
  String _sortDirection = 'desc';
  SharedPreferences? _preferences;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _preferences = await SharedPreferences.getInstance();
    setState(() {
      _viewType = _preferences?.getString(kHomeScreenViewTypeKey) ?? 'list';
      _sortType =
          _preferences?.getString(kHomeScreenSortTypeKey) ?? 'updatedAt';
      _sortDirection =
          _preferences?.getString(kHomeScreenSortDirectionKey) ?? 'desc';
    });
  }

  Future<void> _setViewType(String value) async {
    await _preferences?.setString(kHomeScreenViewTypeKey, value);
    setState(() {
      _viewType = value;
    });
  }

  Future<void> _setSortType(String? value) async {
    if (value == null) return;
    await _preferences?.setString(kHomeScreenSortTypeKey, value);
    setState(() {
      _sortType = value;
    });
  }

  Future<void> _setSortDirection(String? value) async {
    if (value == null) return;
    await _preferences?.setString(kHomeScreenSortDirectionKey, value);
    setState(() {
      _sortDirection = value;
    });
  }

  Future<void> _openGooglePlaySubscriptions() async {
    try {
      final uri = Uri.parse('https://play.google.com/store/account/subscriptions');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GradientScaffold(
      appBar: GlassAppBar(
        title: Row(
          children: [
            Icon(Icons.settings_rounded, color: cs.primary, size: 20),
            const SizedBox(width: 8),
            const Text('Settings'),
          ],
        ),
      ),
      body: ListView(
        padding:
            const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
        children: [
          // Profile/Branding Section
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary.withValues(alpha: 0.1),
                  cs.primary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: cs.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Image.asset(
                      'assets/images/pinpoint-logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pinpoint',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your thoughts, perfectly organized',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Subscription Section
          Consumer<SubscriptionManager>(
            builder: (context, subscriptionManager, child) {
              final premiumService = PremiumService();
              final gracePeriodMessage = premiumService.getGracePeriodMessage();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subscription',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Grace Period Warning Banner
                  if (subscriptionManager.isInGracePeriod && gracePeriodMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              gracePeriodMessage,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  _SettingsTile(
                    title: subscriptionManager.isPremium
                        ? subscriptionManager.isInGracePeriod
                            ? 'Premium (Grace Period)'
                            : 'Premium Active'
                        : 'Upgrade to Premium',
                    subtitle: subscriptionManager.isPremium
                        ? subscriptionManager.isInGracePeriod
                            ? 'Update payment method'
                            : 'Thank you for your support!'
                        : 'Unlock all features',
                    icon: subscriptionManager.isPremium
                        ? Icons.workspace_premium
                        : Icons.star_outline,
                    trailing: subscriptionManager.isPremium
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: subscriptionManager.isInGracePeriod
                                  ? Colors.orange
                                  : PinpointColors.mint,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              subscriptionManager.subscriptionTier
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          )
                        : null,
                    onTap: () {
                      PinpointHaptics.medium();
                      AppNavigation.router.push(SubscriptionScreen.kRouteName);
                    },
                  ),
                  // Manage Subscription button (only for premium users)
                  if (subscriptionManager.isPremium) ...[
                    const SizedBox(height: 8),
                    _SettingsTile(
                      title: 'Manage Subscription',
                      subtitle: 'View in Google Play Store',
                      icon: Icons.manage_accounts_rounded,
                      onTap: () {
                        PinpointHaptics.medium();
                        _openGooglePlaySubscriptions();
                      },
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              );
            },
          ),

          // Usage Limits Section
          _UsageLimitsSection(),

          const SizedBox(height: 32),

          // Account Section
          Consumer<BackendAuthService>(
            // Use child parameter to preserve _LinkedAccountsSection across rebuilds
            child: Consumer<BackendAuthService>(
              builder: (context, auth, _) => _LinkedAccountsSection(backendAuth: auth),
            ),
            builder: (context, backendAuth, linkedAccountsChild) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Profile Card
                  if (backendAuth.isAuthenticated) ...[
                    _ProfileHeaderCard(backendAuth: backendAuth),
                    const SizedBox(height: 12),
                  ],

                  // Reuse the preserved child widget
                  if (linkedAccountsChild != null) linkedAccountsChild,

                  // Logout Button
                  if (backendAuth.isAuthenticated) ...[
                    const SizedBox(height: 12),
                    _LogoutButton(backendAuth: backendAuth),
                  ],

                  const SizedBox(height: 32),
                ],
              );
            },
          ),

          // General Section
          Text(
            'General',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            title: 'My Folders',
            icon: Icons.folder_rounded,
            onTap: () {
              PinpointHaptics.medium();
              AppNavigation.router.push('/my-folders');
            },
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            title: 'Archive',
            icon: Icons.archive_rounded,
            onTap: () {
              PinpointHaptics.medium();
              AppNavigation.router.push(ArchiveScreen.kRouteName);
            },
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            title: 'Trash',
            icon: Icons.delete_rounded,
            onTap: () {
              PinpointHaptics.medium();
              AppNavigation.router.push(TrashScreen.kRouteName);
            },
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            title: 'Sync',
            icon: Icons.sync_rounded,
            onTap: () {
              PinpointHaptics.medium();
              AppNavigation.router.push(SyncScreen.kRouteName);
            },
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            title: 'Biometric Lock',
            subtitle: MyApp.of(context).isBiometricEnabled ? 'Enabled' : 'Disabled',
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
          const SizedBox(height: 8),
          _SettingsTile(
            title: 'Import Note',
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
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
          ],
          // Admin Panel - only visible to admin email
          if (backendAuth.userEmail == 'prantadutta1997@gmail.com') ...[
            _SettingsTile(
              title: 'Admin Panel',
              subtitle: 'Debug sync issues',
              icon: Icons.admin_panel_settings,
              onTap: () async {
                PinpointHaptics.medium();

                // Import required
                final authenticated = await showDialog<bool>(
                  context: context,
                  builder: (context) => const AdminPasswordDialog(),
                );

                if (authenticated == true && mounted) {
                  AppNavigation.router.push(AdminPanelScreen.kRouteName);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
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

          const SizedBox(height: 32),

          // Appearance Section
          Text(
            'Appearance',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            title: 'Theme',
            icon: Icons.color_lens_rounded,
            onTap: () {
              PinpointHaptics.medium();
              AppNavigation.router.push(ThemeScreen.kRouteName);
            },
          ),

          const SizedBox(height: 32),

          // Home Screen Section
          Text(
            'Home Screen',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? cs.surface.withValues(alpha: 0.7)
                  : cs.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cs.outline.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.2 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SwitchListTile(
              title: const Text('Use Grid View'),
              value: _viewType == 'grid',
              onChanged: (value) {
                PinpointHaptics.light();
                _setViewType(value ? 'grid' : 'list');
              },
              secondary: Icon(Icons.grid_view_rounded, color: cs.primary),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? cs.surface.withValues(alpha: 0.7)
                  : cs.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cs.outline.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.2 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              leading: Icon(Icons.sort_rounded, color: cs.primary),
              title: const Text('Sort by'),
              trailing: DropdownButton<String>(
                value: _sortType,
                items: const [
                  DropdownMenuItem(
                      value: 'updatedAt', child: Text('Last Modified')),
                  DropdownMenuItem(
                      value: 'createdAt', child: Text('Date Created')),
                  DropdownMenuItem(value: 'title', child: Text('Title')),
                ],
                onChanged: (value) {
                  PinpointHaptics.selection();
                  _setSortType(value);
                },
                borderRadius: BorderRadius.circular(14),
                underline: Container(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? cs.surface.withValues(alpha: 0.7)
                  : cs.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cs.outline.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.2 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              leading: Icon(Icons.sort_by_alpha_rounded, color: cs.primary),
              title: const Text('Sort Direction'),
              trailing: DropdownButton<String>(
                value: _sortDirection,
                items: const [
                  DropdownMenuItem(value: 'desc', child: Text('Descending')),
                  DropdownMenuItem(value: 'asc', child: Text('Ascending')),
                ],
                onChanged: (value) {
                  PinpointHaptics.selection();
                  _setSortDirection(value);
                },
                borderRadius: BorderRadius.circular(14),
                underline: Container(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageLimitsSection extends StatelessWidget {
  const _UsageLimitsSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final premiumService = PremiumService();
    final isPremium = premiumService.isPremium;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Usage',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
              ),
            ),
            if (!isPremium) _MonthlyResetIndicator(),
          ],
        ),
        const SizedBox(height: 12),

        // Cloud Sync
        _UsageLimitCard(
          icon: Icons.cloud_sync_rounded,
          title: 'Cloud Sync',
          used: premiumService.getSyncedNotesCount(),
          limit: PremiumLimits.maxSyncedNotesForFree,
          isPremium: isPremium,
          isMonthly: false,
        ),
        const SizedBox(height: 8),

        // OCR Scans
        _UsageLimitCard(
          icon: Icons.document_scanner_rounded,
          title: 'OCR Scans',
          used: premiumService.getOcrScansThisMonth(),
          limit: PremiumLimits.maxOcrScansPerMonthForFree,
          isPremium: isPremium,
          isMonthly: true,
        ),
        const SizedBox(height: 8),

        // Exports
        _UsageLimitCard(
          icon: Icons.file_download_rounded,
          title: 'Exports',
          used: premiumService.getExportsThisMonth(),
          limit: PremiumLimits.maxExportsPerMonthForFree,
          isPremium: isPremium,
          isMonthly: true,
        ),
      ],
    );
  }
}

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.refresh_rounded,
            size: 14,
            color: cs.primary,
          ),
          const SizedBox(width: 4),
          Text(
            _getResetCountdown(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageLimitCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final int used;
  final int limit;
  final bool isPremium;
  final bool isMonthly;

  const _UsageLimitCard({
    required this.icon,
    required this.title,
    required this.used,
    required this.limit,
    required this.isPremium,
    required this.isMonthly,
  });

  Color _getProgressColor(BuildContext context, double percentage) {
    if (isPremium) return Theme.of(context).colorScheme.primary;

    if (percentage >= 0.9) return PinpointColors.rose;
    if (percentage >= 0.7) return PinpointColors.amber;
    return PinpointColors.mint;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final percentage = isPremium ? 0.0 : (used / limit).clamp(0.0, 1.0);
    final progressColor = _getProgressColor(context, percentage);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surface.withValues(alpha: 0.7)
            : cs.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: cs.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isMonthly && !isPremium)
                      Text(
                        'This month',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                isPremium ? 'Unlimited' : '$used / $limit',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: progressColor,
                ),
              ),
            ],
          ),
          if (!isPremium) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 6,
                backgroundColor: cs.outline.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? cs.surface.withValues(alpha: 0.7)
            : cs.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            leading: Icon(icon, color: cs.primary),
            title: Text(
              title,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
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
                Icon(Icons.chevron_right_rounded,
                    color: cs.onSurface.withValues(alpha: 0.6)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

/// Profile Header Card showing user information
class _ProfileHeaderCard extends StatelessWidget {
  final BackendAuthService backendAuth;

  const _ProfileHeaderCard({required this.backendAuth});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Consumer<SubscriptionManager>(
      builder: (context, subscriptionManager, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primaryContainer.withValues(alpha: 0.3),
                cs.primaryContainer.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: cs.primary.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: cs.primary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: cs.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Email
                    Text(
                      backendAuth.userEmail ?? 'User',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Account Status
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
                          subscriptionManager.isPremium ? 'Premium Member' : 'Free Account',
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

/// Logout Button with confirmation dialog
class _LogoutButton extends StatelessWidget {
  final BackendAuthService backendAuth;

  const _LogoutButton({required this.backendAuth});

  Future<void> _handleLogout(BuildContext context) async {
    // Show confirmation dialog
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

    try {
      // Sign out from Google (if applicable)
      final googleSignInService = GoogleSignInService();
      await googleSignInService.signOut();

      // Logout from backend (clears state & token)
      await backendAuth.logout();

      // Navigate to auth screen
      if (context.mounted) {
        PinpointHaptics.success();
        AppNavigation.router.go('/auth');

        // Show success feedback after navigation
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
        PinpointHaptics.error();
        showErrorToast(
          context: context,
          title: 'Sign Out Failed',
          description: e.toString().replaceAll('Exception: ', ''),
        );

        // Still navigate to auth screen even if there was an error
        AppNavigation.router.go('/auth');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? cs.surface.withValues(alpha: 0.7)
            : cs.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: PinpointColors.rose.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: PinpointColors.rose.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            PinpointHaptics.medium();
            _handleLogout(context);
          },
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            leading: Icon(
              Icons.logout_rounded,
              color: PinpointColors.rose,
            ),
            title: Text(
              'Sign Out',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: PinpointColors.rose,
              ),
            ),
            subtitle: Text(
              'Sign out of your account',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: PinpointColors.rose.withValues(alpha: 0.6),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

/// Linked Accounts Section showing authentication providers
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
    // Only reload if authentication status changed
    if (widget.backendAuth.isAuthenticated != oldWidget.backendAuth.isAuthenticated) {
      _loadProviders(showLoading: true);
    }
  }

  Future<void> _loadProviders({bool showLoading = false}) async {
    if (!widget.backendAuth.isAuthenticated) {
      return;
    }

    // If we already have data and not explicitly showing loading, do silent refresh
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

    // Show loading for first load or explicit reload
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

      // 1. Sign in with Google
      final userCredential = await googleSignInService.signInWithGoogle();

      if (userCredential == null) {
        throw Exception('Google Sign-In was cancelled');
      }

      // 2. Get Firebase token
      final firebaseToken = await googleSignInService.getFirebaseIdToken();

      if (firebaseToken == null) {
        throw Exception('Failed to get Firebase token');
      }

      // 3. Show password dialog
      if (!mounted) return;

      final password = await showDialog<String>(
        context: context,
        builder: (context) => _PasswordDialog(),
      );

      if (password == null || password.isEmpty) {
        return; // User cancelled
      }

      // 4. Link accounts
      await widget.backendAuth.linkGoogleAccount(
        firebaseToken: firebaseToken,
        password: password,
      );

      // 5. Reload providers (silent refresh)
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
    // Show confirmation dialog
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

      // Reload providers (silent refresh)
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
    if (!widget.backendAuth.isAuthenticated) {
      return _SettingsTile(
        title: 'Sign In',
        subtitle: 'Sign in to sync your notes',
        icon: Icons.login_rounded,
        onTap: () {
          PinpointHaptics.medium();
          AppNavigation.router.push('/auth');
        },
      );
    }

    if (_providers == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasGoogle = _providers!['has_google'] ?? false;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Linked Accounts',
          style: theme.textTheme.labelLarge?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        // Email Provider (always shown if authenticated)
        _AuthProviderCard(
          icon: Icons.email_rounded,
          iconColor: cs.primary,
          title: 'Email',
          subtitle: widget.backendAuth.userEmail ?? 'Email authentication',
          isLinked: true,
          isLoading: false,
          onTap: () {
            PinpointHaptics.light();
          },
        ),

        const SizedBox(height: 8),

        // Google Provider
        _AuthProviderCard(
          icon: Icons.g_mobiledata_rounded,
          iconColor: hasGoogle ? PinpointColors.mint : cs.onSurface.withValues(alpha: 0.5),
          title: 'Google',
          subtitle: hasGoogle
              ? 'Linked to your account'
              : 'Link for easy sign-in',
          isLinked: hasGoogle,
          isLoading: _isLoading,
          onTap: _isLoading
              ? null
              : (hasGoogle ? null : _linkGoogleAccount),
          onUnlink: hasGoogle && !_isLoading ? _unlinkGoogleAccount : null,
        ),
      ],
    );
  }
}

/// Auth Provider Card showing authentication method status
class _AuthProviderCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isLinked;
  final bool isLoading;
  final VoidCallback? onTap;
  final VoidCallback? onUnlink;

  const _AuthProviderCard({
    required this.icon,
    required this.iconColor,
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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? cs.surface.withValues(alpha: 0.7)
            : cs.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLinked
              ? iconColor.withValues(alpha: 0.3)
              : cs.outline.withValues(alpha: 0.1),
          width: isLinked ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isLinked
                ? iconColor.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap != null && !isLoading
              ? () {
                  PinpointHaptics.medium();
                  onTap!();
                }
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: iconColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isLinked) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: PinpointColors.mint.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: PinpointColors.mint.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 12,
                                    color: PinpointColors.mint,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Linked',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: PinpointColors.mint,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
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
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (onUnlink != null)
                  IconButton(
                    icon: Icon(
                      Icons.link_off_rounded,
                      color: PinpointColors.rose,
                    ),
                    onPressed: () {
                      PinpointHaptics.medium();
                      onUnlink!();
                    },
                    tooltip: 'Unlink account',
                  )
                else if (onTap != null && !isLinked)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
              ],
            ),
          ),
        ),
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
          const SizedBox(height: 16),
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
