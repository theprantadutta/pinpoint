import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../../components/onboarding/whats_new_sheet.dart';
import '../../components/shared/notification_prompt.dart';
import '../../design_system/design_system.dart';
import '../../screens/settings_screen.dart';
import '../../services/walkthrough_service.dart';
import '../../walkthrough/walkthrough_keys.dart';
import '../app_shell_scope.dart';
import '../keep_drawer.dart';
import '../new_note.dart';

/// The app shell around the Home / Notes / Todos branches.
///
/// Under 840dp (phones, tablets in portrait) the floating Sketchbook dock
/// (Home, Notes, Create, Todos, Settings) and a modal drawer. Wider, the dock
/// gives way to the list | editor split; from 1200dp the drawer is pinned as
/// a sidebar with its own New note button.
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
  /// onboarding), the one-time notification ask, and then the walkthrough (whose service persists its own
  /// completion). A brand-new install records the current onboarding
  /// version as it finishes onboarding, so it only ever gets the walkthrough.
  Future<void> _runIntros() async {
    if (!mounted) return;
    await WhatsNewSheet.showIfNeeded(context);
    if (!mounted) return;
    await NotificationPrompt.showIfNeeded(context);
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
    // Close the drawer first, like any other modal. Checked before
    // canPop(): an open drawer is local history, so canPop() reports true.
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState!.closeDrawer();
      return true;
    }

    // Let pushed screens (editor, archive, etc.) handle their own back.
    if (Navigator.of(context).canPop()) return false;

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
    // Phones and small tablets (< 840dp, e.g. a tablet in portrait) get the
    // dock and a modal drawer. Wider screens switch to the list | editor
    // split, where a floating dock would sit on the editor's toolbar; the
    // sidebar is pinned only once there is room for it beside both panes.
    final width = MediaQuery.sizeOf(context).width;
    final showDock = width < 840;
    final pinnedDrawer = width >= 1200;
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

    final body = pinnedDrawer
        ? Row(
            children: [
              const KeepDrawer(permanent: true),
              Expanded(child: widget.navigationShell),
            ],
          )
        : Stack(
            children: [
              Positioned.fill(child: widget.navigationShell),
              if (showDock)
                PositionedDirectional(
                  start: 0,
                  end: 0,
                  bottom: SketchSpace.dockBottom +
                      MediaQuery.paddingOf(context).bottom,
                  child: Center(child: dock),
                ),
            ],
          );

    // PopScope rather than BackButtonListener: with predictive back
    // (enableOnBackInvokedCallback, Android 14+) the OS only routes a back
    // press to Flutter when a route declares it handles it. A listener alone
    // declared nothing, so back at the shell — even with the drawer open —
    // dropped the user out of the app. The drawer still closes first: the
    // Scaffold registers it as local history on this route.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBackButtonPressed();
      },
      child: AppShellScope(
        currentBranch: branch,
        goBranch: _goBranch,
        openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
        hasPermanentDrawer: pinnedDrawer,
        showsDock: showDock,
        child: Scaffold(
          key: _scaffoldKey,
          resizeToAvoidBottomInset: false,
          backgroundColor: context.sketch.bg,
          drawer: pinnedDrawer ? null : const KeepDrawer(),
          drawerEnableOpenDragGesture: !pinnedDrawer,
          body: body,
        ),
      ),
    );
  }
}
