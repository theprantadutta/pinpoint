import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../constants/selectors.dart';
import '../shared/floating_theme_change_button.dart';

class MainLayout extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? bottom;
  final List<Widget> actions;

  const MainLayout({
    super.key,
    required this.body,
    this.bottom,
    this.actions = const [],
  });

  Future<bool> _onBackButtonPressed(BuildContext context) async {
    if (context.canPop()) context.pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final darkerColor =
        isDarkTheme ? Colors.grey.shade400 : Colors.grey.shade600;
    return BackButtonListener(
      onBackButtonPressed: () => _onBackButtonPressed(context),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: AnnotatedRegion(
          value: SystemUiOverlayStyle(
            // Status bar color
            statusBarColor: Colors.transparent,
            // statusBarColor: kPrimaryColor.withValues(alpha: 0.1),
            // Status bar brightness (optional)
            statusBarIconBrightness: isDarkTheme
                ? Brightness.light
                : Brightness.dark, // For Android (dark icons)
            statusBarBrightness: isDarkTheme
                ? Brightness.dark
                : Brightness.light, // For iOS (dark icons)
          ),
          child: Container(
            decoration: getBackgroundDecoration(kPrimaryColor),
            child: SafeArea(
              child: Column(
                children: [
                  Container(
                    height: MediaQuery.sizeOf(context).height * 0.06,
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    // decoration: BoxDecoration(
                    //   color: kPrimaryColor.withValues(alpha: 0.1),
                    // ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Row(
                            children: [
                              Icon(
                                Symbols.arrow_back_ios_new_sharp,
                                size: 13,
                                color: darkerColor,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Back',
                                style: TextStyle(
                                  color: darkerColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(children: actions),
                      ],
                    ),
                  ),
                  body,
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: kReleaseMode
            ? null // Don't show FloatingActionButton in release (production) mode
            : const FloatingThemeChangeButton(),
      ),
    );
  }
}
