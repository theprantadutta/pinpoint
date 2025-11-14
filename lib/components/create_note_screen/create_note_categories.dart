import 'package:flutter/material.dart';

import '../../constants/constants.dart';

class CreateNoteCategories extends StatelessWidget {
  final String selectedType;
  final Function(String text) onSelectedTypeChanged;

  const CreateNoteCategories({
    super.key,
    required this.selectedType,
    required this.onSelectedTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
                child: GestureDetector(
                  onTap: () => onSelectedTypeChanged(noteType),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      noteType,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
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
