import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:fleather/fleather.dart';

/// Enhanced toolbar for rich text formatting with Fleather
/// Provides extensive WYSIWYG formatting options including text styles, colors, lists, and more
class MarkdownToolbar extends StatefulWidget {
  final FleatherController controller;
  final FocusNode? focusNode;

  const MarkdownToolbar({
    super.key,
    required this.controller,
    this.focusNode,
  });

  @override
  State<MarkdownToolbar> createState() => _MarkdownToolbarState();
}

class _MarkdownToolbarState extends State<MarkdownToolbar> {
  @override
  void initState() {
    super.initState();
    // Listen to controller changes to update toolbar button states
    widget.controller.addListener(_updateToolbar);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateToolbar);
    super.dispose();
  }

  void _updateToolbar() {
    // Update the toolbar when the selection or formatting changes
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main toolbar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Text Formatting
                _buildSection([
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
                ]),

                _buildDivider(),

                // Headings
                _buildSection([
                  _ToolbarButton(
                    icon: Symbols.format_h1,
                    tooltip: 'Heading 1',
                    onPressed: () => _toggleHeading(ParchmentAttribute.h1),
                    isActive: _isAttributeActive(ParchmentAttribute.h1),
                  ),
                  _ToolbarButton(
                    icon: Symbols.format_h2,
                    tooltip: 'Heading 2',
                    onPressed: () => _toggleHeading(ParchmentAttribute.h2),
                    isActive: _isAttributeActive(ParchmentAttribute.h2),
                  ),
                  _ToolbarButton(
                    icon: Symbols.format_h3,
                    tooltip: 'Heading 3',
                    onPressed: () => _toggleHeading(ParchmentAttribute.h3),
                    isActive: _isAttributeActive(ParchmentAttribute.h3),
                  ),
                ]),

                _buildDivider(),

                // Lists
                _buildSection([
                  _ToolbarButton(
                    icon: Symbols.format_list_bulleted,
                    tooltip: 'Bullet List',
                    onPressed: () => _toggleBlock(ParchmentAttribute.ul),
                    isActive: _isAttributeActive(ParchmentAttribute.ul),
                  ),
                  _ToolbarButton(
                    icon: Symbols.format_list_numbered,
                    tooltip: 'Numbered List',
                    onPressed: () => _toggleBlock(ParchmentAttribute.ol),
                    isActive: _isAttributeActive(ParchmentAttribute.ol),
                  ),
                  _ToolbarButton(
                    icon: Symbols.checklist,
                    tooltip: 'Checklist',
                    onPressed: () => _toggleBlock(ParchmentAttribute.cl),
                    isActive: _isAttributeActive(ParchmentAttribute.cl),
                  ),
                ]),

                _buildDivider(),

                // Special Formatting
                _buildSection([
                  _ToolbarButton(
                    icon: Symbols.format_quote,
                    tooltip: 'Quote',
                    onPressed: () => _toggleBlock(ParchmentAttribute.bq),
                    isActive: _isAttributeActive(ParchmentAttribute.bq),
                  ),
                  _ToolbarButton(
                    icon: Symbols.code,
                    tooltip: 'Code Block',
                    onPressed: () => _toggleBlock(ParchmentAttribute.code),
                    isActive: _isAttributeActive(ParchmentAttribute.code),
                  ),
                ]),

                _buildDivider(),

                // Alignment
                _buildSection([
                  _ToolbarButton(
                    icon: Symbols.format_align_left,
                    tooltip: 'Align Left',
                    onPressed: () => _toggleAlignment(ParchmentAttribute.left),
                    isActive: _isAttributeActive(ParchmentAttribute.left),
                  ),
                  _ToolbarButton(
                    icon: Symbols.format_align_center,
                    tooltip: 'Align Center',
                    onPressed: () => _toggleAlignment(ParchmentAttribute.center),
                    isActive: _isAttributeActive(ParchmentAttribute.center),
                  ),
                  _ToolbarButton(
                    icon: Symbols.format_align_right,
                    tooltip: 'Align Right',
                    onPressed: () => _toggleAlignment(ParchmentAttribute.right),
                    isActive: _isAttributeActive(ParchmentAttribute.right),
                  ),
                ]),

                _buildDivider(),

                // Utilities
                _buildSection([
                  _ToolbarButton(
                    icon: Symbols.link,
                    tooltip: 'Insert Link',
                    onPressed: _insertLink,
                    isActive: false,
                  ),
                  _ToolbarButton(
                    icon: Symbols.format_clear,
                    tooltip: 'Clear Formatting',
                    onPressed: _clearFormatting,
                    isActive: false,
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(List<Widget> buttons) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: buttons,
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
    );
  }

  /// Toggle text formatting attribute
  void _toggleAttribute(ParchmentAttribute attribute) {
    final currentStyle = widget.controller.getSelectionStyle();

    // If the attribute is already active, remove it
    if (currentStyle.containsSame(attribute)) {
      widget.controller.formatSelection(attribute.unset);
    } else {
      widget.controller.formatSelection(attribute);
    }

    widget.focusNode?.requestFocus();
  }

  /// Toggle heading style
  void _toggleHeading(ParchmentAttribute heading) {
    final currentStyle = widget.controller.getSelectionStyle();

    // If the heading is already active, remove it
    if (currentStyle.containsSame(heading)) {
      widget.controller.formatSelection(ParchmentAttribute.heading.unset);
    } else {
      widget.controller.formatSelection(heading);
    }

    widget.focusNode?.requestFocus();
  }

  /// Toggle block-level formatting (lists, quotes, code)
  void _toggleBlock(ParchmentAttribute block) {
    final currentStyle = widget.controller.getSelectionStyle();

    // If the block is already active, remove it
    if (currentStyle.containsSame(block)) {
      widget.controller.formatSelection(block.unset);
    } else {
      widget.controller.formatSelection(block);
    }

    widget.focusNode?.requestFocus();
  }

  /// Toggle text alignment
  void _toggleAlignment(ParchmentAttribute alignment) {
    final currentStyle = widget.controller.getSelectionStyle();

    // If the alignment is already active, remove it (back to default left)
    if (currentStyle.containsSame(alignment)) {
      widget.controller.formatSelection(ParchmentAttribute.alignment.unset);
    } else {
      widget.controller.formatSelection(alignment);
    }

    widget.focusNode?.requestFocus();
  }

  /// Insert a link
  void _insertLink() {
    showDialog(
      context: context,
      builder: (context) => _LinkDialog(
        controller: widget.controller,
        onInsert: (url, text) {
          // Insert link in the document
          final selection = widget.controller.selection;
          final selectedText = widget.controller.document
              .toPlainText()
              .substring(selection.start, selection.end);

          if (selectedText.isNotEmpty) {
            // Apply link to selected text
            widget.controller.formatSelection(
              ParchmentAttribute.link.fromString(url),
            );
          } else {
            // Insert link with provided text
            widget.controller.replaceText(
              selection.start,
              0,
              text,
            );
            // Format the inserted text as a link
            widget.controller.formatText(
              selection.start,
              text.length,
              ParchmentAttribute.link.fromString(url),
            );
          }

          widget.focusNode?.requestFocus();
        },
      ),
    );
  }

  /// Clear all formatting from selection
  void _clearFormatting() {
    // Clear all inline styles
    final selection = widget.controller.selection;
    widget.controller.formatText(
      selection.start,
      selection.end - selection.start,
      ParchmentAttribute.bold.unset,
    );
    widget.controller.formatText(
      selection.start,
      selection.end - selection.start,
      ParchmentAttribute.italic.unset,
    );
    widget.controller.formatText(
      selection.start,
      selection.end - selection.start,
      ParchmentAttribute.underline.unset,
    );
    widget.controller.formatText(
      selection.start,
      selection.end - selection.start,
      ParchmentAttribute.strikethrough.unset,
    );

    widget.focusNode?.requestFocus();
  }

  /// Check if an attribute is currently active
  bool _isAttributeActive(ParchmentAttribute attribute) {
    final style = widget.controller.getSelectionStyle();
    return style.containsSame(attribute);
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

/// Link insertion dialog
class _LinkDialog extends StatefulWidget {
  final FleatherController controller;
  final Function(String url, String text) onInsert;

  const _LinkDialog({
    required this.controller,
    required this.onInsert,
  });

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late TextEditingController _urlController;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _textController = TextEditingController();

    // Pre-fill with selected text if any
    final selection = widget.controller.selection;
    if (!selection.isCollapsed) {
      final selectedText = widget.controller.document
          .toPlainText()
          .substring(selection.start, selection.end);
      _textController.text = selectedText;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Insert Link'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'https://example.com',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            decoration: const InputDecoration(
              labelText: 'Link Text',
              hintText: 'Click here',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_urlController.text.isNotEmpty) {
              final text = _textController.text.isNotEmpty
                  ? _textController.text
                  : _urlController.text;
              widget.onInsert(_urlController.text, text);
              Navigator.pop(context);
            }
          },
          child: const Text('Insert'),
        ),
      ],
    );
  }
}
