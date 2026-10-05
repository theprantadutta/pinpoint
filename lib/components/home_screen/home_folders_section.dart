import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../../design_system/design_system.dart';
import '../../models/folder_summary.dart';
import '../../navigation/keep_drawer.dart';
import '../../screens/my_folders_screen.dart';
import '../../services/drift_note_folder_service.dart';
import '../../walkthrough/walkthrough_keys.dart';
import '../shared/folder_actions.dart';

/// "My folders · View all", a row of folder chips, and a folder preview card
/// for the selected chip listing that folder's newest notes.
class HomeFoldersSection extends StatefulWidget {
  const HomeFoldersSection({super.key});

  @override
  State<HomeFoldersSection> createState() => _HomeFoldersSectionState();
}

class _HomeFoldersSectionState extends State<HomeFoldersSection> {
  /// The selected folder, by id so it survives reordering and new folders.
  int? _selectedId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return StreamBuilder<List<FolderSummary>>(
      stream: DriftNoteFolderService.watchFolderSummaries(),
      builder: (context, snap) {
        final folders = snap.data ?? const <FolderSummary>[];
        final selected = folders.isEmpty
            ? null
            : folders.firstWhere((f) => f.id == _selectedId,
                orElse: () => folders.first);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SketchSectionHeader(
              title: l10n.foldersMyFolders,
              action: SketchTextAction(
                key: WalkthroughKeys.addFolderKey,
                label: l10n.foldersViewAll,
                onTap: () => context.push(MyFoldersScreen.kRouteName),
              ),
            ),
            const SizedBox(height: SketchSpace.titleToContent - 6),
            if (!snap.hasData)
              const SizedBox(height: 36 + 14 + 164)
            else if (folders.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: SketchSpace.screenX),
                child: SketchDashedButton(
                  label: l10n.foldersCreate,
                  onTap: () => FolderActions.create(context),
                ),
              )
            else ...[
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: SketchSpace.screenX),
                  itemCount: folders.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: SketchSpace.chip),
                  itemBuilder: (context, i) {
                    final f = folders[i];
                    return Center(
                      child: SketchChip(
                        label: l10n.homeFolderChip(f.title, f.noteCount),
                        selected: f.id == selected!.id,
                        onTap: () => setState(() => _selectedId = f.id),
                        onLongPress: () => openFolder(context, f.id, f.title),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: SketchSpace.screenX),
                child: _Preview(summary: selected!, all: folders),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.summary, required this.all});

  final FolderSummary summary;
  final List<FolderSummary> all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    // As in the mock: the folder's own pastel at the back, and the next
    // folder's in front, so the stack reads as more than one folder.
    final index = all.indexOf(summary);
    final next = all.length > 1 ? all[(index + 1) % all.length].color : null;
    final front = next != null && next != summary.color
        ? next
        : SketchPastels.roundRobin[
            (SketchPastels.roundRobin.indexOf(summary.color) + 1) %
                SketchPastels.roundRobin.length];

    return AnimatedSwitcher(
      duration: SketchMotion.of(context, SketchMotion.base),
      child: FolderPreviewCard(
        key: ValueKey(summary.id),
        title: summary.title,
        countLabel: l10n.folderNoteCount(summary.noteCount),
        backPastel: summary.color,
        frontPastel: front,
        emptyLabel: l10n.folderPreviewEmpty,
        entries: [
          for (final n in summary.recent)
            FolderPreviewEntry(
              title: n.title.isEmpty ? l10n.dsEmptyNote : n.title,
              color: n.color,
            ),
        ],
        onTap: () => openFolder(context, summary.id, summary.title),
      ),
    );
  }
}
