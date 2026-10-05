import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/util/show_a_toast.dart';

import '../../database/database.dart';
import '../../design_system/design_system.dart';
import '../../dtos/note_folder_dto.dart';
import '../../services/dialog_service.dart';
import '../../services/drift_note_folder_service.dart';
import '../../services/premium_service.dart';
import '../../util/folder_palette.dart';
import '../../widgets/premium_gate_dialog.dart';

/// The editor's folder picker: a Sketchbook sheet of pastel folder chips,
/// multi-select (a note can live in several folders), with a dashed
/// "New folder" chip and a Done pill.
///
/// The list is live, so a folder created here — or arriving from sync while
/// the sheet is open — appears without reopening it.
class ShowNoteFolderBottomSheet extends StatefulWidget {
  final List<NoteFolderDto> selectedFolders;
  final Function(List<NoteFolderDto>) setSelectedFolders;

  /// The folders known when the sheet opened; shown until the live list
  /// arrives.
  final List<NoteFolder> noteFolderData;

  const ShowNoteFolderBottomSheet({
    super.key,
    required this.selectedFolders,
    required this.setSelectedFolders,
    required this.noteFolderData,
  });

  /// Loads the folders and opens the picker.
  static Future<void> show(
    BuildContext context, {
    required List<NoteFolderDto> selected,
    required ValueChanged<List<NoteFolderDto>> onChanged,
  }) async {
    final folders = await DriftNoteFolderService.watchFolders().first;
    if (!context.mounted) return;
    await showSketchSheet<void>(
      context: context,
      builder: (_) => ShowNoteFolderBottomSheet(
        selectedFolders: selected,
        setSelectedFolders: onChanged,
        noteFolderData: folders,
      ),
    );
  }

  @override
  State<ShowNoteFolderBottomSheet> createState() =>
      _ShowNoteFolderBottomSheetState();
}

class _ShowNoteFolderBottomSheetState extends State<ShowNoteFolderBottomSheet> {
  late final List<NoteFolderDto> _selected = List.of(widget.selectedFolders);
  late final Stream<List<NoteFolder>> _folders =
      DriftNoteFolderService.watchFolders();

  bool _isSelected(NoteFolder f) => _selected
      .any((x) => x.id == f.noteFolderId || x.title == f.noteFolderTitle);

  void _toggle(NoteFolder f) {
    PinpointHaptics.light();
    setState(() {
      if (_isSelected(f)) {
        _selected.removeWhere(
            (x) => x.id == f.noteFolderId || x.title == f.noteFolderTitle);
      } else {
        _selected
            .add(NoteFolderDto(id: f.noteFolderId, title: f.noteFolderTitle));
      }
    });
  }

  Future<void> _createFolder(List<NoteFolder> existing) async {
    final l10n = AppL10n.of(context);
    // Same free-tier cap as everywhere else folders are created.
    if (!PremiumService().canCreateFolder(existing.length)) {
      PinpointHaptics.error();
      await PremiumGateDialog.showFolderLimit(context);
      return;
    }
    if (!mounted) return;

    PinpointHaptics.light();
    final controller = TextEditingController();
    DialogService.addSomethingDialog(
      context: context,
      controller: controller,
      title: l10n.foldersAdd,
      hintText: l10n.foldersNameHint,
      onAddPressed: () async {
        final text = controller.text.trim();
        if (text.isEmpty) return;

        // The database has the final say on duplicates: the list this sheet
        // holds can be stale (a folder may have arrived from sync).
        final NoteFolderDto folder;
        try {
          folder = await DriftNoteFolderService.insertNoteFolder(text);
        } on FolderTitleTakenException {
          if (!mounted) return;
          showErrorToast(
            context: context,
            title: l10n.foldersAlreadyExists,
            description: l10n.foldersChooseUniqueName,
          );
          return;
        }

        if (!mounted) return;
        setState(() => _selected.add(folder));
        Navigator.pop(context);
        PinpointHaptics.success();
      },
    );
  }

  void _confirm() {
    final l10n = AppL10n.of(context);
    if (_selected.isEmpty) {
      PinpointHaptics.error();
      showErrorToast(
        context: context,
        title: l10n.folderNoneSelected,
        description: l10n.folderSelectAtLeastOne,
      );
      return;
    }
    PinpointHaptics.medium();
    widget.setSelectedFolders(List.of(_selected));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = context.sketch;
    final t = context.type;

    return StreamBuilder<List<NoteFolder>>(
      stream: _folders,
      initialData: widget.noteFolderData,
      builder: (context, snapshot) {
        final folders = snapshot.data ?? const <NoteFolder>[];
        final colors = FolderPalette.resolve(folders);
        final ordered = FolderPalette.ordered(folders);

        return SketchSheet(
          title: l10n.folderSelectTitle,
          footer: PillButton(label: l10n.commonDone, onPressed: _confirm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.edFoldersSheetHint,
                  style: t.bodySmall.copyWith(color: s.muted)),
              const SizedBox(height: 16),
              Wrap(
                spacing: SketchSpace.chip,
                runSpacing: SketchSpace.chip,
                children: [
                  for (final f in ordered)
                    _FolderChip(
                      title: f.noteFolderTitle,
                      pastel: colors[f.noteFolderId] ?? s.highlight,
                      selected: _isSelected(f),
                      onTap: () => _toggle(f),
                    ),
                  _NewFolderChip(
                    label: l10n.edNewFolder,
                    onTap: () => _createFolder(folders),
                  ),
                ],
              ),
              if (folders.isEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.folderTapNewHint,
                    style: t.bodySmall.copyWith(color: s.muted)),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A folder chip: unselected shows a 12px pastel square in an outline
/// stadium; selected fills with the folder's pastel and a check.
class _FolderChip extends StatelessWidget {
  const _FolderChip({
    required this.title,
    required this.pastel,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final Color pastel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SketchChip(
      label: title,
      selected: selected,
      pastel: pastel,
      onTap: onTap,
      padding: SketchChip.filterPadding,
      leading:
          selected ? null : PastelSquare(color: pastel, size: 12, radius: 3),
    );
  }
}

class _NewFolderChip extends StatelessWidget {
  const _NewFolderChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    return SketchPressable(
      onTap: onTap,
      semanticLabel: label,
      child: CustomPaint(
        foregroundPainter: DashedRRectPainter(
          color: s.outline,
          strokeWidth: SketchStroke.outline,
          radius: 19,
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 38),
          padding: SketchChip.filterPadding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 16, color: s.ink),
              const SizedBox(width: 4),
              ExcludeSemantics(
                child: Text(label, style: context.type.chip),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
