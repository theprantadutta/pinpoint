import 'package:flutter/material.dart';
import 'package:fleather/fleather.dart';
import 'markdown_toolbar.dart';

/// Simple WYSIWYG markdown editor powered by Fleather
/// Shows formatted text while editing (no markdown syntax visible)
class MarkdownEditor extends StatefulWidget {
  final FleatherController controller;
  final FocusNode? focusNode;
  final String? hintText;
  final bool showToolbar;
  final ValueChanged<String>? onChanged;

  const MarkdownEditor({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText,
    this.showToolbar = true,
    this.onChanged,
  });

  /// Creates a FleatherController from markdown text
  static FleatherController createControllerFromMarkdown(String markdown) {
    if (markdown.isEmpty) {
      return FleatherController();
    }

    try {
      // For now, use plain text - we can add proper markdown support later
      // The formatting will be preserved through Fleather's rich text
      final doc = ParchmentDocument.fromDelta(
        Delta()..insert(markdown),
      );
      return FleatherController(document: doc);
    } catch (e) {
      // Fallback to empty controller
      return FleatherController();
    }
  }

  /// Converts the current controller content to markdown text
  static String controllerToMarkdown(FleatherController controller) {
    try {
      // Get plain text for now - formatting is maintained in the editor
      // TODO: Add proper markdown export with formatting
      return controller.document.toPlainText();
    } catch (e) {
      return '';
    }
  }

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  @override
  void initState() {
    super.initState();
    // Listen to document changes and notify parent
    widget.controller.addListener(_onDocumentChanged);
  }

  void _onDocumentChanged() {
    if (widget.onChanged != null) {
      final markdown = MarkdownEditor.controllerToMarkdown(widget.controller);
      widget.onChanged!(markdown);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onDocumentChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    final backgroundColor = isDark ? cs.surfaceContainerLow : cs.surfaceContainerLowest;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: [
          // Editor area - leave space at bottom for toolbar
          Positioned.fill(
            bottom: widget.showToolbar ? 68 : 0,
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: FleatherEditor(
                controller: widget.controller,
                focusNode: widget.focusNode,
                padding: EdgeInsets.zero,
                autofocus: false,
                expands: true,
              ),
            ),
          ),

          // Toolbar - absolutely positioned above keyboard
          if (widget.showToolbar)
            Positioned(
              left: 0,
              right: 0,
              bottom: keyboardHeight,
              child: MarkdownToolbar(
                controller: widget.controller,
                focusNode: widget.focusNode,
              ),
            ),
        ],
      ),
    );
  }
}
