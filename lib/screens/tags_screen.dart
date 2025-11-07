import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/database/database.dart' as db;
import 'package:pinpoint/screens/notes_by_tag_screen.dart';
import 'package:pinpoint/services/drift_note_service.dart';
import 'package:pinpoint/util/dialogs.dart';
import '../design_system/design_system.dart';

class TagsScreen extends StatefulWidget {
  static const String kRouteName = '/tags';

  const TagsScreen({super.key});

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _showTagOptions(BuildContext context, db.NoteTag tag) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ConfirmSheet(
          title: tag.tagTitle,
          message: 'Choose an action',
          icon: Icons.label_rounded,
          onPrimary: () {
            Navigator.of(ctx).pop();
            _showEditTagDialog(context, tag);
          },
          primaryLabel: 'Edit',
          onSecondary: () {
            Navigator.of(ctx).pop();
            _showDeleteTagDialog(context, tag);
          },
          secondaryLabel: 'Delete',
          isDestructive: false,
        );
      },
    );
  }

  void _showEditTagDialog(BuildContext context, db.NoteTag tag) {
    showTextFormDialog(
      context,
      title: 'Edit Tag',
      hintText: 'Enter new tag name',
      initialValue: tag.tagTitle,
      onSave: (newTitle) async {
        if (newTitle.isNotEmpty && newTitle != tag.tagTitle) {
          await DriftNoteService.updateNoteTag(tag.id, newTitle);
          PinpointHaptics.success();
        }
      },
    );
  }

  Future<void> _showDeleteTagDialog(
      BuildContext context, db.NoteTag tag) async {
    final confirmed = await ConfirmSheet.show(
      context: context,
      title: 'Delete Tag',
      message:
          'Are you sure you want to delete "${tag.tagTitle}"? This will remove the tag from all associated notes.',
      primaryLabel: 'Delete',
      secondaryLabel: 'Cancel',
      isDestructive: true,
      icon: Icons.delete_rounded,
    );

    if (confirmed == true) {
      await DriftNoteService.deleteNoteTag(tag.id);
      PinpointHaptics.success();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GradientScaffold(
      appBar: GlassAppBar(
        scrollController: _scrollController,
        title: const Text('Tags'),
      ),
      body: StreamBuilder<List<db.NoteTag>>(
        stream: DriftNoteService.watchAllNoteTags(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Error loading tags',
              message: 'Please try again later',
            );
          }
          final tags = snapshot.data ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      'All Tags',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TagChip(
                      label: '${tags.length}',
                      color: cs.primary,
                      size: TagChipSize.small,
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: tags.isEmpty
                    ? EmptyState(
                        icon: Icons.label_outline_rounded,
                        title: 'No tags yet',
                        message:
                            'Tags will appear here when you add them to notes',
                      )
                    : SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: tags.map((tag) {
                            final tagColor = TagColors.getPreset(
                                tag.id % TagColors.presets.length);
                            return TagChip(
                              label: tag.tagTitle,
                              color: tagColor.foreground,
                              onTap: () {
                                PinpointHaptics.medium();
                                context.push(NotesByTagScreen.kRouteName,
                                    extra: tag);
                              },
                              showClose: true,
                              onClose: () {
                                PinpointHaptics.light();
                                _showTagOptions(context, tag);
                              },
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
