import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../components/shared/floating_theme_change_button.dart';
import '../top_level_pages.dart';

class TopLevelPageView extends StatelessWidget {
  final PageController pageController;
  final Function(int) onPageChanged;

  const TopLevelPageView({
    super.key,
    required this.pageController,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          PageView(
            onPageChanged: onPageChanged,
            controller: pageController,
            padEnds: true,
            children: kTopLevelPages,
          ),
          // Todo: Undo this if felt necessary
          // const BackgroundDecoration(),
          if (!kReleaseMode)
            const Positioned(
              right: 10,
              bottom: 10,
              child: FloatingThemeChangeButton(),
            ),
        ],
      ),
    );
  }
}
