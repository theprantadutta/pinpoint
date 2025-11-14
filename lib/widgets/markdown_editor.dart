import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'markdown_toolbar.dart';

/// Full-featured markdown editor with toolbar and live preview
class MarkdownEditor extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? hintText;
  final int? maxLines;
  final int? minLines;
  final bool showToolbar;
  final bool enablePreview;
  final TextStyle? textStyle;

  const MarkdownEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    this.hintText,
    this.maxLines,
    this.minLines,
    this.showToolbar = true,
    this.enablePreview = true,
    this.textStyle,
  });

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  bool _isPreviewMode = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Editor/Preview area
        Expanded(
          child: _isPreviewMode
              ? _buildPreview(isDarkMode)
              : _buildEditor(isDarkMode),
        ),

        // Markdown toolbar
        if (widget.showToolbar)
          MarkdownToolbar(
            controller: widget.controller,
            focusNode: widget.focusNode,
            onPreviewToggle: widget.enablePreview
                ? () => setState(() => _isPreviewMode = !_isPreviewMode)
                : null,
            isPreviewMode: _isPreviewMode,
          ),
      ],
    );
  }

  Widget _buildEditor(bool isDarkMode) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: widget.textStyle ??
            TextStyle(
              fontSize: 16,
              color: cs.onSurface,
              height: 1.5,
            ),
        decoration: InputDecoration(
          hintText: widget.hintText ?? 'Write your note in markdown...',
          hintStyle: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.4),
            fontSize: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          contentPadding: EdgeInsets.all(15),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildPreview(bool isDarkMode) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        if (value.text.isEmpty) {
          return Center(
            child: Text(
              'No content to preview',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.4),
                fontSize: 16,
              ),
            ),
          );
        }

        return Markdown(
          data: value.text,
          selectable: true,
          padding: EdgeInsets.zero,
          styleSheet: MarkdownStyleSheet.fromTheme(
            Theme.of(context),
          ).copyWith(
            // Customize markdown styles here
            h1: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
            h2: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
            h3: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
            p: TextStyle(
              fontSize: 16,
              color: cs.onSurface,
              height: 1.5,
            ),
            code: TextStyle(
              backgroundColor: cs.surfaceContainerHighest,
              fontFamily: 'monospace',
            ),
            codeblockDecoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            blockquote: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
            ),
            blockquoteDecoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: cs.outline.withValues(alpha: 0.5),
                  width: 4,
                ),
              ),
            ),
            listBullet: TextStyle(
              color: cs.onSurface,
            ),
          ),
          onTapLink: (text, href, title) async {
            if (href != null) {
              final uri = Uri.tryParse(href);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          },
        );
      },
    );
  }
}
