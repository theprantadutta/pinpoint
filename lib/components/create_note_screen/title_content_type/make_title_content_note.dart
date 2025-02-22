import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class MakeTitleContentNote extends StatelessWidget {
  final QuillController quillController;
  const MakeTitleContentNote({
    super.key,
    required this.quillController,
  });

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
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
            Container(
              height: MediaQuery.sizeOf(context).height * 0.06,
              margin: EdgeInsets.symmetric(vertical: 5),
              child: QuillSimpleToolbar(
                controller: quillController,
                config: QuillSimpleToolbarConfig(
                  multiRowsDisplay: false,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: kPrimaryColor.withValues(alpha: 0.05),
                  ),
                ),
              ),
            ),
            // const SizedBox(height: 5),
            Container(
              height: MediaQuery.sizeOf(context).height * 0.53,
              padding: EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(15),
              ),
              child: QuillEditor.basic(
                controller: quillController,
                config: QuillEditorConfig(
                  placeholder: 'Enter Content...',
                  onTapOutside: (_, __) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
