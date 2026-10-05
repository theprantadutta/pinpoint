import 'package:flutter/widgets.dart';

/// What the app shell exposes to the screens inside it: which dock branch is
/// showing, how to switch branches, and how to open the drawer.
///
/// The drawer lives on the shell's Scaffold rather than on each screen, so a
/// screen asks this scope to open it instead of calling
/// `Scaffold.of(context)`, which would find the screen's own Scaffold.
class AppShellScope extends InheritedWidget {
  const AppShellScope({
    super.key,
    required this.currentBranch,
    required this.goBranch,
    required this.openDrawer,
    required this.hasPermanentDrawer,
    required super.child,
  });

  /// 0 Home, 1 Notes, 2 Todos.
  final int currentBranch;
  final void Function(int branch) goBranch;
  final VoidCallback openDrawer;

  /// True on tablets, where the drawer is pinned open as a sidebar.
  final bool hasPermanentDrawer;

  static AppShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppShellScope>();

  @override
  bool updateShouldNotify(AppShellScope old) =>
      currentBranch != old.currentBranch ||
      hasPermanentDrawer != old.hasPermanentDrawer;
}
