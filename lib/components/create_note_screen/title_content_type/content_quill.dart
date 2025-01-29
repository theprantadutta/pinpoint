import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class ContentQuill extends StatefulWidget {
  const ContentQuill({super.key});

  @override
  State<ContentQuill> createState() => _ContentQuillState();
}

class _ContentQuillState extends State<ContentQuill> {
  late QuillController _controller;

  @override
  void initState() {
    _controller = QuillController.basic();
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 8),
        Container(
          height: MediaQuery.sizeOf(context).height * 0.06,
          margin: EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
              // color: kPrimaryColor.withValues(alpha: 0.5),
              ),
          child: QuillToolbar.simple(
            controller: _controller,
            configurations: QuillSimpleToolbarConfigurations(
              multiRowsDisplay: false,
              color: kPrimaryColor.withValues(alpha: 0.05),
              sharedConfigurations: QuillSharedConfigurations(
                locale: Locale('en'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: MediaQuery.sizeOf(context).height * 0.65,
          padding: EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: Colors.blueGrey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(15),
          ),
          child: QuillEditor.basic(
            controller: _controller,
            configurations: QuillEditorConfigurations(
              placeholder: 'Enter Content...',
              sharedConfigurations: QuillSharedConfigurations(
                locale: Locale('en'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
