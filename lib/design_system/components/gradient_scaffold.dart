import 'package:flutter/material.dart';

import '../colors.dart';

/// Legacy scaffold, kept for the screens not yet moved to [SketchScaffold].
///
/// Sketchbook has no gradients: this is now a paper-coloured [Scaffold].
/// [backgroundGradient] and [animateGradient] are accepted and ignored so old
/// call sites compile; delete this file once nothing imports it.
class GradientScaffold extends StatelessWidget {
  final Widget? body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final Color? backgroundColor;
  final Gradient? backgroundGradient;
  final bool animateGradient;
  final bool safeArea;
  final bool extendBodyBehindAppBar;
  final EdgeInsets? padding;

  const GradientScaffold({
    super.key,
    this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.drawer,
    this.backgroundColor,
    this.backgroundGradient,
    this.animateGradient = false,
    this.safeArea = true,
    this.extendBodyBehindAppBar = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Widget? content = body;
    if (content != null && padding != null) {
      content = Padding(padding: padding!, child: content);
    }
    if (content != null && safeArea) content = SafeArea(child: content);

    return Scaffold(
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      backgroundColor: backgroundColor ?? context.sketch.bg,
      appBar: appBar,
      body: content,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      drawer: drawer,
    );
  }
}
