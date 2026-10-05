import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../spacing.dart';
import '../theme.dart';
import '../typography.dart';
import 'sketch/circle_icon_button.dart';

/// GlassAppBar - Frosted toolbar with scroll-aware blur
///
/// Features:
/// - Glassmorphism effect with backdrop filter
/// - Scroll-aware opacity and blur
/// - Customizable title and actions
/// - Supports leading widget
/// - Respects reduce motion setting
class GlassAppBar extends StatefulWidget implements PreferredSizeWidget {
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final double elevation;
  final Color? backgroundColor;
  final double? blurAmount;
  final ScrollController? scrollController;
  final bool floating;
  final bool pinned;
  final bool snap;
  final double? expandedHeight;
  final PreferredSizeWidget? bottom;

  const GlassAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle = false,
    this.elevation = 0,
    this.backgroundColor,
    this.blurAmount,
    this.scrollController,
    this.floating = false,
    this.pinned = true,
    this.snap = false,
    this.expandedHeight,
    this.bottom,
  });

  @override
  State<GlassAppBar> createState() => _GlassAppBarState();

  @override
  Size get preferredSize => Size.fromHeight(
        (expandedHeight ?? kToolbarHeight) +
            (bottom?.preferredSize.height ?? 0.0),
      );
}

class _GlassAppBarState extends State<GlassAppBar> {
  ScrollNotificationObserverState? _scrollObserver;
  bool _scrolledUnder = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final observer = ScrollNotificationObserver.maybeOf(context);
    if (observer != _scrollObserver) {
      _scrollObserver?.removeListener(_handleScrollNotification);
      _scrollObserver = observer;
      _scrollObserver?.addListener(_handleScrollNotification);
    }
  }

  @override
  void dispose() {
    _scrollObserver?.removeListener(_handleScrollNotification);
    _scrollObserver = null;
    super.dispose();
  }

  void _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification &&
        defaultScrollNotificationPredicate(notification)) {
      final scrolledUnder = notification.depth == 0 &&
          notification.metrics.axis == Axis.vertical &&
          notification.metrics.extentBefore > 0;
      if (scrolledUnder != _scrolledUnder) {
        setState(() => _scrolledUnder = scrolledUnder);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    // Sketchbook header: paper background, a circle back button, and a hairline
    // only once content scrolls under it.
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 60,
      leadingWidth: 64,
      backgroundColor: widget.backgroundColor ?? s.bg,
      surfaceTintColor: Colors.transparent,
      shape: _scrolledUnder
          ? Border(
              bottom:
                  BorderSide(color: s.hairline, width: SketchStroke.outline))
          : null,
      centerTitle: widget.centerTitle,
      automaticallyImplyLeading: false,
      leading: widget.leading ??
          (canPop
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(start: 18),
                  child: CircleIconButton.back(context),
                )
              : null),
      titleSpacing: canPop || widget.leading != null ? 4 : 20,
      title: widget.title == null
          ? null
          : DefaultTextStyle.merge(
              style: context.type.sheetTitle.copyWith(fontSize: 24),
              child: IconTheme.merge(
                  data: IconThemeData(color: s.ink), child: widget.title!),
            ),
      actions: [...?widget.actions, const SizedBox(width: 12)],
      bottom: widget.bottom,
    );
  }
}

/// SliverGlassAppBar - Sliver version with scroll effects
///
/// Use this in a CustomScrollView for advanced scroll behaviors
class SliverGlassAppBar extends StatelessWidget {
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool floating;
  final bool pinned;
  final bool snap;
  final double? expandedHeight;
  final Widget? flexibleSpace;
  final Color? backgroundColor;
  final double? blurAmount;

  const SliverGlassAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle = false,
    this.floating = false,
    this.pinned = true,
    this.snap = false,
    this.expandedHeight,
    this.flexibleSpace,
    this.backgroundColor,
    this.blurAmount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glassSurface = theme.glassSurface;
    // final motionSettings = MotionSettings.fromMediaQuery(context);

    return SliverAppBar(
      systemOverlayStyle: theme.brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      elevation: 0,
      backgroundColor: Colors.transparent,
      centerTitle: centerTitle,
      leading: leading,
      title: title,
      actions: actions,
      floating: floating,
      pinned: pinned,
      snap: snap,
      expandedHeight: expandedHeight,
      flexibleSpace: flexibleSpace != null
          ? FlexibleSpaceBar(
              background: flexibleSpace,
            )
          : null,
      forceElevated: true,
      surfaceTintColor: Colors.transparent,
      // Glass effect
      bottom: PreferredSize(
        preferredSize: Size.zero,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: glassSurface.borderColor.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass container for search bars and toolbars
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? borderRadius;
  final Color? backgroundColor;
  final double? blurAmount;
  final Border? border;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.backgroundColor,
    this.blurAmount,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    // No glass: an opaque surface with the standard outline.
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? s.surface,
        border: border ??
            Border.all(color: s.outline, width: SketchStroke.outline),
        borderRadius: BorderRadius.circular(borderRadius ?? SketchRadius.card),
      ),
      child: child,
    );
  }
}
