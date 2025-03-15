import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';

import '../screens/account_screen.dart';
import '../screens/create_note_screen.dart';
import '../screens/home_screen.dart';
import '../screens/notes_screen.dart';
import '../screens/todo_screen.dart';
import 'bottom-navigation/bottom_navigation_layout.dart';

class AppNavigation {
  AppNavigation._();

  static String initial = HomeScreen.kRouteName;

  // Private navigators
  static final rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorHome =
      GlobalKey<NavigatorState>(debugLabel: 'shellHome');
  static final _shellNavigatorFolder =
      GlobalKey<NavigatorState>(debugLabel: 'shellFolder');
  static final _shellNavigatorTodo =
      GlobalKey<NavigatorState>(debugLabel: 'shellTodo');
  static final _shellNavigatorAccount =
      GlobalKey<NavigatorState>(debugLabel: 'shellAccount');

  // GoRouter configuration
  static final GoRouter router = GoRouter(
    initialLocation: initial,
    debugLogDiagnostics: true,
    navigatorKey: rootNavigatorKey,
    routes: [
      // /// OnBoardingScreen
      // GoRoute(
      //   parentNavigatorKey: rootNavigatorKey,
      //   path: OnBoardingScreen.route,
      //   name: "OnBoarding",
      //   builder: (context, state) => OnBoardingScreen(
      //     key: state.pageKey,
      //   ),
      // ),

      // /// OnBoardingThemeScreen
      // GoRoute(
      //   parentNavigatorKey: rootNavigatorKey,
      //   path: OnboardingThemeScreen.route,
      //   name: "OnBoardingTheme",
      //   builder: (context, state) => OnboardingThemeScreen(
      //     key: state.pageKey,
      //   ),
      // ),

      /// MainWrapper
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return BottomNavigationLayout(
            navigationShell: navigationShell,
          );
        },
        branches: <StatefulShellBranch>[
          /// Branch Home
          StatefulShellBranch(
            navigatorKey: _shellNavigatorHome,
            routes: <RouteBase>[
              GoRoute(
                path: HomeScreen.kRouteName,
                name: "Home",
                pageBuilder: (context, state) => reusableTransitionPage(
                  state: state,
                  child: const HomeScreen(),
                ),
              ),
            ],
          ),

          StatefulShellBranch(
            navigatorKey: _shellNavigatorFolder,
            routes: <RouteBase>[
              GoRoute(
                path: NotesScreen.kRouteName,
                name: "Notes",
                pageBuilder: (context, state) => reusableTransitionPage(
                  state: state,
                  child: const NotesScreen(),
                ),
              ),
            ],
          ),

          StatefulShellBranch(
            navigatorKey: _shellNavigatorTodo,
            routes: <RouteBase>[
              GoRoute(
                path: TodoScreen.kRouteName,
                name: "Todo",
                pageBuilder: (context, state) => reusableTransitionPage(
                  state: state,
                  child: const TodoScreen(),
                ),
              ),
            ],
          ),

          StatefulShellBranch(
            navigatorKey: _shellNavigatorAccount,
            routes: <RouteBase>[
              GoRoute(
                path: AccountScreen.kRouteName,
                name: "Account",
                pageBuilder: (context, state) => reusableTransitionPage(
                  state: state,
                  child: const AccountScreen(),
                ),
              ),
            ],
          ),
        ],
      ),

      /// Create Note Screen
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: CreateNoteScreen.kRouteName,
        name: "Create Note",
        builder: (context, state) {
          // final noticeType = state.pathParameters["noticeId"] ?? kNoteTypes[0];
          // Retrieve the arguments from the state
          final args = state.extra as CreateNoteScreenArguments?;
          return CreateNoteScreen(
            key: state.pageKey,
            args: args,
          );
        },
      ),
    ],
  );

  static CustomTransitionPage<void> reusableTransitionPage({
    required state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      restorationId: state.pageKey.value,
      transitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }
}
