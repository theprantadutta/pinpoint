import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/design_system.dart';
import '../screens/archive_screen.dart';
import '../screens/my_folders_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/subscription_screen.dart';
import '../screens/trash_screen.dart';

/// Google-Keep-style navigation drawer. Replaces the old bottom navigation.
///
/// "Notes" is the current (home) destination; the rest push existing routes.
/// Labels maps to the app's folders. Images/drawing/audio premium gating lives
/// on the FAB, not here.
class KeepDrawer extends StatelessWidget {
  const KeepDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/pinpoint-logo.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Pinpoint',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            _DrawerItem(
              icon: Icons.lightbulb_outline_rounded,
              label: 'Notes',
              selected: true,
              onTap: () => Navigator.of(context).pop(),
            ),
            _DrawerItem(
              icon: Icons.label_outline_rounded,
              label: 'Labels',
              onTap: () => _go(context, MyFoldersScreen.kRouteName),
            ),
            const Divider(height: 16, indent: 16, endIndent: 16),
            _DrawerItem(
              icon: Icons.archive_outlined,
              label: 'Archive',
              onTap: () => _go(context, ArchiveScreen.kRouteName),
            ),
            _DrawerItem(
              icon: Icons.delete_outline_rounded,
              label: 'Trash',
              onTap: () => _go(context, TrashScreen.kRouteName),
            ),
            const Divider(height: 16, indent: 16, endIndent: 16),
            _DrawerItem(
              icon: Icons.workspace_premium_outlined,
              label: 'Upgrade to Premium',
              iconColor: const Color(0xFFFFC107),
              onTap: () => _go(context, SubscriptionScreen.kRouteName),
            ),
            _DrawerItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () => _go(context, SettingsScreen.kRouteName),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, String route) {
    PinpointHaptics.light();
    Navigator.of(context).pop(); // close drawer
    context.push(route);
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color? iconColor;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected
            ? cs.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(0),
          right: Radius.circular(999),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected
                      ? cs.primary
                      : (iconColor ?? cs.onSurfaceVariant),
                ),
                const SizedBox(width: 20),
                Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? cs.primary : cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
