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

  /// Forces a delta to satisfy Parchment's document invariant: it must end with
  /// a line break.
  ///
  /// Parchment checks this with an `assert` inside
  /// `ParchmentDocument._loadDocument`, and asserts are stripped from release
  /// builds. So an un-terminated delta does NOT fail loudly in production — it
  /// quietly builds a malformed node tree, and the damage surfaces later and
  /// somewhere else entirely: the next insert near the end of that document
  /// walks off the end of the tree and dies inside `ContainerNode.insert` with
  /// "Null check operator used on a null value", reported from the keyboard
  /// path (`RawEditorStateTextInputClientMixin.updateEditingValueWithDeltas`).
  /// In debug the assert fires instead and the old catch-all swallowed it,
  /// which showed up as a note opening blank.
  ///
  /// Every delta must pass through here before it reaches Parchment.
  static Delta _asDocumentDelta(Delta delta) {
    if (delta.isEmpty) return Delta()..insert('\n');
    final data = delta.last.data;
    if (data is String && data.endsWith('\n')) return delta;
    // Un-terminated text, or a trailing embed, both need a closing line break.
    return Delta.from(delta)..insert('\n');
  }

  /// Decodes stored note content into a valid document delta.
  ///
  /// Content is normally a JSON Delta array. Anything else — genuinely plain
  /// text from an old note, or JSON that is not a delta array (a bare number,
  /// `true`, an object) — is treated as the note's literal text. That last case
  /// used to fall through to an empty controller, which silently wiped the note
  /// on the next save.
  static Delta _deltaForStoredContent(String content) {
    Object? decoded;
    try {
      decoded = jsonDecode(content);
    } catch (_) {
      decoded = null; // Not JSON at all.
    }

    if (decoded is List) {
      try {
        return _asDocumentDelta(Delta.fromJson(decoded));
      } catch (_) {
        // A JSON array that isn't a usable delta; keep the raw text instead.
      }
    }

    return _asDocumentDelta(Delta()..insert(content));
  }

  /// Creates a FleatherController from stored content (JSON Delta format)
  /// Supports both plain text and rich JSON format for backward compatibility
  static FleatherController createControllerFromMarkdown(String content) {
    if (content.isEmpty) {
      return FleatherController();
    }

    try {
      return FleatherController(
        document: ParchmentDocument.fromDelta(_deltaForStoredContent(content)),
      );
    } catch (e) {
      debugPrint('⚠️ [MarkdownEditor] Could not load note content: $e');
      // Never throw while opening a note. Keep the text as one plain line
      // rather than dropping what the user wrote.
      try {
        return FleatherController(
          document: ParchmentDocument.fromDelta(
            _asDocumentDelta(Delta()..insert(content)),
          ),
        );
      } catch (_) {
        return FleatherController();
      }
    }
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
