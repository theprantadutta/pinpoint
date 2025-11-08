import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/constants/shared_preference_keys.dart';
import 'package:pinpoint/screens/archive_screen.dart';
import 'package:pinpoint/screens/sync_screen.dart';
import 'package:pinpoint/screens/trash_screen.dart';
import 'package:pinpoint/screens/subscription_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:pinpoint/services/drift_note_service.dart';
import 'package:pinpoint/services/subscription_manager.dart';
import 'package:pinpoint/services/firebase_notification_service.dart';
import 'package:pinpoint/util/show_a_toast.dart';
import 'package:pinpoint/screens/theme_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../design_system/design_system.dart';

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
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _viewType = _prefs?.getString(kHomeScreenViewTypeKey) ?? 'list';
      _sortType = _prefs?.getString(kHomeScreenSortTypeKey) ?? 'updatedAt';
      _sortDirection = _prefs?.getString(kHomeScreenSortDirectionKey) ?? 'desc';
    });
  }

  Future<void> _setViewType(String value) async {
    await _prefs?.setString(kHomeScreenViewTypeKey, value);
    setState(() {
      _viewType = value;
    });
  }

  Future<void> _setSortType(String? value) async {
    if (value == null) return;
    await _prefs?.setString(kHomeScreenSortTypeKey, value);
    setState(() {
      _sortType = value;
    });
  }

  Future<void> _setSortDirection(String? value) async {
    if (value == null) return;
    await _prefs?.setString(kHomeScreenSortDirectionKey, value);
    setState(() {
      _sortDirection = value;
    });
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
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
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
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
                  _SettingsTile(
                    title: subscriptionManager.isPremium ? 'Premium Active' : 'Upgrade to Premium',
                    subtitle: subscriptionManager.isPremium
                        ? 'Thank you for your support!'
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
                              color: PinpointColors.mint,
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
                        : null,
                    onTap: () {
                      PinpointHaptics.medium();
                      context.push(SubscriptionScreen.kRouteName);
                    },
                  ),
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
            title: 'Archive',
            icon: Icons.archive_rounded,
            onTap: () {
              PinpointHaptics.medium();
              context.push(ArchiveScreen.kRouteName);
            },
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            title: 'Trash',
            icon: Icons.delete_rounded,
            onTap: () {
              PinpointHaptics.medium();
              context.push(TrashScreen.kRouteName);
            },
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            title: 'Sync',
            icon: Icons.sync_rounded,
            onTap: () {
              PinpointHaptics.medium();
              context.push(SyncScreen.kRouteName);
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
              context.push(ThemeScreen.kRouteName);
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
            trailing: Icon(Icons.chevron_right_rounded,
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
