import 'package:flutter/material.dart';
import 'package:fleather/fleather.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../design_system/design_system.dart';

/// Binds a [FleatherController] to the Sketchbook [EditorToolbar].
///
/// The first screenful matches the mock — colour dot, B, I, U, S, H1,
/// checklist, image — and the rest of the formatting actions (H2, H3,
/// highlight, lists, quote, code, alignment, link, clear) follow in the same
/// horizontal scroller, so nothing the old toolbar could do was lost.
class MarkdownToolbar extends StatefulWidget {
  final FleatherController controller;
  final FocusNode? focusNode;

  /// The note's pastel for the colour dot; null shows the pen colour.
  final Color? noteColor;
  final VoidCallback? onColorPressed;

  /// The image tool (scan an image for text). Hidden when null.
  final VoidCallback? onImagePressed;

  const MarkdownToolbar({
    super.key,
    required this.controller,
    this.focusNode,
    this.noteColor,
    this.onColorPressed,
    this.onImagePressed,
  });

  /// The highlight is stored as a background + foreground colour pair inside
  /// the note's (encrypted) delta: yellow behind, ink in front, so the
  /// marked words read the same on light and dark paper.
  static final int highlightBackground = SketchPastels.yellow.toARGB32();
  static final int highlightForeground = SketchPastels.onPastel.toARGB32();

  @override
  State<MarkdownToolbar> createState() => _MarkdownToolbarState();
}

