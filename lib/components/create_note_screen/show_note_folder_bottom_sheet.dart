import 'package:flutter/material.dart';

import 'package:pinpoint/util/show_a_toast.dart';

import '../../database/database.dart';
import '../../dtos/note_folder_dto.dart';
import '../../services/dialog_service.dart';
import '../../services/drift_note_folder_service.dart';

class ShowNoteFolderBottomSheet extends StatefulWidget {
  final List<NoteFolderDto> selectedFolders;
  final Function(List<NoteFolderDto>) setSelectedFolders;
  final List<NoteFolder> noteFolderData;

  const ShowNoteFolderBottomSheet({
    super.key,
    required this.selectedFolders,
    required this.setSelectedFolders,
    required this.noteFolderData,
  });

  @override
  State<ShowNoteFolderBottomSheet> createState() =>
      _ShowNoteFolderBottomSheetState();
}

class _ShowNoteFolderBottomSheetState extends State<ShowNoteFolderBottomSheet> {
  List<NoteFolderDto> tempSelectedFolders = [];

  @override
  void initState() {
    tempSelectedFolders = List.from(widget.selectedFolders);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Folders',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () {
                  final TextEditingController controller =
                      TextEditingController();
                  if (mounted) {
                        DialogService.addSomethingDialog(
                          context: context,
                          controller: controller,
                          title: 'Add Folder',
                          hintText: 'Enter title',
                          onAddPressed: () async {
                            final text = controller.text;
                            if (text.isNotEmpty) {
                              if (widget.noteFolderData.any((x) =>
                                  x.noteFolderTitle.toLowerCase() ==
                                  text.toLowerCase())) {
                                if (!mounted) return;
                                showErrorToast(
                                  context: context,
                                  title: 'Please Provide Unique Name',
                                  description:
                                      'That folder name already exists',
                                );
                                return;
                              }

                              final noteFolder =
                                  await DriftNoteFolderService.insertNoteFolder(
                                      text);

                              if (mounted) {
                                setState(() {
                                  tempSelectedFolders.add(noteFolder);
                                });
                                Navigator.pop(context);
                              }
                            }
                          },
                        );
                      }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text('Add'),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.symmetric(vertical: 10),
              itemCount: widget.noteFolderData.length,
              separatorBuilder: (_, __) =>
                  SizedBox(height: 8), // Add spacing between items
              itemBuilder: (context, i) {
                final currentFolder = widget.noteFolderData[i];
                final title = currentFolder.noteFolderTitle;
                final isSelected =
                    tempSelectedFolders.any((x) => x.title == title);
                final kPrimaryColor = Theme.of(context).primaryColor;
                return AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? kPrimaryColor.withValues(alpha: 0.05)
                        : isDarkTheme
                            ? Colors.grey.shade900
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? kPrimaryColor.withValues(alpha: 0.3)
                          : isDarkTheme
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.2),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CheckboxListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    title: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: isSelected ? kPrimaryColor : null,
                      ),
                    ),
                    value: isSelected,
                    activeColor: kPrimaryColor,
                    checkColor: Colors.white,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          tempSelectedFolders.add(
                            NoteFolderDto(
                              id: currentFolder.noteFolderId,
                              title: currentFolder.noteFolderTitle,
                            ),
                          );
                        } else {
                          tempSelectedFolders.removeWhere(
                            (x) => x.title == title,
                          );
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: MediaQuery.sizeOf(context).width,
            child: ElevatedButton(
              onPressed: () {
                if (tempSelectedFolders.isEmpty) {
                  if (!mounted) return;
                  showErrorToast(
                    context: context,
                    title: 'Please Select One',
                    description: '',
                  );
                  return;
                }
                widget.setSelectedFolders(List.from(tempSelectedFolders));
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 20,
                ),
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }
}
