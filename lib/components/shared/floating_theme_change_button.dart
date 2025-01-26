import 'package:flutter/material.dart';

import '../../main.dart';

class FloatingThemeChangeButton extends StatelessWidget {
  const FloatingThemeChangeButton({super.key});

  @override
  Widget build(BuildContext context) {
    var isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final kPrimaryColor = Theme.of(context).primaryColor;
    void handleThemeToggle() {
      if (isDarkTheme) {
        MyApp.of(context).changeTheme(ThemeMode.light);
      } else {
        MyApp.of(context).changeTheme(ThemeMode.dark);
      }
    }

    return FloatingActionButton(
      onPressed: handleThemeToggle,
      backgroundColor: kPrimaryColor,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: Icon(
          isDarkTheme ? Icons.dark_mode : Icons.light_mode,
          key: Key(isDarkTheme
              .toString()), // Ensure Flutter animates between different keys
          color: Colors.white,
        ),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }
}
