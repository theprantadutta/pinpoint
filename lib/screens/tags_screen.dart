import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/design/widgets/tag_chip.dart';
import 'package:pinpoint/screens/notes_by_tag_screen.dart';
import 'package:pinpoint/services/drift_note_service.dart';
import 'package:pinpoint/util/dialogs.dart';

class TagsScreen extends StatefulWidget {
  static const String kRouteName = '/tags';

  const TagsScreen({super.key});

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  void _showTagOptions(BuildContext context, NoteTag tag) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(tag.tagTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showEditTagDialog(context, tag);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showDeleteTagDialog(context, tag);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditTagDialog(BuildContext context, NoteTag tag) {
    showTextFormDialog(
      context,
      title: 'Edit Tag',
      hintText: 'Enter new tag name',
      initialValue: tag.tagTitle,
      onSave: (newTitle) async {
        if (newTitle.isNotEmpty && newTitle != tag.tagTitle) {
          await DriftNoteService.updateNoteTag(tag.id, newTitle);
        }
      },
    );
  }

  void _showDeleteTagDialog(BuildContext context, NoteTag tag) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Tag'),
          content: Text(
              'Are you sure you want to delete the "${tag.tagTitle}" tag? This will remove the tag from all associated notes.'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () async {
                await DriftNoteService.deleteNoteTag(tag.id);
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
      ),
      body: StreamBuilder<List<NoteTag>>(
        stream: DriftNoteService.watchAllNoteTags(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final tags = snapshot.data ?? [];
          if (tags.isEmpty) {
            return const Center(child: Text('No tags yet.'));
          }
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: tags.map((tag) {
                return GestureDetector(
                  onLongPress: () => _showTagOptions(context, tag),
                  child: TagChip(
                    label: tag.tagTitle,
                    onTap: () {
                      context.push(NotesByTagScreen.kRouteName, extra: tag);
                    },
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
