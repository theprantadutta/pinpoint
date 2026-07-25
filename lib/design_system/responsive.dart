import 'package:flutter/widgets.dart';

import 'spacing.dart';

/// Pinpoint Design System - Responsive layout
///
/// A single source of truth for adapting the UI between phones and
/// tablets/iPads. Everything keys off Material 3's *window size classes*
/// (compact / medium / expanded), which is also how iPad Split View and Slide
/// Over report their available width — so the same logic handles Android
/// tablets, iPads, foldables, and phone landscape without special-casing any
/// device.
///
/// Prefer the [ResponsiveContext] extension getters (`context.isTablet`,
/// `context.screenEdge`, `context.noteGridColumns`, ...) in widgets. When you
/// need the size class of a *region* narrower than the whole window (e.g. the
/// detail pane of a two-pane layout), pass that region's width to
/// [Breakpoints.of] directly instead of reading it from `context`.

/// Material 3 window size classes, by available width.
enum WindowSizeClass {
  /// < 600dp — phones in portrait (and narrow Slide Over on iPad).
  compact,

  /// 600–839dp — small tablets/iPads in portrait, foldables, phone landscape.
  medium,

  /// >= 840dp — tablets/iPads in landscape, large iPads, desktop.
  expanded,
}

/// Width breakpoints and content-sizing constants for the app.
class Breakpoints {
  Breakpoints._();

  /// Width (dp) at/above which the layout leaves the compact (phone) class.
  static const double medium = 600;

  /// Width (dp) at/above which the layout is treated as expanded (large tablet).
  static const double expanded = 840;

  /// The largest a single column of reading/form content should grow to on
  /// wide screens (paywall, settings, auth, note editor body). Beyond this,
  /// content is centered with breathing room on either side rather than
  /// stretched edge-to-edge.
  static const double contentMaxWidth = 720;

  /// A tighter clamp for narrow, form-like content (dialogs, auth fields).
  static const double formMaxWidth = 480;

  /// Target width of a single note tile; used to derive a fluid column count
  /// for a given available width (see [columnsForWidth]).
  static const double noteTileTarget = 220;

  /// Classify an available [width] into a [WindowSizeClass].
  static WindowSizeClass of(double width) {
    if (width >= expanded) return WindowSizeClass.expanded;
    if (width >= medium) return WindowSizeClass.medium;
    return WindowSizeClass.compact;
  }

  /// A fluid note-grid column count for a given [width], clamped to
  /// [min]..[max]. Uses [noteTileTarget] so tiles keep a comfortable size as
  /// the window grows (including inside iPad Split View).
  static int columnsForWidth(
    double width, {
    int min = 2,
    int max = 4,
    double horizontalPadding = 0,
  }) {
    final usable = width - horizontalPadding;
    if (usable <= 0) return min;
    final count = (usable / noteTileTarget).floor();
    return count.clamp(min, max);
  }
}

/// Ergonomic responsive helpers on [BuildContext].
///
/// These read the *window* width via `MediaQuery.sizeOf`, which is the right
/// source for top-level layout decisions. For sub-regions, prefer a
/// `LayoutBuilder` + [Breakpoints].
extension ResponsiveContext on BuildContext {
  /// Current window width in logical pixels.
  double get windowWidth => MediaQuery.sizeOf(this).width;

  /// The window's size class.
  WindowSizeClass get windowSizeClass => Breakpoints.of(windowWidth);

  /// Phone-class layout (single column, drawer behind a hamburger).
  bool get isCompact => windowSizeClass == WindowSizeClass.compact;

  /// Small-tablet-class layout.
  bool get isMedium => windowSizeClass == WindowSizeClass.medium;

  /// Large-tablet/desktop-class layout.
  bool get isExpanded => windowSizeClass == WindowSizeClass.expanded;

  /// True for any tablet-class width (medium or expanded). The primary switch
  /// most widgets should use to opt into the wider layout.
  bool get isTablet => !isCompact;

  /// Screen-edge padding that grows on tablets (20 → 32dp).
  double get screenEdge =>
      isCompact ? PinpointSpacing.screenEdge : PinpointSpacing.screenEdgeLarge;

  /// Number of columns for the note masonry grid at this width.
  int get noteGridColumns => Breakpoints.columnsForWidth(windowWidth,
      horizontalPadding: screenEdge * 2);
}

/// Centers and width-clamps its [child] on wide screens so reading/form content
/// doesn't stretch edge-to-edge on tablets, while remaining full-width on
/// phones. Drop this around a screen's scrollable body.
///
/// On compact widths it is a passthrough (no constraint, no extra padding).
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.contentMaxWidth,
    this.padding = EdgeInsets.zero,
  });

  /// The content to center and clamp.
  final Widget child;

  /// Maximum content width on wide screens.
  final double maxWidth;

  /// Optional padding applied *inside* the clamp (e.g. horizontal gutters).
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final content = padding == EdgeInsets.zero
        ? child
        : Padding(padding: padding, child: child);

    // On phones, don't constrain — let content use the full width.
    if (context.isCompact) return content;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      ),
    );
  }
}
