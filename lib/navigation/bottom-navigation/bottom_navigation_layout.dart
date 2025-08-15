import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../constants/hero_tags.dart';
import '../../constants/selectors.dart';
import '../../screens/create_note_screen.dart';
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
    if (selectedIndex == 0) {
      // Exit the app
      debugPrint('Existing the app as we are on top level page');
      return await _onWillPop(context);
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
    final colorScheme = Theme.of(context).colorScheme;
    
    return BackButtonListener(
      onBackButtonPressed: _onBackButtonPressed,
      child: Scaffold(
        extendBodyBehindAppBar: false,
        resizeToAvoidBottomInset: false,
        body: AnnotatedRegion(
          value: getDefaultSystemUiStyle(isDarkTheme),
          child: Container(
            decoration: getBackgroundDecoration(kPrimaryColor),
            child: SafeArea(
              top: false, // We only want bottom safe area padding
              bottom: false, // Handle bottom padding manually
              child: Stack(
                children: [
                  PageView(
                    onPageChanged: _handlePageViewChanged,
                    controller: pageController,
                    padEnds: true,
                    children: kTopLevelPages,
                  ),
                ],
              ),
            ),
          ),
        ),
        extendBody: true,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: FloatingActionButton(
          heroTag: kAddNewNote,
          shape: const CircleBorder(),
          onPressed: () => context.push(
            CreateNoteScreen.kRouteName,
          ),
          backgroundColor: kPrimaryColor.withValues(alpha: 0.9),
          child: Icon(
            Icons.add,
            color: Colors.white,
          ),
          elevation: 10,
        ),
        bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 12.0), // Add margin for floating effect
        decoration: BoxDecoration(
          color: isDarkTheme 
              ? colorScheme.surface
              : colorScheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20), // More rounded corners
          boxShadow: [
            BoxShadow(
              color: isDarkTheme
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20), // Match the container's border radius
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            selectedItemColor: kPrimaryColor,
            unselectedItemColor: isDarkTheme
                ? Colors.grey.shade400
                : Colors.grey.shade600,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            iconSize: 24,
            type: BottomNavigationBarType.fixed,
            elevation: 0, // Remove default elevation since we're adding our own
            currentIndex: selectedIndex,
            onTap: _updateCurrentPageIndex,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.notes_outlined),
                activeIcon: Icon(Icons.notes),
                label: 'Notes',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.check_box_outline_blank),
                activeIcon: Icon(Icons.check_box),
                label: 'Todo',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Account',
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
