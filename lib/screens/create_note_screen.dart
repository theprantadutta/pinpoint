import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../components/create_note_screen/create_note_categories.dart';
import '../components/create_note_screen/title_content_type/make_title_content_note.dart';
import '../components/layouts/main_layout.dart';
import '../constants/constants.dart';

class CreateNoteScreen extends StatefulWidget {
  static const String kRouteName = '/create-note';
  final String noticeType;

  const CreateNoteScreen({
    super.key,
    required this.noticeType,
  });

  @override
  State<CreateNoteScreen> createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  String selectedNoteType = kNoteTypes[0];

  @override
  void initState() {
    selectedNoteType = widget.noticeType;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final darkerColor =
        isDarkTheme ? Colors.grey.shade400 : Colors.grey.shade600;
    return MainLayout(
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              spacing: 5,
              children: [
                Icon(
                  Symbols.folder_open_rounded,
                  size: 18,
                  color: darkerColor,
                ),
                Text(
                  'Folder',
                  style: TextStyle(
                    color: darkerColor,
                  ),
                ),
                Icon(
                  Symbols.arrow_downward,
                  size: 15,
                  color: darkerColor,
                ),
              ],
            ),
          ],
        ),
        SizedBox(width: 15),
        Icon(
          Symbols.keep_rounded,
          size: 20,
          color: darkerColor,
        ),
        SizedBox(width: 10),
        Icon(
          Symbols.more_vert_rounded,
          size: 20,
          color: darkerColor,
        ),
      ],
      body: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: CustomScrollView(
          slivers: [
            CreateNoteCategories(
              selectedType: selectedNoteType,
              onSelectedTypeChanged: (text) {
                setState(() {
                  selectedNoteType = text;
                });
              },
            ),
            if (selectedNoteType == kNoteTypes[0]) MakeTitleContentNote(),
          ],
        ),
      ),
    );
  }
}
