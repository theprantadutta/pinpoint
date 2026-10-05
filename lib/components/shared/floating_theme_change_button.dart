import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../services/theme_controller.dart';

/// Debug-only light/dark toggle: an inverse circle with the current mode's
/// icon, cross-fading on change.
class FloatingThemeChangeButton extends StatelessWidget {
  const FloatingThemeChangeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final isDarkTheme = s.isDark;

    void handleThemeToggle() {
      context
          .read<ThemeController>()
          .setMode(isDarkTheme ? ThemeMode.light : ThemeMode.dark);
    }

    return CircleIconButton(
      icon: null,
      size: 56,
      fill: s.inverse,
      semanticLabel: isDarkTheme ? 'Light mode' : 'Dark mode',
      onPressed: handleThemeToggle,
      child: AnimatedSwitcher(
        duration: SketchMotion.of(context, SketchMotion.base),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: Icon(
          isDarkTheme ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
          // Ensure Flutter animates between different keys
          key: ValueKey(isDarkTheme),
          color: s.onInverse,
        ),
      ),
    );
  }
}
