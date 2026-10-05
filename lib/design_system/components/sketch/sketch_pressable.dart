import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../animations.dart';

/// Sketchbook press feedback: the child scales to 0.97 over 120ms while held.
///
/// Every tappable Sketchbook surface goes through this rather than an
/// [InkWell] — there are no ripples on paper. When [semanticLabel] is given
/// the region is announced as a button with that label.
class SketchPressable extends StatefulWidget {
  const SketchPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.haptic = false,
    this.scale = SketchMotion.pressScale,
    this.selected,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  /// Light impact on tap (pin toggle, checkbox, dock create).
  final bool haptic;
  final double scale;

  /// Exposed to accessibility as the selected state, when non-null.
  final bool? selected;
  final bool enabled;

  @override
  State<SketchPressable> createState() => _SketchPressableState();
}

class _SketchPressableState extends State<SketchPressable> {
  bool _down = false;

  bool get _interactive =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final animate = SketchMotion.enabled(context);
    Widget child = AnimatedScale(
      scale: _down && animate ? widget.scale : 1,
      duration: SketchMotion.fast,
      curve: _down ? SketchMotion.enter : SketchMotion.exit,
      child: widget.child,
    );

    if (_interactive) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.lightImpact();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                _set(false);
                HapticFeedback.mediumImpact();
                widget.onLongPress!();
              },
        child: child,
      );
    }

    return Semantics(
      button: _interactive,
      enabled: widget.enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      excludeSemantics: false,
      child: child,
    );
  }
}
