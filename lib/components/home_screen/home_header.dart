import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../navigation/app_shell_scope.dart';
import '../../services/connectivity_service.dart';
import '../../services/user_profile.dart';
import '../../sync/sync_manager.dart';
import '../../sync/sync_service.dart';
import '../../service_locators/init_service_locators.dart';
import '../../walkthrough/walkthrough_keys.dart';

/// The home header: brand sticker, "Pinpoint" and a greeting, and a search
/// button. In search mode the greeting row becomes an outlined search field.
///
/// The brand sticker opens the drawer (tap or long-press) and carries a small
/// sync-status dot: mint synced, yellow syncing, pink offline or failed.
class HomeHeader extends StatefulWidget {
  const HomeHeader({super.key, required this.onSearchChanged});

  final ValueChanged<String> onSearchChanged;

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
        const Duration(milliseconds: 280), () => widget.onSearchChanged(value));
  }

  void _openSearch() {
    setState(() => _searching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _closeSearch() {
    _debounce?.cancel();
    _controller.clear();
    widget.onSearchChanged('');
    _focus.unfocus();
    setState(() => _searching = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final t = context.type;
    final s = context.sketch;
    final shell = AppShellScope.maybeOf(context);
    final canOpenDrawer = !(shell?.hasPermanentDrawer ?? false);
    final profile = UserProfile.current();

    final sticker = _SyncDotSticker(
      onTap: canOpenDrawer ? shell?.openDrawer : null,
      label: l10n.a11yOpenMenu,
    );

    final Widget content = _searching
        ? Row(
            key: const ValueKey('search'),
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  style: t.bodyRegular,
                  decoration: InputDecoration(
                    hintText: l10n.homeSearchHint,
                    prefixIcon: Icon(Icons.search_rounded, color: s.ink),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(
                          color: s.outline, width: SketchStroke.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(
                          color: s.outline, width: SketchStroke.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(color: s.ink, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleIconButton(
                icon: Icons.close_rounded,
                semanticLabel: l10n.commonClose,
                onPressed: _closeSearch,
              ),
            ],
          )
        : Row(
            key: const ValueKey('greeting'),
            children: [
              sticker,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      header: true,
                      child: Text('Pinpoint', style: t.brand),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      profile.firstName == null
                          ? l10n.homeGreetingNoName
                          : l10n.homeGreeting(profile.firstName!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CircleIconButton(
                key: WalkthroughKeys.searchKey,
                icon: Icons.search_rounded,
                semanticLabel: l10n.commonSearch,
                onPressed: _openSearch,
              ),
            ],
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(SketchSpace.screenX,
          SketchSpace.headerTop, SketchSpace.screenX - 1, 0),
      child: AnimatedSwitcher(
        duration: SketchMotion.of(context, SketchMotion.base),
        switchInCurve: SketchMotion.enter,
        switchOutCurve: SketchMotion.exit,
        child: content,
      ),
    );
  }
}

/// The brand sticker with the sync-status dot.
class _SyncDotSticker extends StatelessWidget {
  const _SyncDotSticker({required this.onTap, required this.label});

  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final offline =
        context.select<ConnectivityService, bool>((c) => c.isOffline);
    final sync = getIt<SyncManager>();

    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final Color dot;
        if (offline || sync.status == SyncStatus.error) {
          dot = SketchPastels.pink;
        } else if (sync.isSyncing) {
          dot = SketchPastels.yellow;
        } else {
          dot = SketchPastels.mint;
        }
        return SketchPressable(
          onTap: onTap,
          onLongPress: onTap,
          semanticLabel: onTap == null ? null : label,
          child: SizedBox(
            width: SketchSpace.minTap,
            height: SketchSpace.minTap,
            child: Center(child: BrandSticker(statusDot: dot)),
          ),
        );
      },
    );
  }
}
