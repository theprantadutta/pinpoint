import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:pinpoint/screens/folder_screen.dart';
import 'package:pinpoint/services/dialog_service.dart';
import 'package:pinpoint/services/drift_note_folder_service.dart';
import 'package:pinpoint/services/premium_service.dart';
import 'package:pinpoint/widgets/premium_gate_dialog.dart';
import 'package:pinpoint/util/show_a_toast.dart';
import 'package:pinpoint/services/logger_service.dart';
import '../../database/database.dart';
import '../../design_system/design_system.dart';

class HomeScreenMyFolders extends StatelessWidget {
  const HomeScreenMyFolders({super.key});

  Future<void> _addFolderFlow(BuildContext context) async {
    // Check premium limits first
    final folders =
        await DriftNoteFolderService.watchAllNoteFoldersStream().first;
    final premiumService = PremiumService();

    if (!premiumService.canCreateFolder(folders.length)) {
      if (!context.mounted) return;
      PinpointHaptics.error();
      PremiumGateDialog.showFolderLimit(context);
      return;
    }

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
          if (!context.mounted) return;
          showErrorToast(
            context: context,
            title: 'Folder already exists',
            description: 'Please choose a unique name.',
          );
          return;
        }
        await DriftNoteFolderService.insertNoteFolder(text);
        if (!context.mounted) return;
        Navigator.of(context).pop();
        PinpointHaptics.success();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                  onTap: () {
                    PinpointHaptics.light();
                    _addFolderFlow(context);
                  },
                  child: GlassContainer(
                    padding: const EdgeInsets.all(8),
                    borderRadius: 12,
                    child: const Icon(Symbols.add, size: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Folder Rail
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
                    child: Text(
                      'Failed to load folders',
                      style: theme.textTheme.bodyMedium,
                    ),
                  );
                }
                final folders = snapshot.data ?? [];
                if (folders.isEmpty) {
                  return EmptyState(
                    icon: Icons.folder_open_rounded,
                    title: 'No folders yet',
                    message: 'Create one to organize your notes',
                  );
                }
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: folders.length,
                  itemBuilder: (context, idx) {
                    final f = folders[idx];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _FolderCard(
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
                            if (!context.mounted) return;
                            showErrorToast(
                              context: context,
                              title: 'Name already used',
                              description: 'Please choose a unique name.',
                            );
                            return;
                          }
                          await DriftNoteFolderService.renameFolder(
                              f.noteFolderId, text);
                          if (!context.mounted) return;
                          PinpointHaptics.success();
                          showSuccessToast(
                            context: context,
                            title: 'Folder renamed',
                            description: '"${f.noteFolderTitle}" → "$text"',
                          );
                        },
                        onDelete: () async {
                          if (!context.mounted) return;
                          final confirmed = await ConfirmSheet.show(
                            context: context,
                            title: 'Delete folder?',
                            message:
                                'Notes will remain, but their link to this folder will be removed.',
                            primaryLabel: 'Delete folder',
                            secondaryLabel: 'Cancel',
                            isDestructive: true,
                            icon: Icons.folder_delete_rounded,
                          );
                          if (confirmed == true) {
                            await DriftNoteFolderService.deleteFolder(
                                f.noteFolderId);
                            if (!context.mounted) return;
                            PinpointHaptics.success();
                            showSuccessToast(
                              context: context,
                              title: 'Folder deleted',
                              description: '"${f.noteFolderTitle}" removed',
                            );
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
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
    final noteGradients = theme.noteGradients;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        PinpointHaptics.medium();
        final encodedTitle = Uri.encodeComponent(title);
        GoRouter.of(context)
            .push('${FolderScreen.kRouteName}/$folderId/$encodedTitle');
      },
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          gradient: noteGradients.accentGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: PinpointElevations.md(theme.brightness),
        ),
        child: GlassContainer(
          padding: const EdgeInsets.all(12),
          borderRadius: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Symbols.folder,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                  const Spacer(),
                  // Overflow menu
                  GestureDetector(
                    onTap: () {
                      PinpointHaptics.light();
                      _showFolderActionsSheet(context);
                    },
                    child: GlassContainer(
                      padding: const EdgeInsets.all(6),
                      borderRadius: 10,
                      child: const Icon(Icons.more_vert, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.touch_app,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
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
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final controller = TextEditingController(text: title);
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
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
                title: Text(
                  'Delete',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
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
                if (!ctx.mounted) return;
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
