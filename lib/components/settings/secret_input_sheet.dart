import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../../design_system/design_system.dart';

/// A Sketchbook sheet with one or more obscured fields (a password, or a new
/// passphrase plus its confirmation). Returns the first field's text, or null
/// when dismissed.
///
/// [validate] gets every field's text and returns an error to show under the
/// last field, or null to accept.
Future<String?> showSecretInputSheet({
  required BuildContext context,
  required String title,
  String? message,
  required List<String> fieldLabels,
  required String confirmLabel,
  String? Function(List<String> values)? validate,
  bool isDismissible = true,
}) {
  return showSketchSheet<String>(
    context: context,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    builder: (_) => _SecretInputSheet(
      title: title,
      message: message,
      fieldLabels: fieldLabels,
      confirmLabel: confirmLabel,
      validate: validate,
    ),
  );
}

class _SecretInputSheet extends StatefulWidget {
  const _SecretInputSheet({
    required this.title,
    required this.message,
    required this.fieldLabels,
    required this.confirmLabel,
    required this.validate,
  });

  final String title;
  final String? message;
  final List<String> fieldLabels;
  final String confirmLabel;
  final String? Function(List<String> values)? validate;

  @override
  State<_SecretInputSheet> createState() => _SecretInputSheetState();
}

class _SecretInputSheetState extends State<_SecretInputSheet> {
  late final List<TextEditingController> _controllers = [
    for (final _ in widget.fieldLabels) TextEditingController(),
  ];
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final values = [for (final c in _controllers) c.text];
    if (values.first.isEmpty) return;
    final error = widget.validate?.call(values);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(values.first);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final s = context.sketch;
    final l10n = AppL10n.of(context);

    return SketchSheet(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.message != null) ...[
            Text(widget.message!,
                style: t.bodyRegular.copyWith(fontSize: 14, color: s.muted)),
            const SizedBox(height: 16),
          ],
          for (var i = 0; i < _controllers.length; i++) ...[
            TextField(
              controller: _controllers[i],
              obscureText: _obscure,
              autofocus: i == 0,
              textInputAction: i == _controllers.length - 1
                  ? TextInputAction.done
                  : TextInputAction.next,
              onSubmitted:
                  i == _controllers.length - 1 ? (_) => _submit() : null,
              decoration: InputDecoration(
                labelText: widget.fieldLabels[i],
                errorText: i == _controllers.length - 1 ? _error : null,
                suffixIcon: i == 0
                    ? IconButton(
                        tooltip: _obscure
                            ? l10n.stShowPassword
                            : l10n.stHidePassword,
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 6),
          PillButton(label: widget.confirmLabel, onPressed: _submit),
          const SizedBox(height: 10),
          PillButton.secondary(
            label: l10n.commonCancel,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
