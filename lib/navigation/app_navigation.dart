import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/screens/archive_screen.dart';
import 'package:pinpoint/screens/folder_screen.dart';
import 'package:pinpoint/screens/sync_screen.dart';
import 'package:pinpoint/screens/theme_screen.dart';
import 'package:pinpoint/screens/trash_screen.dart';
import 'package:pinpoint/screens/splash_screen.dart';
import 'package:pinpoint/screens/onboarding_screen.dart';
import 'package:pinpoint/screens/subscription_screen_revcat.dart';
import 'package:pinpoint/screens/my_folders_screen.dart';
import 'package:pinpoint/screens/auth_screen.dart';
import 'package:pinpoint/screens/account_linking_screen.dart';

import '../screen_arguments/create_note_screen_arguments.dart';
import '../screens/account_screen.dart';
import '../screens/create_note_screen.dart';
import '../screens/home_screen.dart';
import '../screens/notes_screen.dart';
import '../screens/todo_screen.dart';
import 'bottom-navigation/bottom_navigation_layout.dart';

class AppNavigation {
  AppNavigation._();

  static String initial = SplashScreen.kRouteName;

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
      /// Splash Screen
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: SplashScreen.kRouteName,
        name: "Splash",
        builder: (context, state) => const SplashScreen(),
      ),

      /// Onboarding Screen
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: OnboardingScreen.kRouteName,
        name: "Onboarding",
        builder: (context, state) => const OnboardingScreen(),
      ),

      /// Authentication Screen
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AuthScreen.kRouteName,
        name: "Auth",
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const AuthScreen(),
        ),
      ),

      /// Account Linking Screen
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AccountLinkingScreen.kRouteName,
        name: "Account Linking",
        pageBuilder: (context, state) {
          final firebaseToken = state.extra as String;
          return NoTransitionPage(
            key: state.pageKey,
            child: AccountLinkingScreen(
              key: state.pageKey,
              firebaseToken: firebaseToken,
            ),
          );
        },
      ),

      /// Subscription Screen
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: SubscriptionScreenRevCat.kRouteName,
        name: "Subscription",
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const SubscriptionScreenRevCat(),
        ),
      ),

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
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '${FolderScreen.kRouteName}/:folderId/:folderTitle',
        name: "Folder Screen",
        pageBuilder: (context, state) {
          final folderId = int.parse(state.pathParameters['folderId']!);
          final folderTitle = state.pathParameters['folderTitle']!;
          return NoTransitionPage(
            key: state.pageKey,
            child: FolderScreen(
              key: state.pageKey,
              folderId: folderId,
              folderTitle: folderTitle,
            ),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: ArchiveScreen.kRouteName,
        name: "Archive Screen",
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: ArchiveScreen(
            key: state.pageKey,
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: TrashScreen.kRouteName,
        name: "Trash Screen",
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: TrashScreen(
            key: state.pageKey,
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: SyncScreen.kRouteName,
        name: "Sync Screen",
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: SyncScreen(
            key: state.pageKey,
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: ThemeScreen.kRouteName,
        name: "Theme Screen",
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: ThemeScreen(
            key: state.pageKey,
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: MyFoldersScreen.kRouteName,
        name: "My Folders Screen",
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: MyFoldersScreen(
            key: state.pageKey,
          ),
        ),
      ),
    ],
  );

  static CustomTransitionPage<void> reusableTransitionPage({
    required GoRouterState state,
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
