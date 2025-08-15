import 'package:flutter/material.dart';

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
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }
}
