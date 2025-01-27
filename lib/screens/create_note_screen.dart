import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:pinpoint/components/create_note_screen/create_note_categories.dart';

import '../components/layouts/main_layout.dart';

class CreateNoteScreen extends StatelessWidget {
  static const String kRouteName = '/create-note';
  const CreateNoteScreen({super.key});

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
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 18.0),
        child: Column(
          children: [
            CreateNoteCategories(),
          ],
        ),
      ),
    );
  }
}
