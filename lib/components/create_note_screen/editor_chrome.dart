import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../../design_system/design_system.dart';
import '../../dtos/note_folder_dto.dart';
import '../../screens/encryption_settings_screen.dart';
import '../../services/zero_knowledge_service.dart';
import '../../util/localized_dates.dart';

/// The editor's top bar (padding 8/20, gap 10): back (or close, in the
/// tablet detail pane), the folder chip, then pin and "⋯" on the end side.
class EditorTopBar extends StatelessWidget {
  const EditorTopBar({
    super.key,
    required this.onBack,
    required this.folderChip,
    required this.menu,
    this.pin,
    this.embedded = false,
  });

  final VoidCallback onBack;
  final Widget folderChip;
  final Widget menu;

  /// The pin button; null hides it (checklists keep pin in the ⋯ menu).
  final Widget? pin;

  /// In the master–detail pane the leading button closes the pane.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(SketchSpace.screenX - 1,
          SketchSpace.headerTop, SketchSpace.screenX - 1, 0),
      child: Row(
        children: [
          embedded
              ? CircleIconButton.close(context, onPressed: onBack)
              : CircleIconButton.back(context, onPressed: onBack),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: folderChip,
            ),
          ),
          const SizedBox(width: 8),
          if (pin != null) ...[pin!, const SizedBox(width: 6)],
          menu,
        ],
      ),
    );
  }
}

/// The pin toggle: outlined, or filled yellow (ink pin) when pinned. Light
/// haptic on toggle.
class EditorPinButton extends StatelessWidget {
  const EditorPinButton({
    super.key,
    required this.pinned,
    required this.onPressed,
  });

  final bool pinned;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return CircleIconButton(
      icon: pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
      fill: pinned ? SketchPastels.yellow : null,
      semanticLabel: pinned ? l10n.edUnpin : l10n.edPin,
      selected: pinned,
      haptic: true,
      onPressed: onPressed,
    );
  }
}

/// The folder chip: an outline stadium (h36) with the folder's 12px pastel
/// square, its name (13/600) and ▾. Several folders read "Random +2".
class EditorFolderChip extends StatelessWidget {
  const EditorFolderChip({
    super.key,
    required this.folders,
    required this.colors,
    required this.onTap,
  });

  final List<NoteFolderDto> folders;

  /// Folder id → pastel ([FolderPalette.resolve]).
  final Map<int, Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = context.sketch;
    final t = context.type;

    final first = folders.isEmpty ? null : folders.first;
    final label = first == null
        ? l10n.edAddToFolder
        : folders.length == 1
            ? first.title
            : l10n.edFolderChipMore(first.title, folders.length - 1);
    final semantic = first == null
        ? l10n.edAddToFolder
        : l10n.edFolderChipSemantic(folders.map((f) => f.title).join(', '));
    final pastel = first == null ? null : colors[first.id];

