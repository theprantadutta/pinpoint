import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../screens/home_screen.dart';
import '../../services/walkthrough_service.dart';

/// Top-level shell. The app moved from a bottom navigation bar to a Keep-style
/// navigation drawer (hosted by [HomeScreen]), so this is now a thin wrapper
/// that renders the home surface and owns root back-button behavior.
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
  @override
  void initState() {
    super.initState();

    // Trigger walkthrough check - service handles persistence via SharedPreferences.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        WalkthroughService().showWalkthroughIfNeeded(context);
      }
    });
  }

  Future<bool> _onBackButtonPressed() async {
    // Let pushed screens (editor, archive, etc.) handle their own back.
    if (Navigator.of(context).canPop()) {
      return false;
    }

    // At the root: confirm app exit.
    final shouldExit = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Are you sure?'),
            content: const Text('Do you want to exit the app?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldExit) {
      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    }
    return true; // handled (either exited or cancelled)
  }

  @override
  Widget build(BuildContext context) {
    return BackButtonListener(
      onBackButtonPressed: _onBackButtonPressed,
      child: const HomeScreen(),
    );
  }
}
