import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../elevations.dart';
import '../animations.dart';

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
  });

  @override
  State<GlassAppBar> createState() => _GlassAppBarState();

  @override
  Size get preferredSize => Size.fromHeight(expandedHeight ?? kToolbarHeight);
}

class _GlassAppBarState extends State<GlassAppBar> {
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(GlassAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_onScroll);
      widget.scrollController?.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (widget.scrollController != null) {
      setState(() {
        _scrollOffset = widget.scrollController!.offset;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glassSurface = theme.glassSurface;
    final motionSettings = MotionSettings.fromMediaQuery(context);

    // Calculate opacity based on scroll
    final opacity = (_scrollOffset / 100).clamp(0.0, 1.0);
    final blurIntensity = motionSettings.reduceMotion
        ? (widget.blurAmount ?? glassSurface.blurAmount)
        : ((widget.blurAmount ?? glassSurface.blurAmount) *
            (0.5 + opacity * 0.5));

    return AppBar(
      systemOverlayStyle: theme.brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      elevation: 0,
      backgroundColor: Colors.transparent,
      centerTitle: widget.centerTitle,
      leading: widget.leading,
      title: widget.title,
      actions: widget.actions,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blurIntensity,
            sigmaY: blurIntensity,
          ),
          child: AnimatedContainer(
            duration: motionSettings.getDuration(PinpointAnimations.fast),
            curve: motionSettings.getCurve(PinpointAnimations.standard),
            decoration: BoxDecoration(
              color: (widget.backgroundColor ?? glassSurface.overlayColor)
                  .withValues(alpha: glassSurface.opacity + (opacity * 0.1)),
              border: Border(
                bottom: BorderSide(
                  color: glassSurface.borderColor.withValues(alpha: opacity),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
      ),
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
    final motionSettings = MotionSettings.fromMediaQuery(context);

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
    final theme = Theme.of(context);
    final glassSurface = theme.glassSurface;
    final motionSettings = MotionSettings.fromMediaQuery(context);

    final effectiveBlur = motionSettings.reduceMotion
        ? 0.0
        : (blurAmount ?? glassSurface.blurAmount);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius ?? 14),
        boxShadow: PinpointElevations.md(theme.brightness),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius ?? 14),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: effectiveBlur,
            sigmaY: effectiveBlur,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor ??
                  glassSurface.overlayColor.withValues(alpha: glassSurface.opacity,),
              border: border ??
                  Border.all(
                    color: glassSurface.borderColor,
                    width: 1,
                  ),
              borderRadius: BorderRadius.circular(borderRadius ?? 14),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
