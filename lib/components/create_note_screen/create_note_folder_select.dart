import 'package:flutter/material.dart';

import '../../dtos/note_folder_dto.dart';
import '../../services/drift_note_folder_service.dart';
import 'show_note_folder_bottom_sheet.dart';

class CreateNoteFolderSelect extends StatelessWidget {
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
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final selectedFolderString = selectedFolders.map((x) => x.title).join(', ');
    return SliverToBoxAdapter(
      child: GestureDetector(
        onTap: () => _showFolderSelectionSheet(context),
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

  void _showFolderSelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.62,
          child: StreamBuilder(
            stream: DriftNoteFolderService.watchAllNoteFoldersStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Something Went Wrong'),
                );
              }
              final noteFolderData = snapshot.data!;
              return ShowNoteFolderBottomSheet(
                selectedFolders: selectedFolders,
                setSelectedFolders: setSelectedFolders,
                noteFolderData: noteFolderData,
              );
            },
          ),
        );
      },
    );
  }
}
