import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:pinpoint/util/show_a_toast.dart';

import '../../database/database.dart';
import '../../dtos/note_folder_dto.dart';
import '../../services/dialog_service.dart';
import '../../services/drift_note_folder_service.dart';
import '../../design_system/design_system.dart';

class ShowNoteFolderBottomSheet extends StatefulWidget {
  final List<NoteFolderDto> selectedFolders;
  final Function(List<NoteFolderDto>) setSelectedFolders;
  final List<NoteFolder> noteFolderData;

  const ShowNoteFolderBottomSheet({
    super.key,
    required this.selectedFolders,
    required this.setSelectedFolders,
    required this.noteFolderData,
  });

  @override
  State<ShowNoteFolderBottomSheet> createState() =>
      _ShowNoteFolderBottomSheetState();
}

class _ShowNoteFolderBottomSheetState extends State<ShowNoteFolderBottomSheet> {
  List<NoteFolderDto> tempSelectedFolders = [];

  @override
  void initState() {
    tempSelectedFolders = List.from(widget.selectedFolders);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          height: 4,
          width: 40,
          decoration: BoxDecoration(
            color: cs.outline.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Row(
            children: [
              Icon(Symbols.folder, color: cs.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Select Folders',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  PinpointHaptics.light();
                  final TextEditingController controller =
                      TextEditingController();
                  if (mounted) {
                    DialogService.addSomethingDialog(
                      context: context,
                      controller: controller,
                      title: 'Add Folder',
                      hintText: 'Enter folder name',
                      onAddPressed: () async {
                        final text = controller.text.trim();
                        if (text.isNotEmpty) {
                          if (widget.noteFolderData.any((x) =>
                              x.noteFolderTitle.toLowerCase() ==
                              text.toLowerCase())) {
                            if (!mounted) return;
                            showErrorToast(
                              context: context,
                              title: 'Folder Already Exists',
                              description: 'Please choose a unique name',
                            );
                            return;
                          }

                          final noteFolder =
                              await DriftNoteFolderService.insertNoteFolder(
                                  text);

                          if (context.mounted) {
                            setState(() {
                              tempSelectedFolders.add(noteFolder);
                            });
                            Navigator.pop(context);
                            PinpointHaptics.success();
                          }
                        }
                      },
                    );
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cs.primary,
                        cs.primary.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Symbols.add, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'New',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Folders List
        Expanded(
          child: widget.noteFolderData.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Symbols.folder_off,
                        size: 64,
                        color: cs.onSurface.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No folders yet',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap "New" to create your first folder',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: widget.noteFolderData.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final currentFolder = widget.noteFolderData[i];
                    final title = currentFolder.noteFolderTitle;
                    final isSelected =
                        tempSelectedFolders.any((x) => x.title == title);

                    return GestureDetector(
                      onTap: () {
                        PinpointHaptics.light();
                        setState(() {
                          if (isSelected) {
                            tempSelectedFolders.removeWhere(
                              (x) => x.title == title,
                            );
                          } else {
                            tempSelectedFolders.add(
                              NoteFolderDto(
                                id: currentFolder.noteFolderId,
                                title: currentFolder.noteFolderTitle,
                              ),
                            );
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                                  colors: [
                                    cs.primary.withValues(alpha: 0.15),
                                    cs.primary.withValues(alpha: 0.08),
                                  ],
                                )
                              : null,
                          color: isSelected
                              ? null
                              : isDark
                                  ? cs.surface.withValues(alpha: 0.4)
                                  : cs.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? cs.primary.withValues(alpha: 0.4)
                                : cs.outline.withValues(alpha: 0.1),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: cs.primary.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Checkbox
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? cs.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected
                                      ? cs.primary
                                      : cs.outline.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? Icon(
                                      Symbols.check,
                                      size: 16,
                                      color: Colors.white,
                                      weight: 700,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            // Folder Icon
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? cs.primary.withValues(alpha: 0.2)
                                    : cs.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Symbols.folder,
                                color: cs.primary,
                                size: 20,
                                fill: isSelected ? 1.0 : 0.0,
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Title
                            Expanded(
                              child: Text(
                                title,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: isSelected ? cs.primary : cs.onSurface,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Confirm Button
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (tempSelectedFolders.isEmpty) {
                  if (!mounted) return;
                  PinpointHaptics.error();
                  showErrorToast(
                    context: context,
                    title: 'No Folder Selected',
                    description: 'Please select at least one folder',
                  );
                  return;
                }
                PinpointHaptics.medium();
                widget.setSelectedFolders(List.from(tempSelectedFolders));
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                shadowColor: cs.primary.withValues(alpha: 0.3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Symbols.check_circle, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Confirm Selection',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
