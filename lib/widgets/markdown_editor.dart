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
  final bool showToolbar;
  final bool enablePreview;
  final TextStyle? textStyle;

  const MarkdownEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    this.hintText,
    this.maxLines,
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
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        maxLines: widget.maxLines,
        style: widget.textStyle ??
            TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.white : Colors.black87,
              fontFamily: 'monospace',
            ),
        decoration: InputDecoration(
          hintText: widget.hintText ?? 'Write your note in markdown...',
          hintStyle: TextStyle(
            color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildPreview(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
        ),
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: widget.controller,
        builder: (context, value, child) {
          if (value.text.isEmpty) {
            return Center(
              child: Text(
                'No content to preview',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                  fontSize: 16,
                ),
              ),
            );
          }

          return Markdown(
            data: value.text,
            selectable: true,
            padding: const EdgeInsets.all(16),
            styleSheet: MarkdownStyleSheet.fromTheme(
              Theme.of(context),
            ).copyWith(
              // Customize markdown styles here
              h1: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              h2: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              h3: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              p: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white : Colors.black87,
                height: 1.5,
              ),
              code: TextStyle(
                backgroundColor: isDarkMode ? Colors.grey[850] : Colors.grey[200],
                fontFamily: 'monospace',
              ),
              codeblockDecoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[850] : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              blockquote: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              blockquoteDecoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[400]!,
                    width: 4,
                  ),
                ),
              ),
              listBullet: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
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
      ),
    );
  }
}
