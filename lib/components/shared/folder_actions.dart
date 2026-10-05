import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../../design_system/design_system.dart';
import '../../services/dialog_service.dart';
import '../../services/drift_note_folder_service.dart';
import '../../services/premium_service.dart';
import '../../util/show_a_toast.dart';
import '../../widgets/premium_gate_dialog.dart';

/// Folder creation, shared by the home screen, the drawer and My folders.
///
/// Checks the free-tier folder cap first (and shows the premium gate when it
/// is hit), then asks for a name and rejects duplicates case-insensitively.
class FolderActions {
  FolderActions._();

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
      title: l10n.foldersAdd,
      hintText: l10n.foldersNameHint,
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
        if (!context.mounted) return;
        Navigator.of(context).pop();
        PinpointHaptics.success();
      },
    );
  }
}
