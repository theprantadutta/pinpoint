import 'package:flutter/material.dart';
import '../animations.dart';

/// ChecklistItem - Animated checkbox with reorder handle
///
/// Features:
/// - Animated checkbox
/// - Strikethrough on completion
/// - Reorder drag handle
/// - Haptic feedback
/// - Accessibility support
class ChecklistItem extends StatefulWidget {
  final String text;
  final bool isChecked;
  final ValueChanged<bool>? onChanged;
  final ValueChanged<String>? onTextChanged;
  final VoidCallback? onDelete;
  final bool showDragHandle;
  final bool readOnly;

  const ChecklistItem({
    super.key,
    required this.text,
    this.isChecked = false,
    this.onChanged,
    this.onTextChanged,
    this.onDelete,
    this.showDragHandle = false,
    this.readOnly = false,
  });

  @override
  State<ChecklistItem> createState() => _ChecklistItemState();
}

class _ChecklistItemState extends State<ChecklistItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkAnimationController;
  late Animation<double> _checkAnimation;
  late TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.text);

    _checkAnimationController = AnimationController(
      vsync: this,
      duration: PinpointAnimations.normal,
    );

    _checkAnimation = CurvedAnimation(
      parent: _checkAnimationController,
      curve: PinpointAnimations.emphasizedDecelerate,
    );

    if (widget.isChecked) {
      _checkAnimationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(ChecklistItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isChecked != widget.isChecked) {
      if (widget.isChecked) {
        _checkAnimationController.forward();
      } else {
        _checkAnimationController.reverse();
      }
    }
    if (oldWidget.text != widget.text) {
      _textController.text = widget.text;
    }
  }

  @override
  void dispose() {
    _checkAnimationController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleCheck() {
    if (widget.onChanged != null) {
      PinpointHaptics.selection();
      widget.onChanged!(!widget.isChecked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final motionSettings = MotionSettings.fromMediaQuery(context);

    return Semantics(
      label:
          '${widget.isChecked ? "Completed" : "Incomplete"} task: ${widget.text}',
      checked: widget.isChecked,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            if (widget.showDragHandle)
              Padding(
                padding: const EdgeInsets.only(top: 12, right: 8),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
              ),

            // Checkbox
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: GestureDetector(
                onTap: _toggleCheck,
                child: AnimatedBuilder(
                  animation: _checkAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _checkAnimation.value > 0
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: _checkAnimation.value > 0
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Transform.scale(
                        scale: _checkAnimation.value,
                        child: Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Text field
            Expanded(
              child: widget.readOnly
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: AnimatedDefaultTextStyle(
                        duration: motionSettings
                            .getDuration(PinpointAnimations.normal),
                        curve: motionSettings
                            .getCurve(PinpointAnimations.standard),
                        style: theme.textTheme.bodyMedium!.copyWith(
                          decoration: widget.isChecked
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color: widget.isChecked
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onSurface,
                        ),
                        child: Text(widget.text),
                      ),
                    )
                  : TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: theme.textTheme.bodyMedium!.copyWith(
                        decoration: widget.isChecked
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: widget.isChecked
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface,
                      ),
                      onChanged: widget.onTextChanged,
                      maxLines: null,
                    ),
            ),

            // Delete button
            if (widget.onDelete != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  iconSize: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                  onPressed: () {
                    PinpointHaptics.light();
                    widget.onDelete!();
                  },
                  tooltip: 'Delete task',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
