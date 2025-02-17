import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fquery/fquery.dart';

import '../../constants/fquery_keys.dart';
import '../../database/database.dart';
import '../../services/drift_note_folder_service.dart';

class CreateNoteFolderSelect extends HookWidget {
  final List<String> selectedFolders;
  final Function(List<String>) setSelectedFolders;

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
                  selectedFolders.isEmpty
                      ? 'Select Folder'
                      : selectedFolders.join(', '),
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
              Row(
                children: [
                  Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
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
    List<String> tempSelectedFolders = List.from(selectedFolders);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.5,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select Folders',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: noteFolderData.length,
                        itemBuilder: (context, i) {
                          final title = noteFolderData[i].title;
                          final isSelected =
                              tempSelectedFolders.contains(title);
                          return CheckboxListTile(
                            title: Text(title),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  tempSelectedFolders.add(title);
                                } else {
                                  tempSelectedFolders.remove(title);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.sizeOf(context).width,
                      child: ElevatedButton(
                        onPressed: () {
                          setSelectedFolders(List.from(tempSelectedFolders));
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
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
