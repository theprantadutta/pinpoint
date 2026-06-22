import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../screen_arguments/create_note_screen_arguments.dart';
import '../../screens/create_note_screen_v2.dart';
import '../../services/premium_gate.dart';
import '../../walkthrough/walkthrough_keys.dart';
import '../animations.dart';

/// Google-Keep-style create button: a blue rounded-square FAB that opens a
/// bottom sheet of note-creation options (Text, List, and the premium-gated
/// Drawing / Image / Audio). A bottom sheet keeps placement reliable across
/// screen sizes and text directions.
class KeepFab extends StatelessWidget {
  const KeepFab({super.key});

  void _openEditor(BuildContext context, String noticeType) {
    context.push(
      CreateNoteScreenV2.kRouteName,
      extra: CreateNoteScreenArguments(noticeType: noticeType),
    );
  }

  void _showCreateMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CreateOption(
                icon: Icons.text_fields_rounded,
                label: 'Text note',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openEditor(context, 'Title Content');
                },
              ),
              _CreateOption(
                icon: Icons.check_box_outlined,
                label: 'List',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openEditor(context, 'Todo List');
                },
              ),
              _CreateOption(
                icon: Icons.brush_outlined,
                label: 'Drawing',
                locked: true,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  PremiumGate.require(context, 'Drawing');
                },
              ),
              _CreateOption(
                icon: Icons.image_outlined,
                label: 'Image',
                locked: true,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  PremiumGate.require(context, 'Image');
                },
              ),
              _CreateOption(
                icon: Icons.mic_none_rounded,
                label: 'Audio',
                locked: true,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  PremiumGate.require(context, 'Audio');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FloatingActionButton(
      key: WalkthroughKeys.fabKey,
      onPressed: () {
        PinpointHaptics.light();
        _showCreateMenu(context);
      },
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.add, size: 30),
    );
  }
}

class _CreateOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool locked;
  final VoidCallback onTap;

  const _CreateOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.onSurfaceVariant),
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      trailing: locked
          ? Icon(Icons.lock_outline_rounded, size: 18, color: cs.onSurfaceVariant)
          : null,
      onTap: () {
        PinpointHaptics.light();
        onTap();
      },
    );
  }
}
