import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';

import '../../constants/hero_tags.dart';
import '../../constants/selectors.dart';
import '../../screens/create_note_screen.dart';
import 'awesome_bottom_bar/top_level_page_view.dart';
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

class _BottomNavigationLayoutState extends State<BottomNavigationLayout> {
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
    pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _handlePageViewChanged(int currentPageIndex) {
    setState(() {
      selectedIndex = currentPageIndex;
    });
  }

  gotoPage(int index) {
    if (index < kTopLevelPages.length && index >= 0) {
      _updateCurrentPageIndex(index);
      // _handleIconPress(index);
    }
  }

  gotoNextPage() {
    if (selectedIndex != kTopLevelPages.length - 1) {
      _updateCurrentPageIndex(selectedIndex + 1);
      // _handleIconPress(selectedIndex + 1);
    }
  }

  gotoPreviousPage() {
    if (selectedIndex != 0) {
      _updateCurrentPageIndex(selectedIndex - 1);
      // _handleIconPress(selectedIndex - 1);
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
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () =>
                    // Exit the app
                    SystemChannels.platform.invokeMethod('SystemNavigator.pop'),
                // FlutterExitApp.exitApp(),
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
    return BackButtonListener(
      onBackButtonPressed: _onBackButtonPressed,
      child: Scaffold(
        extendBodyBehindAppBar: false,
        resizeToAvoidBottomInset: false,
        body: AnnotatedRegion(
          value: getDefaultSystemUiStyle(isDarkTheme),
          child: Container(
            decoration: getBackgroundDecoration(kPrimaryColor),
            child: TopLevelPageView(
              pageController: pageController,
              onPageChanged: _handlePageViewChanged,
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
        ),
        bottomNavigationBar: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.085,
          child: StylishBottomBar(
            backgroundColor:
                isDarkTheme ? Colors.grey.shade900 : Colors.grey.shade200,
            notchStyle: NotchStyle.circle,
            option: DotBarOptions(
              dotStyle: DotStyle.circle,
            ),
            items: [
              BottomBarItem(
                icon: const Icon(Icons.home),
                title: const Text('Home'),
                selectedColor: kPrimaryColor,
              ),
              BottomBarItem(
                icon: const Icon(Icons.notes_outlined),
                title: const Text('Notes'),
                selectedColor: kPrimaryColor,
              ),
              BottomBarItem(
                icon: const Icon(Icons.check_box_outlined),
                title: const Text('Todo'),
                selectedColor: kPrimaryColor,
              ),
              BottomBarItem(
                icon: const Icon(Icons.person_2_outlined),
                title: const Text('Account'),
                selectedColor: kPrimaryColor,
              ),
            ],
            fabLocation: StylishBarFabLocation.center,
            hasNotch: true,
            currentIndex: selectedIndex,
            onTap: _updateCurrentPageIndex,
          ),
        ),
      ),
    );
  }
}
