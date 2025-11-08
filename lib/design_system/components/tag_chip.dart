import 'package:flutter/material.dart';
import '../colors.dart';
import '../theme.dart';
import '../typography.dart';
import '../animations.dart';

/// TagChip - Animated chip component for tags
///
/// Features:
/// - Color/emoji badges
/// - Selectable state
/// - Add/remove animations
/// - Hover effects
/// - Size variants
class TagChip extends StatefulWidget {
  final String label;
  final String? emoji;
  final Color? color;
  final bool isSelected;
  final bool showClose;
  final VoidCallback? onTap;
  final VoidCallback? onClose;
  final TagChipSize size;

  const TagChip({
    super.key,
    required this.label,
    this.emoji,
    this.color,
    this.isSelected = false,
    this.showClose = false,
    this.onTap,
    this.onClose,
    this.size = TagChipSize.medium,
  });

  @override
  State<TagChip> createState() => _TagChipState();
}

class _TagChipState extends State<TagChip> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: PinpointAnimations.microInteraction.duration,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: PinpointAnimations.microInteraction.curve,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _animateRemove() async {
    await _animationController.reverse();
    if (widget.onClose != null) {
      widget.onClose!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagStyle = theme.tagStyle;
    final motionSettings = MotionSettings.fromMediaQuery(context);

    final tagColors = widget.color != null
        ? _getColorsFromColor(widget.color!)
        : TagColors.getPreset(0);

    // Calculate padding based on size
    final padding = _getPadding();
    final fontSize = _getFontSize();
    final iconSize = _getIconSize();

    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTap: widget.onTap != null
                ? () {
                    PinpointHaptics.selection();
                    widget.onTap!();
                  }
                : null,
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            child: Semantics(
              label: 'Tag: ${widget.label}',
              button: widget.onTap != null,
              selected: widget.isSelected,
              child: AnimatedContainer(
                duration: motionSettings.getDuration(PinpointAnimations.fast),
                curve: motionSettings.getCurve(PinpointAnimations.sharp),
                padding: padding,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? tagColors.foreground.withValues(alpha: 0.15)
                      : tagColors.background,
                  border: Border.all(
                    color: widget.isSelected || _isHovered
                        ? tagColors.foreground
                        : tagColors.border.withValues(alpha: 0.3),
                    width: widget.isSelected ? 2 : 1,
                  ),
                  borderRadius: tagStyle.borderRadius,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Emoji or color dot
                    if (widget.emoji != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          widget.emoji!,
                          style: TextStyle(fontSize: fontSize),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Container(
                          width: fontSize * 0.7,
                          height: fontSize * 0.7,
                          decoration: BoxDecoration(
                            color: tagColors.foreground,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),

                    // Label
                    Text(
                      widget.label,
                      style: PinpointTypography.tagChip(
                        brightness: theme.brightness,
                        color: tagColors.foreground,
                      ).copyWith(fontSize: fontSize),
                    ),

                    // Close button
                    if (widget.showClose) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          PinpointHaptics.light();
                          _animateRemove();
                        },
                        child: Icon(
                          Icons.close_rounded,
                          size: iconSize,
                          color: tagColors.foreground,
                        ),
                      ),
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

  EdgeInsets _getPadding() {
    switch (widget.size) {
      case TagChipSize.small:
        return const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
      case TagChipSize.medium:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
      case TagChipSize.large:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    }
  }

  double _getFontSize() {
    switch (widget.size) {
      case TagChipSize.small:
        return 10;
      case TagChipSize.medium:
        return 12;
      case TagChipSize.large:
        return 14;
    }
  }

  double _getIconSize() {
    switch (widget.size) {
      case TagChipSize.small:
        return 14;
      case TagChipSize.medium:
        return 16;
      case TagChipSize.large:
        return 18;
    }
  }

  TagColors _getColorsFromColor(Color color) {
    return TagColors(
      background: color.withValues(alpha: 0.15),
      foreground: color,
      border: color,
    );
  }
}

/// Tag chip size variants
enum TagChipSize {
  small,
  medium,
  large,
}

/// Tag input field - for adding new tags
class TagInputField extends StatefulWidget {
  final Function(String) onSubmit;
  final String? hint;

  const TagInputField({
    super.key,
    required this.onSubmit,
    this.hint,
  });

  @override
  State<TagInputField> createState() => _TagInputFieldState();
}

class _TagInputFieldState extends State<TagInputField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSubmit(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagStyle = theme.tagStyle;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(
          color: _focusNode.hasFocus
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
          width: _focusNode.hasFocus ? 2 : 1,
        ),
        borderRadius: tagStyle.borderRadius,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.add_rounded,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: widget.hint ?? 'Add tag...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: PinpointTypography.tagChip(
                brightness: theme.brightness,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          if (_controller.text.isNotEmpty)
            GestureDetector(
              onTap: _submit,
              child: Icon(
                Icons.check_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}
