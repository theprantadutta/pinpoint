import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../screen_arguments/create_note_screen_arguments.dart';
import '../../screens/create_note_screen_v2.dart';
import '../../services/premium_gate.dart';
import '../../walkthrough/walkthrough_keys.dart';
import '../animations.dart';

/// A speed-dial create button (Keep-style). Tapping the FAB expands a vertical
/// stack of labelled mini-buttons above it, over a dismiss scrim. The expanded
/// items + scrim are rendered in an [Overlay] anchored to the FAB's real
/// position — this is the reliable way to do a speed dial (a multi-child column
/// placed directly in the Scaffold FAB slot lays out unpredictably).
class KeepFab extends StatefulWidget {
  const KeepFab({super.key});

  @override
  State<KeepFab> createState() => _KeepFabState();
}

class _SpeedDialAction {
  final IconData icon;
  final String label;
  final bool locked;
  final VoidCallback onTap;
  const _SpeedDialAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.locked = false,
  });
}

class _KeepFabState extends State<KeepFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  OverlayEntry? _entry;
  bool _isOpen = false;

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    _controller.dispose();
    super.dispose();
  }

  List<_SpeedDialAction> get _actions => [
        // Top of the stack first; the last item sits closest to the FAB.
        _SpeedDialAction(
          icon: Icons.mic_none_rounded,
          label: 'Audio',
          locked: true,
          onTap: () => _select(() => PremiumGate.require(context, 'Audio')),
        ),
        _SpeedDialAction(
          icon: Icons.image_outlined,
          label: 'Image',
          locked: true,
          onTap: () => _select(() => PremiumGate.require(context, 'Image')),
        ),
        _SpeedDialAction(
          icon: Icons.brush_outlined,
          label: 'Drawing',
          locked: true,
          onTap: () => _select(() => PremiumGate.require(context, 'Drawing')),
        ),
        _SpeedDialAction(
          icon: Icons.check_box_outlined,
          label: 'List',
          onTap: () => _select(() => _openEditor('Todo List')),
        ),
        _SpeedDialAction(
          icon: Icons.text_fields_rounded,
          label: 'Text',
          onTap: () => _select(() => _openEditor('Title Content')),
        ),
      ];

  void _openEditor(String noticeType) {
    context.push(
      CreateNoteScreenV2.kRouteName,
      extra: CreateNoteScreenArguments(noticeType: noticeType),
    );
  }

  /// Run an action: tear down the menu immediately, then perform it.
  void _select(VoidCallback action) {
    _removeOverlay();
    action();
  }

  void _toggle() {
    PinpointHaptics.light();
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    _entry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_entry!);
    setState(() => _isOpen = true);
    _controller.forward();
  }

  Future<void> _close() async {
    if (!_isOpen) return;
    try {
      await _controller.reverse();
    } catch (_) {}
    _removeOverlay();
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
    _controller.value = 0;
    if (mounted) setState(() => _isOpen = false);
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final media = MediaQuery.of(overlayContext);
    final cs = Theme.of(overlayContext).colorScheme;

    // Anchor the stack to the FAB's actual on-screen rect.
    final fabBox =
        WalkthroughKeys.fabKey.currentContext?.findRenderObject() as RenderBox?;
    double rightInset = 16;
    double itemsBottom = media.padding.bottom + 16 + 56 + 12;
    double fabBottom = media.padding.bottom + 16;
    double fabW = 56;
    double fabH = 56;
    if (fabBox != null && fabBox.hasSize) {
      final topLeft = fabBox.localToGlobal(Offset.zero);
      rightInset = media.size.width - (topLeft.dx + fabBox.size.width);
      itemsBottom = media.size.height - topLeft.dy + 12;
      fabBottom = media.size.height - (topLeft.dy + fabBox.size.height);
      fabW = fabBox.size.width;
      fabH = fabBox.size.height;
    }

    final actions = _actions;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Stack(
          children: [
            // Dismiss scrim — blurred + darkened so the page recedes and the
            // speed-dial labels are easy to read.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 8 * _controller.value,
                    sigmaY: 8 * _controller.value,
                  ),
                  child: ColoredBox(
                    color: Colors.black
                        .withValues(alpha: 0.6 * _controller.value),
                  ),
                ),
              ),
            ),
            // Action stack, anchored just above the FAB
            Positioned(
              right: rightInset,
              bottom: itemsBottom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (int i = 0; i < actions.length; i++)
                    _buildAnimatedItem(actions[i], i, actions.length),
                ],
              ),
            ),
            // Close (×) button drawn on top of the scrim, over the real FAB
            // (which is hidden behind the scrim).
            Positioned(
              right: rightInset,
              bottom: fabBottom,
              child: SizedBox(
                width: fabW,
                height: fabH,
                child: Material(
                  color: cs.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _close,
                    child: AnimatedRotation(
                      turns: _controller.value * 0.125,
                      duration: Duration.zero,
                      child: Icon(Icons.add, size: 30, color: cs.onPrimary),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnimatedItem(_SpeedDialAction action, int index, int total) {
    // Stagger from the bottom (closest to the FAB) upward.
    final reverseIndex = total - 1 - index;
    final start = (reverseIndex * 0.06).clamp(0.0, 0.5);
    final anim = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1.0, curve: Curves.easeOutBack),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: anim,
          alignment: Alignment.bottomRight,
          child: _SpeedDialRow(action: action),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FloatingActionButton(
      key: WalkthroughKeys.fabKey,
      onPressed: _toggle,
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: AnimatedRotation(
        turns: _isOpen ? 0.125 : 0,
        duration: const Duration(milliseconds: 220),
        child: const Icon(Icons.add, size: 30),
      ),
    );
  }
}

/// A single speed-dial row: a label chip and a circular mini-button.
class _SpeedDialRow extends StatelessWidget {
  final _SpeedDialAction action;
  const _SpeedDialRow({required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label chip
        Material(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.2),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: action.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (action.locked) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.lock_outline_rounded,
                        size: 14, color: cs.onSurfaceVariant),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Mini circular button
        Material(
          color: cs.surfaceContainerHighest,
          shape: const CircleBorder(),
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: action.onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(action.icon, size: 22, color: cs.primary),
            ),
          ),
        ),
      ],
    );
  }
}
