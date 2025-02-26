import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';

class QuillToolbar extends StatefulWidget {
  final QuillController quillController;
  const QuillToolbar({
    super.key,
    required this.quillController,
  });

  @override
  State<QuillToolbar> createState() => _QuillToolbarState();
}

class _QuillToolbarState extends State<QuillToolbar> {
  bool multiRowsDisplay = false;
  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 10.0,
            vertical: 8.0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Toolbar',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () => setState(
                  () => multiRowsDisplay = !multiRowsDisplay,
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Center(
                    child: Row(
                      children: [
                        Text(multiRowsDisplay ? 'Hide' : 'Expand'),
                        SizedBox(width: 2),
                        Icon(
                          multiRowsDisplay
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        QuillSimpleToolbar(
          controller: widget.quillController,
          config: QuillSimpleToolbarConfig(
            embedButtons: FlutterQuillEmbeds.toolbarButtons(),
            multiRowsDisplay: multiRowsDisplay,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              // color: kPrimaryColor.withValues(alpha: 0.05),
            ),
          ),
        ),
      ],
    );
  }
}
