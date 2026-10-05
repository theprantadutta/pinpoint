import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fleather/fleather.dart';
import 'package:material_ui/material_ui.dart' as material_ui;

import '../design_system/design_system.dart';

/// The note body editor: a Fleather rich-text editor styled as Sketchbook
/// paper (paragraph 16/1.65, H1 22/800, H2 18/700, H3 16/700, ink links,
/// yellow marker highlight). All formatting is preserved through the JSON
/// delta serialization below.
///
/// The editor is not scrollable itself: it sizes to its content and lives
/// inside the screen's scroll view, so the title, body and attachments scroll
/// as one page. The formatting toolbar is separate (`MarkdownToolbar`) and
/// floated by the screen above the keyboard.
class MarkdownEditor extends StatefulWidget {
  final FleatherController controller;
  final FocusNode? focusNode;
  final String? hintText;
  final ValueChanged<String>? onChanged;

  const MarkdownEditor({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText,
    this.onChanged,
  });

  /// The Sketchbook [FleatherThemeData]: every colour from [SketchColors],
  /// every face through the Sketchbook type scale.
  static FleatherThemeData sketchTheme(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final base = t.bodyLarge.copyWith(color: s.ink);
    final mono =
        PinpointTypography.codeBlock(brightness: Theme.of(context).brightness)
            .copyWith(color: s.ink);
    TextStyle heading(double size, FontWeight weight, double height) =>
        base.copyWith(
          fontSize: size,
          fontWeight: weight,
          height: height,
          letterSpacing: size >= 20 ? -0.02 * size : 0,
        );

    return FleatherThemeData(
      bold: const TextStyle(fontWeight: FontWeight.w800),
      italic: const TextStyle(fontStyle: FontStyle.italic),
      underline: TextStyle(
          decoration: TextDecoration.underline, decorationColor: s.ink),
      strikethrough: TextStyle(
          decoration: TextDecoration.lineThrough, decorationColor: s.ink),
      inlineCode: InlineCodeThemeData(
        backgroundColor: s.soft,
        radius: const Radius.circular(SketchRadius.highlight),
        style: mono,
      ),
      link: TextStyle(
        color: s.ink,
        decoration: TextDecoration.underline,
        decorationColor: s.ink,
        decorationThickness: 1.5,
      ),
      paragraph: TextBlockTheme(
        style: base,
        spacing: const VerticalSpacing(top: 2, bottom: 8),
      ),
      heading1: TextBlockTheme(
        style: heading(22, FontWeight.w800, 1.3),
        spacing: const VerticalSpacing(top: 14, bottom: 4),
      ),
      heading2: TextBlockTheme(
        style: heading(18, FontWeight.w700, 1.35),
        spacing: const VerticalSpacing(top: 12, bottom: 2),
      ),
      heading3: TextBlockTheme(
        style: heading(16, FontWeight.w700, 1.4),
        spacing: const VerticalSpacing(top: 12, bottom: 2),
      ),
      heading4: TextBlockTheme(
        style: heading(15, FontWeight.w700, 1.4),
        spacing: const VerticalSpacing(top: 10, bottom: 0),
      ),
      heading5: TextBlockTheme(
        style: heading(15, FontWeight.w600, 1.4),
        spacing: const VerticalSpacing(top: 8, bottom: 0),
      ),
      heading6: TextBlockTheme(
        style: heading(14, FontWeight.w600, 1.4).copyWith(color: s.muted),
        spacing: const VerticalSpacing(top: 8, bottom: 0),
      ),
      lists: TextBlockTheme(
        style: base.copyWith(fontSize: 15, height: 1.5),
        spacing: const VerticalSpacing(top: 2, bottom: 8),
        lineSpacing: const VerticalSpacing(bottom: 6),
      ),
      quote: TextBlockTheme(
        style: base.copyWith(color: s.muted),
        spacing: const VerticalSpacing(top: 4, bottom: 8),
        lineSpacing: const VerticalSpacing(top: 4, bottom: 2),
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(width: 3, color: s.ink),
          ),
        ),
      ),
      code: TextBlockTheme(
        style: mono,
        spacing: const VerticalSpacing(top: 4, bottom: 8),
        decoration: BoxDecoration(
          color: s.soft,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      horizontalRule: HorizontalRuleThemeData(
        height: 26,
        thickness: SketchStroke.outline,
        color: s.hairline,
      ),
    );
  }

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
  late bool _isEmpty;

  @override
  void initState() {
    super.initState();
    _isEmpty = _documentIsEmpty();
    widget.controller.addListener(_onDocumentChanged);
  }

  @override
  void didUpdateWidget(MarkdownEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onDocumentChanged);
      widget.controller.addListener(_onDocumentChanged);
      _isEmpty = _documentIsEmpty();
    }
  }

  bool _documentIsEmpty() =>
      MarkdownEditor.getPlainText(widget.controller).trim().isEmpty &&
      widget.controller.document.length <= 1;

  void _onDocumentChanged() {
    final empty = _documentIsEmpty();
    if (empty != _isEmpty && mounted) setState(() => _isEmpty = empty);
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
    final s = context.sketch;
    final t = context.type;

    // Fleather reads its cursor, selection and checklist-box styling from
    // package:material_ui's themes, which the app's MaterialApp does not
    // provide; give it the Sketchbook values directly.
    final editor = material_ui.TextSelectionTheme(
      data: material_ui.TextSelectionThemeData(
        cursorColor: s.ink,
        selectionColor: s.highlight.withValues(alpha: 0.7),
        selectionHandleColor: s.ink,
      ),
      child: material_ui.CheckboxTheme(
        data: material_ui.CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? SketchPastels.mint
                  : Colors.transparent),
          checkColor: const WidgetStatePropertyAll(SketchPastels.onPastel),
          side: WidgetStateBorderSide.resolveWith((states) => BorderSide(
                color: states.contains(WidgetState.selected)
                    ? SketchPastels.onPastel
                    : s.ink,
                width: SketchStroke.checkbox,
              )),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SketchRadius.checkboxSmall + 1),
          ),
        ),
        // Fleather's checklist boxes assert a package:material_ui Material
        // ancestor; the app's Scaffold is package:flutter's, a different
        // type, so provide a transparent one.
        child: material_ui.Material(
          type: material_ui.MaterialType.transparency,
          child: FleatherTheme(
            data: MarkdownEditor.sketchTheme(context),
            child: FleatherEditor(
              controller: widget.controller,
              focusNode: widget.focusNode,
              scrollable: false,
              padding: EdgeInsets.zero,
              autofocus: false,
            ),
          ),
        ),
      ),
    );

    if (widget.hintText == null) return editor;
    return Stack(
      children: [
        editor,
        if (_isEmpty)
          PositionedDirectional(
            start: 0,
            end: 0,
            top: 2,
            child: IgnorePointer(
              child: Text(
                widget.hintText!,
                style: t.bodyLarge.copyWith(color: s.muted),
              ),
            ),
          ),
      ],
    );
  }
}