class _MarkdownToolbarState extends State<MarkdownToolbar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateToolbar);
  }

  @override
  void didUpdateWidget(MarkdownToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_updateToolbar);
      widget.controller.addListener(_updateToolbar);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateToolbar);
    super.dispose();
  }

  void _updateToolbar() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final style = widget.controller.getSelectionStyle();
    bool on(ParchmentAttribute a) => style.containsSame(a);
    final highlighted = style.get(ParchmentAttribute.backgroundColor)?.value ==
        MarkdownToolbar.highlightBackground;

    EditorToolbarItem glyph(
      String g,
      String label,
      ParchmentAttribute attr,
      VoidCallback onPressed, {
      TextStyle? glyphStyle,
    }) =>
        EditorToolbarItem(
          glyph: g,
          glyphStyle: glyphStyle,
          semanticLabel: label,
          active: on(attr),
          onPressed: onPressed,
        );

    EditorToolbarItem icon(
      IconData i,
      String label,
      VoidCallback onPressed, {
      bool active = false,
    }) =>
        EditorToolbarItem(
          icon: i,
          semanticLabel: label,
          active: active,
          onPressed: onPressed,
        );

    final items = <EditorToolbarItem>[
      glyph('B', l10n.mdBold, ParchmentAttribute.bold,
          () => _toggleAttribute(ParchmentAttribute.bold),
          glyphStyle:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      glyph('I', l10n.mdItalic, ParchmentAttribute.italic,
          () => _toggleAttribute(ParchmentAttribute.italic),
          glyphStyle: const TextStyle(
              fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
      glyph('U', l10n.mdUnderline, ParchmentAttribute.underline,
          () => _toggleAttribute(ParchmentAttribute.underline),
          glyphStyle: const TextStyle(decoration: TextDecoration.underline)),
      glyph('S', l10n.mdStrikethrough, ParchmentAttribute.strikethrough,
          () => _toggleAttribute(ParchmentAttribute.strikethrough),
          glyphStyle: const TextStyle(decoration: TextDecoration.lineThrough)),
      glyph('H1', l10n.mdHeading1, ParchmentAttribute.h1,
          () => _toggleHeading(ParchmentAttribute.h1),
          glyphStyle: const TextStyle(fontSize: 13)),
      icon(Icons.check_box_outlined, l10n.mdChecklist,
          () => _toggleBlock(ParchmentAttribute.cl),
          active: on(ParchmentAttribute.cl)),
      if (widget.onImagePressed != null)
        icon(Icons.image_outlined, l10n.edScanText, widget.onImagePressed!),
      glyph('H2', l10n.mdHeading2, ParchmentAttribute.h2,
          () => _toggleHeading(ParchmentAttribute.h2),
          glyphStyle: const TextStyle(fontSize: 13)),
      glyph('H3', l10n.mdHeading3, ParchmentAttribute.h3,
          () => _toggleHeading(ParchmentAttribute.h3),
          glyphStyle: const TextStyle(fontSize: 13)),
      icon(Icons.border_color_outlined, l10n.edHighlight, _toggleHighlight,
          active: highlighted),
      icon(Icons.format_list_bulleted_rounded, l10n.mdBulletList,
          () => _toggleBlock(ParchmentAttribute.ul),
          active: on(ParchmentAttribute.ul)),
      icon(Icons.format_list_numbered_rounded, l10n.mdNumberedList,
          () => _toggleBlock(ParchmentAttribute.ol),
          active: on(ParchmentAttribute.ol)),
      icon(Icons.format_quote_rounded, l10n.mdQuote,
          () => _toggleBlock(ParchmentAttribute.bq),
          active: on(ParchmentAttribute.bq)),
      icon(Icons.code_rounded, l10n.mdCodeBlock,
          () => _toggleBlock(ParchmentAttribute.code),
          active: on(ParchmentAttribute.code)),
      icon(Icons.format_align_left_rounded, l10n.mdAlignLeft,
          () => _toggleAlignment(ParchmentAttribute.left),
          active: on(ParchmentAttribute.left)),
      icon(Icons.format_align_center_rounded, l10n.mdAlignCenter,
          () => _toggleAlignment(ParchmentAttribute.center),
          active: on(ParchmentAttribute.center)),
      icon(Icons.format_align_right_rounded, l10n.mdAlignRight,
          () => _toggleAlignment(ParchmentAttribute.right),
          active: on(ParchmentAttribute.right)),
      icon(Icons.link_rounded, l10n.mdInsertLink, _insertLink),
      icon(
          Icons.format_clear_rounded, l10n.mdClearFormatting, _clearFormatting),
    ];

    return EditorToolbar(
      semanticLabel: l10n.edFormatting,
      items: items,
      color: widget.noteColor,
      colorLabel: l10n.edColor,
      onColorPressed: widget.onColorPressed,
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

  /// Toggle the yellow marker highlight on the selection.
  void _toggleHighlight() {
    final style = widget.controller.getSelectionStyle();
    final active = style.get(ParchmentAttribute.backgroundColor)?.value ==
        MarkdownToolbar.highlightBackground;
    if (active) {
      widget.controller
          .formatSelection(ParchmentAttribute.backgroundColor.unset);
      widget.controller
          .formatSelection(ParchmentAttribute.foregroundColor.unset);
    } else {
      widget.controller.formatSelection(ParchmentAttribute.backgroundColor
          .withColor(MarkdownToolbar.highlightBackground));
      widget.controller.formatSelection(ParchmentAttribute.foregroundColor
          .withColor(MarkdownToolbar.highlightForeground));
    }
    widget.focusNode?.requestFocus();
  }

  /// Insert a link
  void _insertLink() {
    final selection = widget.controller.selection;
    final initialText = selection.isCollapsed
        ? ''
        : widget.controller.document
            .toPlainText()
            .substring(selection.start, selection.end);

    showSketchSheet<void>(
      context: context,
      builder: (sheetContext) => _LinkSheet(
        initialText: initialText,
        onInsert: (url, text) {
          // Insert link in the document
          final selectedText = widget.controller.document
              .toPlainText()
              .substring(selection.start, selection.end);

          if (selectedText.isNotEmpty) {
            // Apply link to selected text
            widget.controller.formatText(
              selection.start,
              selection.end - selection.start,
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
    final selection = widget.controller.selection;
    final length = selection.end - selection.start;
    for (final attr in [
      ParchmentAttribute.bold.unset,
      ParchmentAttribute.italic.unset,
      ParchmentAttribute.underline.unset,
      ParchmentAttribute.strikethrough.unset,
      ParchmentAttribute.backgroundColor.unset,
      ParchmentAttribute.foregroundColor.unset,
    ]) {
      widget.controller.formatText(selection.start, length, attr);
    }

    widget.focusNode?.requestFocus();
  }
}

/// Link insertion sheet: URL and the text to show.
class _LinkSheet extends StatefulWidget {
  final String initialText;
  final void Function(String url, String text) onInsert;

  const _LinkSheet({
    required this.initialText,
    required this.onInsert,
  });

  @override
  State<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends State<_LinkSheet> {
  late final TextEditingController _urlController = TextEditingController();
  late final TextEditingController _textController =
      TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _urlController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_urlController.text.isEmpty) return;
    final text = _textController.text.isNotEmpty
        ? _textController.text
        : _urlController.text;
    widget.onInsert(_urlController.text, text);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return SketchSheet(
      title: l10n.mdInsertLink,
      footer: PillButton(label: l10n.mdInsert, onPressed: _submit),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.mdUrl,
              hintText: 'https://example.com',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l10n.mdLinkText,
              hintText: l10n.mdLinkTextHint,
            ),
          ),
        ],
      ),
    );
  }
}
