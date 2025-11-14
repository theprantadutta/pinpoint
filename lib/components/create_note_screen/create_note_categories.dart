import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../constants/constants.dart';

class CreateNoteCategories extends StatelessWidget {
  final String selectedType;
  final Function(String text) onSelectedTypeChanged;

  const CreateNoteCategories({
    super.key,
    required this.selectedType,
    required this.onSelectedTypeChanged,
  });

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: kNoteTypes.asMap().entries.map((entry) {
              final index = entry.key;
              final noteType = entry.value;
              final isSelected = noteType == selectedType;

              return Padding(
                padding: EdgeInsets.only(right: index == kNoteTypes.length - 1 ? 0 : 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelectedTypeChanged(noteType),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cs.primary.withValues(alpha: 0.1)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? cs.primary.withValues(alpha: 0.2)
                            : cs.outline.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getIconForNoteType(noteType),
                          color: isSelected ? cs.primary : cs.onSurface.withValues(alpha: 0.7),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          noteType,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? cs.primary : cs.onSurface,
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
