import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

/// Toolbar for markdown text formatting
/// Provides buttons to insert common markdown syntax
class MarkdownToolbar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback? onPreviewToggle;
  final bool isPreviewMode;

  const MarkdownToolbar({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onPreviewToggle,
    this.isPreviewMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            _ToolbarButton(
              icon: Symbols.format_bold,
              tooltip: 'Bold',
              onPressed: () => _wrapSelection('**', '**'),
            ),
            _ToolbarButton(
              icon: Symbols.format_italic,
              tooltip: 'Italic',
              onPressed: () => _wrapSelection('*', '*'),
            ),
            _ToolbarButton(
              icon: Symbols.format_strikethrough,
              tooltip: 'Strikethrough',
              onPressed: () => _wrapSelection('~~', '~~'),
            ),
            const SizedBox(width: 8),
            const _ToolbarDivider(),
            const SizedBox(width: 8),
            _ToolbarButton(
              icon: Symbols.title,
              tooltip: 'Heading',
              onPressed: () => _insertAtLineStart('# '),
            ),
            _ToolbarButton(
              icon: Symbols.format_list_bulleted,
              tooltip: 'Bullet List',
              onPressed: () => _insertAtLineStart('- '),
            ),
            _ToolbarButton(
              icon: Symbols.format_list_numbered,
              tooltip: 'Numbered List',
              onPressed: () => _insertAtLineStart('1. '),
            ),
            _ToolbarButton(
              icon: Symbols.checklist,
              tooltip: 'Checkbox',
              onPressed: () => _insertAtLineStart('- [ ] '),
            ),
            const SizedBox(width: 8),
            const _ToolbarDivider(),
            const SizedBox(width: 8),
            _ToolbarButton(
              icon: Symbols.code,
              tooltip: 'Inline Code',
              onPressed: () => _wrapSelection('`', '`'),
            ),
            _ToolbarButton(
              icon: Symbols.code_blocks,
              tooltip: 'Code Block',
              onPressed: () => _wrapSelection('```\n', '\n```'),
            ),
            _ToolbarButton(
              icon: Symbols.format_quote,
              tooltip: 'Quote',
              onPressed: () => _insertAtLineStart('> '),
            ),
            _ToolbarButton(
              icon: Symbols.link,
              tooltip: 'Link',
              onPressed: () => _insertLink(),
            ),
            const SizedBox(width: 8),
            const _ToolbarDivider(),
            const SizedBox(width: 8),
            _ToolbarButton(
              icon: Symbols.horizontal_rule,
              tooltip: 'Horizontal Line',
              onPressed: () => _insertText('\n---\n'),
            ),
            if (onPreviewToggle != null) ...[
              const SizedBox(width: 8),
              const _ToolbarDivider(),
              const SizedBox(width: 8),
              _ToolbarButton(
                icon: isPreviewMode ? Symbols.edit : Symbols.preview,
                tooltip: isPreviewMode ? 'Edit' : 'Preview',
                onPressed: onPreviewToggle!,
                isActive: isPreviewMode,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Wrap selected text with prefix and suffix
  void _wrapSelection(String prefix, String suffix) {
    final text = controller.text;
    final selection = controller.selection;

    if (!selection.isValid) return;

    final selectedText = selection.textInside(text);
    final before = text.substring(0, selection.start);
    final after = text.substring(selection.end);

    final newText = selectedText.isEmpty
        ? '$before${prefix}text$suffix$after'
        : '$before$prefix$selectedText$suffix$after';

    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + prefix.length + (selectedText.isEmpty ? 4 : selectedText.length),
      ),
    );

    focusNode.requestFocus();
  }

  /// Insert text at the beginning of the current line
  void _insertAtLineStart(String prefix) {
    final text = controller.text;
    final selection = controller.selection;

    if (!selection.isValid) return;

    // Find start of current line
    final lineStart = text.lastIndexOf('\n', selection.start - 1) + 1;
    final before = text.substring(0, lineStart);
    final after = text.substring(lineStart);

    final newText = '$before$prefix$after';

    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(
        offset: lineStart + prefix.length,
      ),
    );

    focusNode.requestFocus();
  }

  /// Insert text at cursor position
  void _insertText(String textToInsert) {
    final text = controller.text;
    final selection = controller.selection;

    if (!selection.isValid) return;

    final before = text.substring(0, selection.start);
    final after = text.substring(selection.end);

    final newText = '$before$textToInsert$after';

    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + textToInsert.length,
      ),
    );

    focusNode.requestFocus();
  }

  /// Insert markdown link
  void _insertLink() {
    final text = controller.text;
    final selection = controller.selection;

    if (!selection.isValid) return;

    final selectedText = selection.textInside(text);
    final before = text.substring(0, selection.start);
    final after = text.substring(selection.end);

    final linkText = selectedText.isEmpty ? 'link text' : selectedText;
    final linkUrl = 'https://';

    final newText = '$before[$linkText]($linkUrl)$after';

    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection(
        baseOffset: selection.start + linkText.length + 3,
        extentOffset: selection.start + linkText.length + 3 + linkUrl.length,
      ),
    );

    focusNode.requestFocus();
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive
                ? (isDarkMode ? Colors.blue[900] : Colors.blue[100])
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isActive
                ? (isDarkMode ? Colors.blue[300] : Colors.blue[700])
                : (isDarkMode ? Colors.grey[400] : Colors.grey[700]),
          ),
        ),
      ),
    );
  }
}

/// Vertical divider for toolbar
class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 1,
      height: 20,
      color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
    );
  }
}
