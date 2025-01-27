import 'package:flutter/material.dart';

class CreateNoteCategories extends StatelessWidget {
  const CreateNoteCategories({super.key});

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final darkerColor =
        isDarkTheme ? Colors.grey.shade400 : Colors.grey.shade600;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.045,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 10,
        itemBuilder: (context, index) {
          return Container(
            margin: EdgeInsets.symmetric(horizontal: index == 0 ? 0 : 5),
            padding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                'Record Audio',
                style: TextStyle(
                  fontSize: 13,
                  color: darkerColor,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
