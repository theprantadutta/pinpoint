import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:pinpoint/screens/folder_screen.dart';
import 'package:pinpoint/services/dialog_service.dart';
import 'package:pinpoint/services/drift_note_folder_service.dart';
import 'package:pinpoint/util/show_a_toast.dart';
import 'package:pinpoint/services/logger_service.dart';

import '../../database/database.dart';
import '../../design/app_theme.dart';

class HomeScreenMyFolders extends StatelessWidget {
  const HomeScreenMyFolders({super.key});

  Future<void> _addFolderFlow(BuildContext context) async {
    final controller = TextEditingController();
    DialogService.addSomethingDialog(
      context: context,
      controller: controller,
      title: 'Add Folder',
      hintText: 'Enter folder name',
      onAddPressed: () async {
        final text = controller.text.trim();
        if (text.isEmpty) return;
        final folders =
            await DriftNoteFolderService.watchAllNoteFoldersStream().first;
        if (folders.any(
            (f) => f.noteFolderTitle.toLowerCase() == text.toLowerCase())) {
          showErrorToast(
            context: context,
            title: 'Folder already exists',
            description: 'Please choose a unique name.',
          );
          return;
        }
        await DriftNoteFolderService.insertNoteFolder(text);
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Builder(builder: (context) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My folders',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                Tooltip(
                  message: 'Create folder',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _addFolderFlow(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: dark
                            ? Colors.white.withOpacity(0.07)
                            : Colors.black.withOpacity(0.05),
                      ),
                      child: const Icon(Symbols.add, size: 20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Legendary Folder Rail
            SizedBox(
              height: 120,
              child: StreamBuilder<List<NoteFolder>>(
                stream: DriftNoteFolderService.watchAllNoteFoldersStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    log.e('[folders] stream error', snapshot.error);
                    return Center(
                      child: Text('Failed to load folders',
                          style: theme.textTheme.bodyMedium),
                    );
                  }
                  final folders = snapshot.data ?? [];
                  if (folders.isEmpty) {
                    return Center(
                      child: Text(
                        'No folders yet — create one',
                        style: theme.textTheme.bodyMedium,
                      ),
                    );
                  }
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemBuilder: (context, idx) {
                      final f = folders[idx];
                      return _FolderCard(
                        folderId: f.noteFolderId,
                        title: f.noteFolderTitle,
                        countHint: 'Tap to view',
                        onRename: (newTitle) async {
                          final text = newTitle.trim();
                          if (text.isEmpty) return;
                          final all = await DriftNoteFolderService
                                  .watchAllNoteFoldersStream()
                              .first;
                          if (all.any((x) =>
                              x.noteFolderTitle.toLowerCase() ==
                                  text.toLowerCase() &&
                              x.noteFolderId != f.noteFolderId)) {
                            showErrorToast(
                              context: context,
                              title: 'Name already used',
                              description: 'Please choose a unique name.',
                            );
                            return;
                          }
                          await DriftNoteFolderService.renameFolder(
                              f.noteFolderId, text);
                          showSuccessToast(
                            context: context,
                            title: 'Folder renamed',
                            description: '"${f.noteFolderTitle}" → "$text"',
                          );
                        },
                        onDelete: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete folder?'),
                              content: const Text(
                                  'Notes will remain, but their link to this folder will be removed.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton.tonal(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Delete folder'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await DriftNoteFolderService.deleteFolder(
                                f.noteFolderId);
                            showSuccessToast(
                              context: context,
                              title: 'Folder deleted',
                              description: '"${f.noteFolderTitle}" removed',
                            );
                          }
                        },
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemCount: folders.length,
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _ActionDot extends StatelessWidget {
  final VoidCallback onTap;
  const _ActionDot({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: (dark ? Colors.white : Colors.black).withOpacity(0.10),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.22 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: const Icon(Icons.more_vert, size: 16),
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  final int folderId;
  final String title;
  final String countHint;
  final Future<void> Function(String newTitle)? onRename;
  final Future<void> Function()? onDelete;

  const _FolderCard({
    required this.folderId,
    required this.title,
    required this.countHint,
    this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: AppTheme.radiusL.resolve(TextDirection.ltr),
      onTap: () {
        final encodedTitle = Uri.encodeComponent(title);
        // Use existing FolderScreen route pattern: /folder/:folderId/:folderTitle
        GoRouter.of(context)
            .push('${FolderScreen.kRouteName}/$folderId/$encodedTitle');
      },
      child: Glass(
        padding: const EdgeInsets.all(0),
        borderRadius: AppTheme.radiusL,
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            borderRadius: AppTheme.radiusL,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0x337C3AED),
                Color(0x2210B981),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Symbols.folder,
                      color: theme.colorScheme.primary, size: 22),
                  const Spacer(),
                  // Overflow menu for actions
                  _ActionDot(
                    onTap: () => _showFolderActionsSheet(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.touch_app,
                      size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    countHint,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showFolderActionsSheet(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final controller = TextEditingController(text: title);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  height: 4,
                  width: 40,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2))),
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: const Text('Rename'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _showRenameDialog(context, controller);
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.delete_outline, color: theme.colorScheme.error),
                title: Text('Delete',
                    style: TextStyle(color: theme.colorScheme.error)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  if (onDelete != null) {
                    await onDelete!();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showRenameDialog(
      BuildContext context, TextEditingController controller) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Rename folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Folder name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final value = controller.text.trim();
                if (value.isEmpty) return;
                if (onRename != null) {
                  await onRename!(value);
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
