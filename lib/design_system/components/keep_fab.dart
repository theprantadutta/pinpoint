import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../screen_arguments/create_note_screen_arguments.dart';
import '../../screens/create_note_screen_v2.dart';
import '../../services/premium_gate.dart';
import '../../walkthrough/walkthrough_keys.dart';
import '../animations.dart';

/// Google-Keep-style FAB: a blue rounded-square button that expands into a
/// vertical speed-dial of note-creation options (Text, List, Drawing, Image,
/// Audio). Premium-only actions show a lock and route to the upsell.
class KeepFab extends StatefulWidget {
  const KeepFab({super.key});

  @override
  State<KeepFab> createState() => _KeepFabState();
}

class _KeepFabState extends State<KeepFab> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  bool _open = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _close() {
    if (!_open) return;
    setState(() => _open = false);
    _controller.reverse();
  }

  void _openEditor({required String noticeType}) {
    _close();
    context.push(
      CreateNoteScreenV2.kRouteName,
      extra: CreateNoteScreenArguments(noticeType: noticeType),
    );
  }

  void _premiumAction(String feature) {
    _close();
    PremiumGate.require(context, feature);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final actions = <Widget>[
      _SpeedDialItem(
        icon: Icons.image_outlined,
        label: 'Image',
        locked: true,
        onTap: () => _premiumAction('Image'),
        animation: _controller,
        index: 0,
      ),
      _SpeedDialItem(
        icon: Icons.brush_outlined,
        label: 'Drawing',
        locked: true,
        onTap: () => _premiumAction('Drawing'),
        animation: _controller,
        index: 1,
      ),
      _SpeedDialItem(
        icon: Icons.mic_none_rounded,
        label: 'Audio',
        locked: true,
        onTap: () => _premiumAction('Audio'),
        animation: _controller,
        index: 2,
      ),
      _SpeedDialItem(
        icon: Icons.check_box_outlined,
        label: 'List',
        onTap: () => _openEditor(noticeType: 'Todo List'),
        animation: _controller,
        index: 3,
      ),
      _SpeedDialItem(
        icon: Icons.text_fields_rounded,
        label: 'Text',
        onTap: () => _openEditor(noticeType: 'Title Content'),
        animation: _controller,
        index: 4,
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Only present while open so the closed FAB stays compact and pinned
        // to the bottom-right (a collapsed SizeTransition still reserves width).
        if (_open) ...actions,
        if (_open) const SizedBox(height: 8),
        FloatingActionButton(
          key: WalkthroughKeys.fabKey,
          onPressed: _toggle,
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: AnimatedRotation(
            turns: _open ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.add, size: 30),
          ),
        ),
      ],
    );
  }
}

class _SpeedDialItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool locked;
  final VoidCallback onTap;
  final Animation<double> animation;
  final int index;

  const _SpeedDialItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.animation,
    required this.index,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SizeTransition(
      sizeFactor: animation,
      child: FadeTransition(
        opacity: animation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: () {
                PinpointHaptics.light();
                onTap();
              },
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 20, color: cs.onSurface),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (locked) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.lock_outline_rounded,
                          size: 14, color: cs.onSurfaceVariant),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
