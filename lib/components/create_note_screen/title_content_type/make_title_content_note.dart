import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:keyboard_avoider/keyboard_avoider.dart';

import 'quill_toolbar.dart';

class MakeTitleContentNote extends StatefulWidget {
  final QuillController quillController;
  final FocusNode focusNode;
  final ScrollController scrollController;

  const MakeTitleContentNote({
    super.key,
    required this.quillController,
    required this.focusNode,
    required this.scrollController,
  });

  @override
  State<MakeTitleContentNote> createState() => _MakeTitleContentNoteState();
}

class _MakeTitleContentNoteState extends State<MakeTitleContentNote> {
  final GlobalKey _containerKey = GlobalKey();
  final GlobalKey _editorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
    widget.quillController.addListener(_onTextChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    widget.quillController.removeListener(_onTextChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (widget.focusNode.hasFocus) {
      _scrollToShowEditor();
    }
  }

  void _onTextChange() {
    if (widget.focusNode.hasFocus) {
      _scrollToShowEditor();
    }
  }

  void _scrollToShowEditor() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final containerContext = _containerKey.currentContext;
      if (containerContext != null) {
        Scrollable.ensureVisible(
          containerContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: 0.0,
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Column(
          key: _containerKey, // Key on whole column to include toolbar in scroll
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QuillToolbar(
              quillController: widget.quillController,
            ),
            const SizedBox(height: 8),
            Container(
              key: _editorKey, // Key on editor to track its position
              constraints: const BoxConstraints(
                minHeight: 300,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? cs.surface.withValues(alpha: 0.4)
                    : cs.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.outline.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: QuillEditor.basic(
                controller: widget.quillController,
                focusNode: widget.focusNode,
                config: QuillEditorConfig(
                  expands: false,
                  embedBuilders: [
                    ...kIsWeb
                        ? FlutterQuillEmbeds.editorWebBuilders()
                        : FlutterQuillEmbeds.editorBuilders(),
                  ],
                  placeholder: 'Start writing your note...',
                  scrollable: false, // Let outer scroll handle it
                  padding: const EdgeInsets.all(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
