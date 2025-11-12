import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../constants/selectors.dart';
import '../../screens/create_note_screen.dart';
import '../../design_system/design_system.dart';
import 'top_level_pages.dart';

class BottomNavigationLayout extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const BottomNavigationLayout({
    super.key,
    required this.navigationShell,
  });

  @override
  State<BottomNavigationLayout> createState() => _BottomNavigationLayoutState();

  // ignore: library_private_types_in_public_api
  static _BottomNavigationLayoutState of(BuildContext context) =>
      context.findAncestorStateOfType<_BottomNavigationLayoutState>()!;
}

class _BottomNavigationLayoutState extends State<BottomNavigationLayout>
    with TickerProviderStateMixin {
  int selectedIndex = 0;
  late PageController pageController;

  @override
  void initState() {
    super.initState();
    pageController = PageController(
      initialPage: selectedIndex,
    );
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  void _updateCurrentPageIndex(int index) {
    if (index == selectedIndex) return;

    setState(() {
      selectedIndex = index;
    });

    pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _handlePageViewChanged(int currentPageIndex) {
    setState(() {
      selectedIndex = currentPageIndex;
    });
  }

  void gotoPage(int index) {
    if (index < kTopLevelPages.length && index >= 0) {
      _updateCurrentPageIndex(index);
    }
  }

  void gotoNextPage() {
    if (selectedIndex != kTopLevelPages.length - 1) {
      _updateCurrentPageIndex(selectedIndex + 1);
    }
  }

  void gotoPreviousPage() {
    if (selectedIndex != 0) {
      _updateCurrentPageIndex(selectedIndex - 1);
    }
  }

  Future<bool> _onWillPop(BuildContext context) async {
    return (await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Are you sure?'),
            content: const Text('Do you want to exit the app?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () =>
                    // Exit the app
                    SystemChannels.platform.invokeMethod('SystemNavigator.pop'),
                child: const Text('Yes'),
              ),
            ],
          ),
        )) ??
        true;
  }

  Future<bool> _onBackButtonPressed() async {
    debugPrint('Back button Pressed');

    // Check if we can pop (i.e., there are screens pushed on top like CreateNoteScreen)
    if (Navigator.of(context).canPop()) {
      debugPrint('There are screens to pop, letting system handle it');
      return false; // Let the system handle the back press
    }

    if (selectedIndex == 0) {
      // Exit the app dialog
      debugPrint('At root of navigation, showing exit dialog');
      await _onWillPop(context);
      // Always return true because either:
      // - User clicked "Yes" and app exited (doesn't matter)
      // - User clicked "No" and we want to prevent back (return true = handled)
      return true;
    } else {
      // Go back
      debugPrint('Going back to previous page');
      gotoPreviousPage();
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final kPrimaryColor = Theme.of(context).primaryColor;
    // final colorScheme = Theme.of(context).colorScheme;

    return BackButtonListener(
      onBackButtonPressed: _onBackButtonPressed,
      child: Scaffold(
        extendBodyBehindAppBar: false,
        resizeToAvoidBottomInset: false,
        extendBody: true,
        body: AnnotatedRegion(
          value: getDefaultSystemUiStyle(isDarkTheme),
          child: Container(
            decoration: getBackgroundDecoration(kPrimaryColor),
            child: Stack(
              children: [
                PageView(
                  onPageChanged: _handlePageViewChanged,
                  controller: pageController,
                  padEnds: true,
                  children: kTopLevelPages,
                ),
                // Floating Navigation Bar
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 24,
                  child: Container(
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDarkTheme
                            ? [
                                const Color(0xFF1E293B), // Slate 800
                                const Color(0xFF0F172A), // Slate 900
                              ]
                            : [
                                const Color(0xFFF8FAFC), // Slate 50
                                const Color(0xFFE2E8F0), // Slate 200
                              ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDarkTheme ? 0.5 : 0.2),
                          blurRadius: 32,
                          offset: const Offset(0, 12),
                        ),
                        BoxShadow(
                          color: isDarkTheme
                              ? kPrimaryColor.withValues(alpha: 0.1)
                              : kPrimaryColor.withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isDarkTheme
                                  ? [
                                      Colors.white.withValues(alpha: 0.08),
                                      Colors.white.withValues(alpha: 0.03),
                                    ]
                                  : [
                                      Colors.white.withValues(alpha: 0.7),
                                      Colors.white.withValues(alpha: 0.5),
                                    ],
                            ),
                            border: Border.all(
                              color: isDarkTheme
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.white.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _NavBarItem(
                                icon: Symbols.home,
                                label: 'Home',
                                isSelected: selectedIndex == 0,
                                onTap: () {
                                  PinpointHaptics.light();
                                  _updateCurrentPageIndex(0);
                                },
                              ),
                              _NavBarItem(
                                icon: Symbols.sticky_note_2,
                                label: 'Notes',
                                isSelected: selectedIndex == 1,
                                onTap: () {
                                  PinpointHaptics.light();
                                  _updateCurrentPageIndex(1);
                                },
                              ),
                              // FAB in the middle - Large with gradient
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      PinpointColors.mint,
                                      PinpointColors.mint
                                          .withValues(alpha: 0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: PinpointColors.mint
                                          .withValues(alpha: 0.4),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      PinpointHaptics.medium();
                                      context.push(CreateNoteScreen.kRouteName);
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: const Center(
                                      child: Icon(
                                        Symbols.add,
                                        size: 36,
                                        color: Colors.white,
                                        weight: 700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              _NavBarItem(
                                icon: Symbols.task_alt,
                                label: 'Todo',
                                isSelected: selectedIndex == 2,
                                onTap: () {
                                  PinpointHaptics.light();
                                  _updateCurrentPageIndex(2);
                                },
                              ),
                              _NavBarItem(
                                icon: Symbols.settings,
                                label: 'Settings',
                                isSelected: selectedIndex == 3,
                                onTap: () {
                                  PinpointHaptics.light();
                                  _updateCurrentPageIndex(3);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              AnimatedScale(
                scale: isSelected ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: Icon(
                  icon,
                  size: 25,
                  color: isSelected
                      ? primaryColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fill: isSelected ? 1.0 : 0.0,
                  weight: isSelected ? 600 : 400,
                ),
              ),
              const SizedBox(height: 3),
              // Label
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                style: theme.textTheme.labelSmall!.copyWith(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? primaryColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  letterSpacing: 0.1,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
