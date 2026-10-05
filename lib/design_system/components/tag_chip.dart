import 'package:flutter/material.dart';
import '../colors.dart';
import '../spacing.dart';
import '../typography.dart';
import 'sketch/sketch_chip.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

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

class _TagChipState extends State<TagChip> {
  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final pad = switch (widget.size) {
      TagChipSize.small =>
        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      TagChipSize.medium =>
        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      TagChipSize.large =>
        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    };
    return SketchChip(
      label: widget.label,
      selected: widget.isSelected,
      // A coloured tag selects to its pastel; otherwise to the inverse pill.
      pastel: widget.color == null ? null : _pastelFor(widget.color!),
      onTap: widget.onTap,
      padding: pad,
      leading: widget.emoji == null ? null : Text(widget.emoji!),
      trailing: widget.showClose
          ? Semantics(
              label: AppL10n.of(context).dsClear,
              button: true,
              child: GestureDetector(
                onTap: widget.onClose,
                child: Icon(Icons.close_rounded,
                    size: 14, color: widget.isSelected ? null : s.muted),
              ),
            )
          : null,
    );
  }

  /// Snap an arbitrary colour to the nearest Sketchbook pastel by hue.
  static Color _pastelFor(Color c) {
    if (SketchPastels.roundRobin.contains(c)) return c;
    final h = HSLColor.fromColor(c).hue;
    if (h < 25 || h >= 330) return SketchPastels.pink;
    if (h < 75) return SketchPastels.yellow;
    if (h < 170) return SketchPastels.mint;
    if (h < 230) return SketchPastels.sky;
    return SketchPastels.lavender;
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
    final s = context.sketch;

    return Container(
      decoration: BoxDecoration(
        color: s.surface,
        border: Border.all(
          color: s.outline,
          width: _focusNode.hasFocus ? 2 : SketchStroke.outline,
        ),
        borderRadius: BorderRadius.circular(999),
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
                hintText: widget.hint ?? AppL10n.of(context).dsAddTagHint,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: context.type.chip,
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
