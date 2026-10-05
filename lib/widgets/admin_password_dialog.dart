import 'package:flutter/material.dart';
import 'package:pinpoint/design_system/design_system.dart';
import 'package:pinpoint/services/admin_api_service.dart';
import 'package:pinpoint/services/backend_auth_service.dart';
import 'package:provider/provider.dart';

/// Admin Password Dialog
///
/// Shows a secure password input dialog for admin authentication
class AdminPasswordDialog extends StatefulWidget {
  const AdminPasswordDialog({super.key});

  @override
  State<AdminPasswordDialog> createState() => _AdminPasswordDialogState();
}

class _AdminPasswordDialogState extends State<AdminPasswordDialog> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final backendAuth = context.read<BackendAuthService>();
    final adminEmail = backendAuth.userEmail;

    if (adminEmail == null) {
      setState(() {
        _errorMessage = 'Not authenticated';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final adminApi = AdminApiService();
      final password = _passwordController.text.trim();

      // DEBUG: Print what we're about to send
      debugPrint(
          '[AdminDialog] Attempting login with password length: ${password.length}');

      await adminApi.adminLogin(adminEmail, password);

      if (mounted) {
        Navigator.of(context).pop(true); // Success
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;

    // Admin tooling: deliberately left in English. The dialog itself takes
    // the Sketchbook dialog theme (surface, 1.5px outline).
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.admin_panel_settings_outlined, color: s.ink),
          const SizedBox(width: 12),
          const Text('Admin Access'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This panel contains sensitive user data. Enter admin password to continue.',
            style: t.bodyRegular.copyWith(fontSize: 14, color: s.muted),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofocus: true,
            enabled: !_isLoading,
            decoration: InputDecoration(
              labelText: 'Admin Password',
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
                borderRadius: BorderRadius.circular(SketchRadius.card),
              ),
              errorText: _errorMessage,
              errorMaxLines: 3,
            ),
            onFieldSubmitted: (_) => _handleSubmit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _handleSubmit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Access'),
        ),
      ],
    );
  }
}
