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
    final kPrimaryColor = Theme.of(context).primaryColor;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final darkerColor =
        isDarkTheme ? Colors.grey.shade400 : Colors.grey.shade600;
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.0),
        margin: EdgeInsets.symmetric(vertical: 5),
        height: MediaQuery.sizeOf(context).height * 0.045,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: kNoteTypes.length,
          itemBuilder: (context, index) {
            final noteType = kNoteTypes[index];
            final isSelected = noteType == selectedType;
            return GestureDetector(
              onTap: () => onSelectedTypeChanged(noteType),
              child: Container(
                margin: EdgeInsets.only(
                  left: index == 0 ? 0 : 5,
                  right: index == kNoteTypes.length - 1 ? 5 : 0,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? kPrimaryColor.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: isSelected
                      ? null
                      : Border.all(
                          color: kPrimaryColor.withValues(alpha: 0.2),
                        ),
                ),
                child: Center(
                  child: Text(
                    noteType,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? kPrimaryColor : darkerColor,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
