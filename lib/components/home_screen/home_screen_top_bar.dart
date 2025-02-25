import 'package:drift_db_viewer/drift_db_viewer.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../database/database.dart';
import '../../service_locators/init_service_locators.dart';

class HomeScreenTopBar extends StatelessWidget {
  const HomeScreenTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8.0,
        horizontal: 10,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              final database = getIt<AppDatabase>();
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => DriftDbViewer(database)));
            },
            child: Icon(
              Symbols.menu,
            ),
          ),
          Text(
            'PinPoint',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.3,
              color: isDarkTheme ? Colors.grey.shade300 : Colors.grey.shade600,
            ),
          ),
          Icon(Symbols.more_vert),
        ],
      ),
    );
  }
}
