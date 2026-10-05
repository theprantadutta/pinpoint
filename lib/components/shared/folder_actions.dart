import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../../design_system/design_system.dart';
import '../../service_locators/init_service_locators.dart';
import '../../services/analytics/analytics_facade.dart';
import '../../services/dialog_service.dart';
import '../../services/drift_note_folder_service.dart';
import '../../services/premium_service.dart';
import '../../util/show_a_toast.dart';
import '../../widgets/premium_gate_dialog.dart';

/// Folder actions shared by the home screen, the drawer and My folders:
/// create (premium-gated), rename, change colour and delete.
class FolderActions {
  FolderActions._();

  /// Checks the free-tier folder cap first (and shows the premium gate when
  /// it is hit), then asks for a name. Duplicates are rejected
  /// case-insensitively by [DriftNoteFolderService.insertNoteFolder].
  static Future<void> create(BuildContext context) async {
    final folders = await DriftNoteFolderService.watchFolders().first;
    if (!context.mounted) return;

    if (!PremiumService().canCreateFolder(folders.length)) {
      PinpointHaptics.error();
      PremiumGateDialog.showFolderLimit(context);
      return;
    }

    final l10n = AppL10n.of(context);
    final controller = TextEditingController();
    DialogService.addSomethingDialog(
      context: context,
      controller: controller,
      title: l10n.flNewFolder,
      hintText: l10n.foldersNameHint,
      icon: Icons.create_new_folder_outlined,
      primaryLabel: l10n.dgCreate,
      onAddPressed: () async {
        final text = controller.text.trim();
        if (text.isEmpty) return;
        try {
          await DriftNoteFolderService.insertNoteFolder(text);
        } on FolderTitleTakenException {
          if (!context.mounted) return;
          showErrorToast(
            context: context,
            title: l10n.foldersAlreadyExists,
            description: l10n.foldersChooseUniqueName,
          );
          return;
        }
        getIt<AnalyticsFacade>().trackFolderCreated();
        if (!context.mounted) return;
        Navigator.of(context).pop();
        PinpointHaptics.success();
      },
    );
  }

  /// Asks for a new name; rejects a name another folder already uses.
  static Future<void> rename(
      BuildContext context, int folderId, String currentTitle) async {
    final l10n = AppL10n.of(context);
    final controller = TextEditingController(text: currentTitle);
    controller.selection =
        TextSelection(baseOffset: 0, extentOffset: currentTitle.length);
    DialogService.addSomethingDialog(
      context: context,
      controller: controller,
      title: l10n.foldersRenameTitle,
      hintText: l10n.foldersNameFieldHint,
      icon: Icons.drive_file_rename_outline_rounded,
      primaryLabel: l10n.commonSave,
      onAddPressed: () async {
        final text = controller.text.trim();
        if (text.isEmpty) return;
        if (text == currentTitle) {
          Navigator.of(context).pop();
          return;
        }
        try {
          await DriftNoteFolderService.renameFolder(folderId, text);
        } on FolderTitleTakenException {
          if (!context.mounted) return;
          showErrorToast(
            context: context,
            title: l10n.foldersNameUsed,
            description: l10n.foldersChooseUniqueName,
          );
          return;
        }
        getIt<AnalyticsFacade>().trackFolderRenamed();
        if (!context.mounted) return;
        Navigator.of(context).pop();
        PinpointHaptics.success();
        showSuccessToast(
          context: context,
          title: l10n.foldersRenamed,
          description: '“$currentTitle” → “$text”',
        );
      },
    );
  }

  /// The five-pastel picker. Resolves once the colour is saved.
  static Future<void> changeColour(
      BuildContext context, int folderId, Color current) async {
    final name = await showSketchSheet<String>(
      context: context,
      builder: (ctx) => FolderColourSheet(current: current),
    );
    if (name == null) return;
    PinpointHaptics.selection();
    await DriftNoteFolderService.setFolderColor(folderId, name);
  }

  /// Confirms, then deletes the folder. Its notes stay. Resolves to whether
  /// the folder was deleted.
  static Future<bool> delete(
      BuildContext context, int folderId, String title) async {
    final l10n = AppL10n.of(context);
    final confirmed = await ConfirmSheet.show(
      context: context,
      title: l10n.foldersDeleteTitle,
      message: l10n.foldersDeleteBody,
      primaryLabel: l10n.foldersDeleteConfirm,
      secondaryLabel: l10n.commonCancel,
      isDestructive: true,
      icon: Icons.folder_delete_rounded,
    );
    if (confirmed != true) return false;
    await DriftNoteFolderService.deleteFolder(folderId);
    getIt<AnalyticsFacade>().trackFolderDeleted();
    if (!context.mounted) return true;
    PinpointHaptics.success();
    showSuccessToast(
      context: context,
      title: l10n.foldersDeleted,
      description: l10n.flDeletedBody(title),
    );
    return true;
  }
}

/// The folder colour sheet: five pastel swatches; the current one carries a
/// check. Pops the chosen pastel's stable name.
class FolderColourSheet extends StatelessWidget {
  const FolderColourSheet({super.key, required this.current});

  final Color current;

  static String label(AppL10n l10n, String name) => switch (name) {
        'yellow' => l10n.flColorYellow,
        'lavender' => l10n.flColorLavender,
        'mint' => l10n.flColorMint,
        'sky' => l10n.flColorSky,
        _ => l10n.flColorPink,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return SketchSheet(
      title: l10n.flColourSheetTitle,
      scrollable: false,
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          for (var i = 0; i < SketchPastels.roundRobin.length; i++)
            _Swatch(
              color: SketchPastels.roundRobin[i],
              label: label(l10n, SketchPastels.names[i]),
              selected: SketchPastels.roundRobin[i] == current,
              onTap: () =>
                  Navigator.of(context).pop(SketchPastels.names[i]),
            ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    return SketchPressable(
      onTap: onTap,
      semanticLabel: label,
      selected: selected,
      child: Container(
        width: 52,
        height: 52,
        padding: const EdgeInsets.all(3),
        decoration: ShapeDecoration(
          shape: CircleBorder(
            side: selected
                ? BorderSide(color: s.outline, width: 2)
                : BorderSide.none,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
                color: SketchPastels.onPastel, width: SketchStroke.outline),
          ),
          child: selected
              ? const Icon(Icons.check_rounded,
                  size: 22, color: SketchPastels.onPastel)
              : null,
        ),
      ),
    );
  }
}
