import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fleather/fleather.dart';
import 'markdown_toolbar.dart';

/// Advanced WYSIWYG editor powered by Fleather
/// Supports full rich text formatting including colors, headings, lists, links, and more
/// All formatting is preserved through JSON serialization
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

  /// Creates a FleatherController from stored content (JSON Delta format)
  /// Supports both plain text and rich JSON format for backward compatibility
  static FleatherController createControllerFromMarkdown(String content) {
    if (content.isEmpty) {
      return FleatherController();
    }

    try {
      // Try to parse as JSON (rich text format)
      final jsonData = jsonDecode(content);

      if (jsonData is List) {
        // It's a Delta JSON array
        final delta = Delta.fromJson(jsonData);
        final doc = ParchmentDocument.fromDelta(delta);
        return FleatherController(document: doc);
      }
    } catch (e) {
      // Not JSON, treat as plain text for backward compatibility
      // This maintains compatibility with old notes
      try {
        final doc = ParchmentDocument.fromDelta(
          Delta()..insert(content),
        );
        return FleatherController(document: doc);
      } catch (e) {
        // Fallback to empty controller
        return FleatherController();
      }
    }

    // Fallback
    return FleatherController();
  }

  /// Converts the current controller content to JSON format
  /// This preserves ALL formatting including colors, styles, headings, etc.
  static String controllerToMarkdown(FleatherController controller) {
    try {
      // Convert to JSON Delta format to preserve all formatting
      final delta = controller.document.toDelta();
      final jsonData = delta.toJson();
      return jsonEncode(jsonData);
    } catch (e) {
      // Fallback to plain text if something goes wrong
      try {
        return controller.document.toPlainText();
      } catch (e) {
        return '';
      }
    }
  }

  /// Get plain text version (for previews, search, etc.)
  static String getPlainText(FleatherController controller) {
    try {
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
      final content = MarkdownEditor.controllerToMarkdown(widget.controller);
      widget.onChanged!(content);
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
