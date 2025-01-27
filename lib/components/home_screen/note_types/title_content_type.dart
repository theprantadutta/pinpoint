import 'package:flutter/material.dart';

class TitleContentType extends StatelessWidget {
  static const kDefaultHeight = 150;
  const TitleContentType({super.key});

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.network(
              'https://images.pexels.com/photos/1629212/pexels-photo-1629212.jpeg',
              height: kDefaultHeight.toDouble(),
              width: double.infinity,
              cacheHeight: kDefaultHeight,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 10,
            ),
            child: Column(
              spacing: 5,
              children: [
                Text(
                  'Some Title',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Some Really Long Description about some title, I do not know what else to write here',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkTheme
                        ? Colors.grey.shade200
                        : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
