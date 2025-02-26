import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:keyboard_avoider/keyboard_avoider.dart';

import 'quill_toolbar.dart';

class MakeTitleContentNote extends StatelessWidget {
  final QuillController quillController;
  const MakeTitleContentNote({
    super.key,
    required this.quillController,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(
          left: 10,
          right: 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 3),
            QuillToolbar(
              quillController: quillController,
            ),
            const SizedBox(height: 5),
            Container(
              height: MediaQuery.sizeOf(context).height * 0.49,
              padding: EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(15),
              ),
              child: KeyboardAvoider(
                child: QuillEditor.basic(
                  controller: quillController,
                  config: QuillEditorConfig(
                    expands: true,
                    embedBuilders: kIsWeb
                        ? FlutterQuillEmbeds.editorWebBuilders()
                        : FlutterQuillEmbeds.editorBuilders(),
                    placeholder: 'Enter Content...',
                    scrollable: true,
                    onTapOutside: (_, __) {
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                    padding: EdgeInsets.only(bottom: 50),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
