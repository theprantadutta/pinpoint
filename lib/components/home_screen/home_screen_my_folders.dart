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
import '../../navigation/app_navigation.dart';
import '../../walkthrough/walkthrough_keys.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

class HomeScreenMyFolders extends StatelessWidget {
  const HomeScreenMyFolders({super.key});

  Future<void> _addFolderFlow(BuildContext context) async {
    // Check premium limits first
    final folders =
        await DriftNoteFolderService.watchAllNoteFoldersStream().first;
    final premiumService = PremiumService();

    if (!context.mounted) return;

    if (!premiumService.canCreateFolder(folders.length)) {
      PinpointHaptics.error();
      PremiumGateDialog.showFolderLimit(context);
      return;
    }

    final controller = TextEditingController();
    DialogService.addSomethingDialog(
      context: context,
      controller: controller,
      title: AppL10n.of(context).foldersAdd,
      hintText: AppL10n.of(context).foldersNameHint,
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
            title: AppL10n.of(context).foldersAlreadyExists,
            description: AppL10n.of(context).foldersChooseUniqueName,
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppL10n.of(context).foldersMyFolders,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      PinpointHaptics.light();
                      AppNavigation.router.push('/my-folders');
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(AppL10n.of(context).foldersViewAll),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: AppL10n.of(context).foldersCreate,
                    child: InkWell(
                      key: WalkthroughKeys.addFolderKey,
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        PinpointHaptics.light();
                        _addFolderFlow(context);
                      },
                      child: GlassContainer(
                        padding: const EdgeInsets.all(6),
                        borderRadius: 10,
                        child: const Icon(Symbols.add, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Compact Folder Chips
          SizedBox(
            height: 44,
            child: StreamBuilder<List<NoteFolder>>(
              stream: DriftNoteFolderService.watchAllNoteFoldersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator.adaptive());
                }
                if (snapshot.hasError) {
                  log.e('[folders] stream error', snapshot.error);
                  return Center(
                    child: Text(
                      AppL10n.of(context).foldersLoadFailed,
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                }
                final folders = snapshot.data ?? [];
                if (folders.isEmpty) {
                  return Center(
                    child: Text(
                      AppL10n.of(context).foldersNoneYet,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  );
                }
                // Show max 4 folders
                final displayFolders = folders.take(4).toList();
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: displayFolders.length,
                  itemBuilder: (context, idx) {
                    final f = displayFolders[idx];
                    return Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: _CompactFolderChip(
                        folderId: f.noteFolderId,
                        title: f.noteFolderTitle,
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
                              title: AppL10n.of(context).foldersNameUsed,
                              description: AppL10n.of(context).foldersChooseUniqueName,
                            );
                            return;
                          }
                          await DriftNoteFolderService.renameFolder(
                              f.noteFolderId, text);
                          if (!context.mounted) return;
                          PinpointHaptics.success();
                          showSuccessToast(
                            context: context,
                            title: AppL10n.of(context).foldersRenamed,
                            description: '"${f.noteFolderTitle}" → "$text"',
                          );
                        },
                        onDelete: () async {
                          if (!context.mounted) return;
                          final confirmed = await ConfirmSheet.show(
                            context: context,
                            title: AppL10n.of(context).foldersDeleteTitle,
                            message:
                                AppL10n.of(context).foldersDeleteBody,
                            primaryLabel: AppL10n.of(context).foldersDeleteConfirm,
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
                              title: AppL10n.of(context).foldersDeleted,
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

// Compact folder chip for home screen
class _CompactFolderChip extends StatelessWidget {
  final int folderId;
  final String title;
  final Future<void> Function(String newTitle)? onRename;
  final Future<void> Function()? onDelete;

  const _CompactFolderChip({
    required this.folderId,
    required this.title,
    this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        PinpointHaptics.light();
        final encodedTitle = Uri.encodeComponent(title);
        GoRouter.of(context)
            .push('${FolderScreen.kRouteName}/$folderId/$encodedTitle');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.folder,
              color: theme.colorScheme.primary,
              size: 18,
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
