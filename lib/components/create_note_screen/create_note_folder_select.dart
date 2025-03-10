import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fquery/fquery.dart';
import 'package:pinpoint/util/show_a_toast.dart';

import '../../constants/fquery_keys.dart';
import '../../database/database.dart';
import '../../dtos/note_folder_dto.dart';
import '../../services/dialog_service.dart';
import '../../services/drift_note_folder_service.dart';

class CreateNoteFolderSelect extends HookWidget {
  final List<NoteFolderDto> selectedFolders;
  final Function(List<NoteFolderDto>) setSelectedFolders;

  const CreateNoteFolderSelect({
    super.key,
    required this.selectedFolders,
    required this.setSelectedFolders,
  });

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    final noteFolders =
        useQuery([kNoteFoldersKey], DriftNoteFolderService.getAllNoteFolders);

    if (noteFolders.isLoading) {
      return _buildLoadingContainer(context, kPrimaryColor);
    }
    if (noteFolders.isError) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Text('Something Went Wrong'),
        ),
      );
    }
    final noteFolderData = noteFolders.data!;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final selectedFolderString = selectedFolders.map((x) => x.title).join(', ');
    return SliverToBoxAdapter(
      child: GestureDetector(
        onTap: () => _showFolderSelectionSheet(context, noteFolderData),
        child: Container(
          width: MediaQuery.sizeOf(context).width * 0.8,
          height: MediaQuery.sizeOf(context).height * 0.07,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: kPrimaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kPrimaryColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  // selectedFolders.isEmpty
                  //     ? 'Select Folder'
                  //     : selectedFolders.join(', '),
                  selectedFolderString,
                  style: TextStyle(
                    color: kPrimaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
              ),
              SizedBox(width: 10),
              Row(
                children: [
                  Text(
                    'Change Folder',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkTheme
                          ? Colors.grey.shade300
                          : Colors.grey.shade600,
                      fontWeight: FontWeight.w200,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingContainer(BuildContext context, Color kPrimaryColor) {
    return SliverToBoxAdapter(
      child: Container(
        width: MediaQuery.sizeOf(context).width * 0.8,
        height: MediaQuery.sizeOf(context).height * 0.07,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: kPrimaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const SizedBox(),
      ),
    );
  }

  void _showFolderSelectionSheet(
      BuildContext context, List<NoteFolder> noteFolderData) {
    List<NoteFolderDto> tempSelectedFolders = List.from(selectedFolders);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final kPrimaryColor = Theme.of(context).primaryColor;
        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.62,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Folders',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        GestureDetector(
                          onTap: () {
                            final TextEditingController controller =
                                TextEditingController();
                            DialogService.addSomethingDialog(
                              context: context,
                              controller: controller,
                              title: 'Add Folder',
                              hintText: 'Enter title',
                              onAddPressed: () async {
                                final text = controller.text;
                                if (text.isNotEmpty) {
                                  if (noteFolderData.any((x) =>
                                      x.title.toLowerCase() ==
                                      text.toLowerCase())) {
                                    showErrorToast(
                                      context: context,
                                      title: 'Please Provide Unique Name',
                                      description:
                                          'That folder name already exists',
                                    );
                                    return;
                                  }
                                  final noteFolder =
                                      await DriftNoteFolderService
                                          .insertNoteFolder(text);
                                  setState(() {
                                    tempSelectedFolders.add(noteFolder);
                                  });
                                  Navigator.pop(context);
                                }
                              },
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 5),
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
                        itemCount: noteFolderData.length,
                        separatorBuilder: (_, __) =>
                            SizedBox(height: 8), // Add spacing between items
                        itemBuilder: (context, i) {
                          final currentFolder = noteFolderData[i];
                          final title = currentFolder.title;
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
                                        id: currentFolder.id,
                                        title: currentFolder.title,
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
                          if (selectedFolders.isEmpty) {
                            showErrorToast(
                                context: context,
                                title: 'Please Select One',
                                description: '');
                            return;
                          }
                          setSelectedFolders(List.from(tempSelectedFolders));
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
            },
          ),
        );
      },
    );
  }
}
