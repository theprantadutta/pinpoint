import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pinpoint/screens/folder_screen.dart';
import 'package:pinpoint/services/dialog_service.dart';
import 'package:pinpoint/util/show_a_toast.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../services/drift_note_folder_service.dart';

class HomeScreenFolderList extends StatelessWidget {
  const HomeScreenFolderList({super.key});

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    return StreamBuilder(
      stream: DriftNoteFolderService.watchAllNoteFoldersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return HomeScreenFolderListSkeletonizer();
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Something Went Wrong'),
          );
        }
        final noteFoldersData = snapshot.data!;
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.11,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: noteFoldersData.length,
            itemBuilder: (context, index) {
              final currentFolder = noteFoldersData[index];
              return GestureDetector(
                onTap: () {
                  context.push(
                    '${FolderScreen.kRouteName}/${currentFolder.noteFolderId}/${currentFolder.noteFolderTitle}',
                  );
                },
                onLongPress: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) {
                      return Wrap(
                        children: <Widget>[
                          ListTile(
                            leading: Icon(Icons.edit),
                            title: Text('Rename'),
                            onTap: () {
                              Navigator.pop(context);
                              final controller = TextEditingController(text: currentFolder.noteFolderTitle);
                              DialogService.addSomethingDialog(
                                context: context,
                                controller: controller,
                                title: 'Rename Folder',
                                hintText: 'Enter new name',
                                onAddPressed: () async {
                                  final text = controller.text.trim();
                                  if (text.isNotEmpty) {
                                    await DriftNoteFolderService.renameFolder(currentFolder.noteFolderId, text);
                                    Navigator.of(context).pop();
                                  }
                                },
                              );
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.delete),
                            title: Text('Delete'),
                            onTap: () {
                              Navigator.pop(context);
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Delete Folder'),
                                  content: Text('Are you sure you want to delete this folder? Notes inside will not be deleted.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        await DriftNoteFolderService.deleteFolder(currentFolder.noteFolderId);
                                        Navigator.pop(context);
                                        showSuccessToast(context: context, title: "Folder Deleted", description: "");
                                      },
                                      child: Text('Delete', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  width: MediaQuery.sizeOf(context).width * 0.25,
                  margin: EdgeInsets.only(right: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Symbols.folder,
                        size: MediaQuery.sizeOf(context).height * 0.045,
                      ),
                      Text(
                        currentFolder.noteFolderTitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w200,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class HomeScreenFolderListSkeletonizer extends StatelessWidget {
  const HomeScreenFolderListSkeletonizer({super.key});

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    return Skeletonizer(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.11,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 5,
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(15),
              ),
              width: MediaQuery.sizeOf(context).width * 0.25,
              margin: const EdgeInsets.only(right: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Symbols.folder,
                    size: MediaQuery.sizeOf(context).height * 0.045,
                  ),
                  Text(
                    'HomeWork',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w200,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
