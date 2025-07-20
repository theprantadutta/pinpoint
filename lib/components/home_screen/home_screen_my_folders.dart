import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:pinpoint/services/dialog_service.dart';
import 'package:pinpoint/services/drift_note_folder_service.dart';
import 'package:pinpoint/util/show_a_toast.dart';

import '../../components/home_screen/home_screen_folder_list.dart';

class HomeScreenMyFolders extends StatelessWidget {
  const HomeScreenMyFolders({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Folders',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              GestureDetector(
                onTap: () {
                  final controller = TextEditingController();
                  DialogService.addSomethingDialog(
                    context: context,
                    controller: controller,
                    title: 'Add Folder',
                    hintText: 'Enter folder name',
                    onAddPressed: () async {
                      final text = controller.text.trim();
                      if (text.isNotEmpty) {
                        // This is a simplified check. For a large number of folders,
                        // it would be better to query the database directly.
                        final folders = await DriftNoteFolderService.watchAllNoteFoldersStream().first;
                        if (folders.any((f) => f.noteFolderTitle.toLowerCase() == text.toLowerCase())) {
                          showErrorToast(
                            context: context,
                            title: 'Folder already exists',
                            description: 'Please choose a unique name.',
                          );
                          return;
                        }
                        await DriftNoteFolderService.insertNoteFolder(text);
                        Navigator.of(context).pop();
                      }
                    },
                  );
                },
                child: Icon(Symbols.add),
              ),
            ],
          ),
          SizedBox(height: 5),
          HomeScreenFolderList(),
        ],
      ),
    );
  }
}
