import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/services/dialog_service.dart';
import 'package:pinpoint/services/drift_note_service.dart';
import 'package:pinpoint/util/show_a_toast.dart';

class CreateNoteTagSelect extends StatefulWidget {
  final List<NoteTag> selectedTags;
  final Function(List<NoteTag> newTags) onSelectedTagsChanged;

  const CreateNoteTagSelect({
    super.key,
    required this.selectedTags,
    required this.onSelectedTagsChanged,
  });

  @override
  State<CreateNoteTagSelect> createState() => _CreateNoteTagSelectState();
}

class _CreateNoteTagSelectState extends State<CreateNoteTagSelect> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kPrimaryColor = theme.primaryColor;
    final isDarkTheme = theme.brightness == Brightness.dark;

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: kPrimaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tags',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDarkTheme ? Colors.white : Colors.black,
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    final controller = TextEditingController();
                    DialogService.addSomethingDialog(
                      context: context,
                      controller: controller,
                      title: 'Add Tag',
                      hintText: 'Enter tag name',
                      onAddPressed: () async {
                        final text = controller.text.trim();
                        if (text.isNotEmpty) {
                          final existingTags = await DriftNoteService.watchAllNoteTags().first;
                          if (existingTags.any((t) => t.tagTitle.toLowerCase() == text.toLowerCase())) {
                            if (!context.mounted) return;
                            showErrorToast(
                              context: context,
                              title: 'Tag already exists',
                              description: 'Please choose a unique name.',
                            );
                            return;
                          }
                          final newTag = await DriftNoteService.insertNoteTag(text);
                          widget.onSelectedTagsChanged([...widget.selectedTags, newTag]);
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                        }
                      },
                    );
                  },
                  child: Icon(Symbols.add),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [ 
                ...widget.selectedTags.map((tag) {
                  return Chip(
                    label: Text(tag.tagTitle),
                    onDeleted: () {
                      widget.onSelectedTagsChanged(
                        widget.selectedTags.where((t) => t.id != tag.id).toList(),
                      );
                    },
                    deleteIcon: Icon(Icons.close),
                    backgroundColor: kPrimaryColor.withValues(alpha: 0.2),
                    labelStyle: TextStyle(color: isDarkTheme ? Colors.white : Colors.black),
                  );
                }),
                ActionChip(
                  avatar: Icon(Icons.add),
                  label: Text('Select Existing'),
                  onPressed: () async {
                    final allTags = await DriftNoteService.watchAllNoteTags().first;
                    final availableTags = allTags.where((tag) => !widget.selectedTags.any((selected) => selected.id == tag.id)).toList();
                    if (!context.mounted) return;
                    showModalBottomSheet(
                      context: context,
                      builder: (context) {
                        return ListView.builder(
                          itemCount: availableTags.length,
                          itemBuilder: (context, index) {
                            final tag = availableTags[index];
                            return ListTile(
                              title: Text(tag.tagTitle),
                              onTap: () {
                                widget.onSelectedTagsChanged([...widget.selectedTags, tag]);
                                Navigator.pop(context);
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
