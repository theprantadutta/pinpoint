import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:fleather/fleather.dart';

/// Simple toolbar for text formatting with Fleather
/// Provides buttons for bold, italic, underline, and strikethrough
class MarkdownToolbar extends StatelessWidget {
  final FleatherController controller;
  final FocusNode? focusNode;

  const MarkdownToolbar({
    super.key,
    required this.controller,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _ToolbarButton(
              icon: Symbols.format_bold,
              tooltip: 'Bold',
              onPressed: () => _toggleAttribute(ParchmentAttribute.bold),
              isActive: _isAttributeActive(ParchmentAttribute.bold),
            ),
            _ToolbarButton(
              icon: Symbols.format_italic,
              tooltip: 'Italic',
              onPressed: () => _toggleAttribute(ParchmentAttribute.italic),
              isActive: _isAttributeActive(ParchmentAttribute.italic),
            ),
            _ToolbarButton(
              icon: Symbols.format_underlined,
              tooltip: 'Underline',
              onPressed: () => _toggleAttribute(ParchmentAttribute.underline),
              isActive: _isAttributeActive(ParchmentAttribute.underline),
            ),
            _ToolbarButton(
              icon: Symbols.format_strikethrough,
              tooltip: 'Strikethrough',
              onPressed: () => _toggleAttribute(ParchmentAttribute.strikethrough),
              isActive: _isAttributeActive(ParchmentAttribute.strikethrough),
            ),
          ],
        ),
      ),
    );
  }

  /// Toggle text formatting attribute
  void _toggleAttribute(ParchmentAttribute attribute) {
    controller.formatSelection(attribute);
    focusNode?.requestFocus();
  }

  /// Check if an attribute is currently active
  bool _isAttributeActive(ParchmentAttribute attribute) {
    final attrs = controller.getSelectionStyle().values;
    return attrs.contains(attribute);
  }
}

/// Single toolbar button
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isActive;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive ? cs.primaryContainer : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 22,
            color: isActive
                ? cs.onPrimaryContainer
                : cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
