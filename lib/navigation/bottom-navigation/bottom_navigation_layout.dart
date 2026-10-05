import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../../components/onboarding/whats_new_sheet.dart';
import '../../design_system/design_system.dart';
import '../../screens/settings_screen.dart';
import '../../services/walkthrough_service.dart';
import '../../walkthrough/walkthrough_keys.dart';
import '../app_shell_scope.dart';
import '../keep_drawer.dart';
import '../new_note.dart';

/// The app shell around the Home / Notes / Todos branches.
///
/// Phones get the floating Sketchbook dock (Home, Notes, Create, Todos,
/// Settings) and a modal drawer. Tablets pin the drawer open as a sidebar —
/// which carries its own New note button — and drop the dock, since the
/// sidebar already holds every destination and a dock floating over a
/// two-pane editor would sit on top of the editor's own toolbar.
class BottomNavigationLayout extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const BottomNavigationLayout({
    super.key,
    required this.navigationShell,
  });

  @override
  State<BottomNavigationLayout> createState() => _BottomNavigationLayoutState();
}

class _BottomNavigationLayoutState extends State<BottomNavigationLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runIntros());
  }

  /// First-frame intros, strictly one after the other so they never stack:
  /// the one-time What's-new sheet (people upgrading from an older
  /// onboarding) and then the walkthrough (whose service persists its own
  /// completion). A brand-new install records the current onboarding
  /// version as it finishes onboarding, so it only ever gets the walkthrough.
  Future<void> _runIntros() async {
    if (!mounted) return;
    await WhatsNewSheet.showIfNeeded(context);
    if (!mounted) return;
    await WalkthroughService().showWalkthroughIfNeeded(context);
  }

  void _goBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      // Re-selecting the current tab returns it to its root.
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  Future<bool> _onBackButtonPressed() async {
    // Let pushed screens (editor, archive, etc.) handle their own back.
    if (Navigator.of(context).canPop()) return false;

    // Close the drawer first, like any other modal.
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState!.closeDrawer();
      return true;
    }

    // From another tab, back returns home before it offers to exit.
    if (widget.navigationShell.currentIndex != 0) {
      _goBranch(0);
      return true;
    }

    final l10n = AppL10n.of(context);
    final shouldExit = await showSketchConfirm(
      context: context,
      title: l10n.exitAreYouSure,
      message: l10n.exitConfirmBody,
      confirmLabel: l10n.commonYes,
      cancelLabel: l10n.commonNo,
      destructive: false,
    );
    if (shouldExit) {
      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final tablet = context.windowSizeClass != WindowSizeClass.compact;
    final branch = widget.navigationShell.currentIndex;

    final dock = SketchDock(
      currentIndex: branch,
      createLabel: l10n.dockNewNote,
      createKey: WalkthroughKeys.fabKey,
      onCreate: () => NewNote.open(context),
      onCreateLongPress: () => NewNote.showChooser(context),
      onSelect: (i) {
        if (i == 3) {
          context.push(SettingsScreen.kRouteName);
        } else {
          _goBranch(i);
        }
      },
      items: [
        SketchDockItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: l10n.navHome,
        ),
        SketchDockItem(
          icon: Icons.folder_outlined,
          activeIcon: Icons.folder_rounded,
          label: l10n.navNotes,
        ),
        SketchDockItem(
          icon: Icons.check_box_outlined,
          activeIcon: Icons.check_box_rounded,
          label: l10n.todosTitle,
        ),
        SketchDockItem(
          icon: Icons.person_outline_rounded,
          label: l10n.navSettings,
          targetKey: WalkthroughKeys.navSettingsKey,
        ),
      ],
    );

    final body = tablet
        ? Row(
            children: [
              const KeepDrawer(permanent: true),
              Expanded(child: widget.navigationShell),
            ],
          )
        : Stack(
            children: [
              Positioned.fill(child: widget.navigationShell),
              PositionedDirectional(
                start: 0,
                end: 0,
                bottom: SketchSpace.dockBottom +
                    MediaQuery.paddingOf(context).bottom,
                child: Center(child: dock),
              ),
            ],
          );

    return BackButtonListener(
      onBackButtonPressed: _onBackButtonPressed,
      child: AppShellScope(
        currentBranch: branch,
        goBranch: _goBranch,
        openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
        hasPermanentDrawer: tablet,
        child: Scaffold(
          key: _scaffoldKey,
          resizeToAvoidBottomInset: false,
          backgroundColor: context.sketch.bg,
          drawer: tablet ? null : const KeepDrawer(),
          drawerEnableOpenDragGesture: !tablet,
          body: body,
        ),
      ),
    );
  }
}
