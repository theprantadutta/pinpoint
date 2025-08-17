import 'package:flutter/material.dart';
import 'package:pinpoint/design/app_theme.dart';

class AccountListTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const AccountListTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Glass(
        child: ListTile(
          leading: Icon(
            icon,
            color: cs.primary,
          ),
          title: Text(
            title,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.radiusL,
          ),
        ),
      ),
    );
  }
}