    return SketchPressable(
      onTap: onTap,
      semanticLabel: semantic,
      child: SizedBox(
        height: SketchSpace.minTap,
        child: Center(
          widthFactor: 1,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: ShapeDecoration(
              shape: StadiumBorder(
                side: BorderSide(color: s.outline, width: SketchStroke.outline),
              ),
            ),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pastel != null)
                    PastelSquare(color: pastel, size: 12, radius: 3)
                  else
                    Icon(Icons.create_new_folder_outlined,
                        size: 16, color: s.ink),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.chip,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_drop_down_rounded, size: 18, color: s.ink),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 28/800 borderless title field.
class EditorTitleField extends StatelessWidget {
  const EditorTitleField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: null,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.sentences,
      onSubmitted: onSubmitted,
      style: t.pageTitle.copyWith(color: s.ink),
      decoration: InputDecoration(
        hintText: AppL10n.of(context).edTitleHint,
        hintStyle: t.pageTitle.copyWith(color: s.muted),
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

/// "Edited Oct 2, 2026 · ● Encrypted" (13 muted). Tapping "Encrypted"
/// explains the account's key mode honestly.
class EditorMetaRow extends StatelessWidget {
  const EditorMetaRow({
    super.key,
    this.editedAt,
    this.showEncrypted = true,
  });

  /// Null for a note that has not been saved yet.
  final DateTime? editedAt;

  /// Text and checklist notes only: reminders are readable by the server,
  /// and cloud voice recordings are not end-to-end encrypted.
  final bool showEncrypted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = context.sketch;
    final style = context.type.bodySmall
        .copyWith(color: s.muted, fontWeight: FontWeight.w400);

    final children = <Widget>[
      if (editedAt != null)
        Text(l10n.edEditedOn(LocalizedDates.mediumDate(context, editedAt!)),
            style: style),
      if (editedAt != null && showEncrypted)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(color: s.muted, shape: BoxShape.circle),
          ),
        ),
      if (showEncrypted)
        SketchPressable(
          onTap: () => showEncryptionInfoSheet(context),
          semanticLabel: l10n.edEncryptedSemantic,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: SketchSpace.minTap),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: SketchFunctional.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                ExcludeSemantics(child: Text(l10n.edEncrypted, style: style)),
              ],
            ),
          ),
        ),
    ];
    if (children.isEmpty) return const SizedBox(height: 8);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 30),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}

/// Explains how a note is protected, for the account's actual key mode.
///
/// Reads the locally cached mode (no network): Standard mode keeps a
/// recoverable copy of the key on the server, Maximum Privacy does not. The
/// exceptions (reminders, cloud voice) are always stated.
Future<void> showEncryptionInfoSheet(BuildContext context) async {
  final zk = await ZeroKnowledgeService.isZeroKnowledge();
  if (!context.mounted) return;
  await showSketchSheet<void>(
    context: context,
    builder: (ctx) {
      final l10n = AppL10n.of(ctx);
      final s = ctx.sketch;
      final t = ctx.type;
      return SketchSheet(
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StickerTile(
                  color: zk ? SketchPastels.mint : SketchPastels.sky,
                  size: 40,
                  angle: -6,
                  icon: Icons.lock_rounded,
                ),
                const SizedBox(width: 14),
                SketchTag(
                  label: zk ? l10n.encMaxPrivacy : l10n.encStandard,
                  pastel: zk ? SketchPastels.mint : SketchPastels.sky,
                  dense: false,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(l10n.edEncSheetTitle, style: t.emptyTitle),
            ),
          ],
        ),
        footer: PillButton.secondary(
          label: l10n.edEncManage,
          onPressed: () {
            Navigator.of(ctx).pop();
            context.push(EncryptionSettingsScreen.kRouteName);
          },
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(zk ? l10n.edEncZkBody : l10n.edEncStandardBody,
                style: t.bodyRegular.copyWith(fontSize: 14, color: s.ink)),
            const SizedBox(height: 12),
            Text(l10n.edEncExceptions,
                style: t.bodyRegular.copyWith(fontSize: 14, color: s.muted)),
          ],
        ),
      );
    },
  );
}

/// The note colour on the editor paper: a 6px pastel strip down the leading
/// edge, with an ink rule on its inner side (pastel elements always carry an
/// ink outline). Nothing when the note has no colour.
class NoteColorEdge extends StatelessWidget {
  const NoteColorEdge({super.key, required this.color});

  final Color? color;

  static const double width = 6;

  @override
  Widget build(BuildContext context) {
    final c = color;
    return AnimatedSwitcher(
      duration: SketchMotion.of(context, SketchMotion.base),
      child: c == null
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey(c),
              width: width + SketchStroke.pastel,
              decoration: BoxDecoration(
                color: c,
                border: const BorderDirectional(
                  end: BorderSide(
                      color: SketchPastels.onPastel,
                      width: SketchStroke.pastel),
                ),
              ),
            ),
    );
  }
}
