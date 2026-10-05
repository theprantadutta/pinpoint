import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../design_system/design_system.dart';

class DialogService {
  DialogService._();

  /// The "add / edit a single value" sheet, shared by the add-todo, add-folder
  /// and rename-folder flows: a [SketchSheet] with a 26/800 title, an optional
  /// muted line, one outlined text field and an inverse pill that enables
  /// once there is text.
  ///
  /// [onAddPressed] closes the sheet itself (callers pop when the value was
  /// accepted, and keep it open to show an error toast otherwise).
  static void addSomethingDialog({
    required BuildContext context,
    required TextEditingController controller,
    required String title,
    required String hintText,
    required void Function() onAddPressed,
    IconData icon = Icons.add_rounded,
    String? subtitle,
    String? primaryLabel,
  }) {
    showSketchSheet<void>(
      context: context,
      builder: (sheetContext) => _ValueSheet(
        controller: controller,
        title: title,
        hintText: hintText,
        subtitle: subtitle,
        icon: icon,
        primaryLabel: primaryLabel ?? AppL10n.of(sheetContext).edAdd,
        onSubmit: onAddPressed,
      ),
    );
  }
}

class _ValueSheet extends StatelessWidget {
  const _ValueSheet({
    required this.controller,
    required this.title,
    required this.hintText,
    required this.subtitle,
    required this.icon,
    required this.primaryLabel,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String title;
  final String hintText;
  final String? subtitle;
  final IconData icon;
  final String primaryLabel;
  final VoidCallback onSubmit;

  void _submit() {
    if (controller.text.trim().isEmpty) return;
    PinpointHaptics.medium();
    onSubmit();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;

    return SketchSheet(
      title: title,
      scrollable: false,
      footer: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => PillButton(
          label: primaryLabel,
          icon: icon,
          onPressed: value.text.trim().isEmpty ? null : _submit,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (subtitle != null) ...[
            Text(subtitle!,
                style: t.bodyRegular.copyWith(fontSize: 14, color: s.muted)),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _submit(),
            style: t.bodyRegular.copyWith(color: s.ink),
            cursorColor: s.ink,
            decoration: InputDecoration(
              hintText: hintText,
              filled: true,
              fillColor: s.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SketchRadius.card),
                borderSide:
                    BorderSide(color: s.outline, width: SketchStroke.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SketchRadius.card),
                borderSide: BorderSide(color: s.ink, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
