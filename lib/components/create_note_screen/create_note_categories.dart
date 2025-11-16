import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../constants/constants.dart';
import '../../constants/note_type_config.dart';

class CreateNoteCategories extends StatefulWidget {
  final String selectedType;
  final Function(String text) onSelectedTypeChanged;

  const CreateNoteCategories({
    super.key,
    required this.selectedType,
    required this.onSelectedTypeChanged,
  });

  @override
  State<CreateNoteCategories> createState() => _CreateNoteCategoriesState();
}

class _CreateNoteCategoriesState extends State<CreateNoteCategories> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    // Create keys for each note type
    for (var noteType in kNoteTypes) {
      _itemKeys[noteType] = GlobalKey();
    }

    // Scroll to selected item after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected();
    });
  }

  @override
  void didUpdateWidget(CreateNoteCategories oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedType != widget.selectedType) {
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    final selectedKey = _itemKeys[widget.selectedType];
    if (selectedKey?.currentContext != null) {
      Scrollable.ensureVisible(
        selectedKey!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5, // Center the item
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  IconData _getIconForNoteType(String noteType) {
    switch (noteType) {
      case 'Title Content':
        return Symbols.edit_note;
      case 'Record Audio':
        return Symbols.mic;
      case 'Todo List':
        return Symbols.check_box;
      case 'Reminder':
        return Symbols.alarm;
      default:
        return Symbols.note;
    }
  }

  NoteTypeConfig? _getNoteTypeConfig(String noteType) {
    switch (noteType) {
      case 'Title Content':
        return NoteTypeConfig.text;
      case 'Record Audio':
        return NoteTypeConfig.voice;
      case 'Todo List':
        return NoteTypeConfig.todo;
      case 'Reminder':
        return NoteTypeConfig.reminder;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: kNoteTypes.asMap().entries.map((entry) {
              final index = entry.key;
              final noteType = entry.value;
              final isSelected = noteType == widget.selectedType;

              // Get note type config for colors
              final noteTypeConfig = _getNoteTypeConfig(noteType);
              final chipColor = noteTypeConfig?.color ?? cs.primary;

              return Padding(
                key: _itemKeys[noteType],
                padding: EdgeInsets.only(
                    right: index == kNoteTypes.length - 1 ? 0 : 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => widget.onSelectedTypeChanged(noteType),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? chipColor.withValues(alpha: 0.08)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? chipColor.withValues(alpha: 0.15)
                            : cs.outline.withValues(alpha: 0.1),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getIconForNoteType(noteType),
                          color: isSelected
                              ? chipColor.withValues(alpha: 0.7)
                              : cs.onSurface.withValues(alpha: 0.7),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          noteType,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? chipColor.withValues(alpha: 0.8)
                                : cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
