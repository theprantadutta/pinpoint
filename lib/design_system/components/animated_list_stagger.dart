import 'package:flutter/material.dart';
import '../animations.dart';

/// AnimatedListStagger - Wrapper for staggered list entrance animations
///
/// Features:
/// - Staggered fade and slide animations
/// - Configurable delay and duration
/// - Respects reduce motion
class AnimatedListStagger extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Duration? delay;
  final Duration? itemDelay;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsets? padding;
  final bool reverse;

  const AnimatedListStagger({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.delay,
    this.itemDelay,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
    this.reverse = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: padding,
      reverse: reverse,
      itemBuilder: (context, index) {
        return StaggeredListItem(
          index: index,
          delay: delay,
          itemDelay: itemDelay,
          child: itemBuilder(context, index),
        );
      },
    );
  }
}

/// StaggeredListItem - Individual item with entrance animation
class StaggeredListItem extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration? delay;
  final Duration? itemDelay;

  const StaggeredListItem({
    super.key,
    required this.index,
    required this.child,
    this.delay,
    this.itemDelay,
  });

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    final stagger = StaggerAnimation(
      delay: widget.delay ?? Duration.zero,
      itemDelay: widget.itemDelay ?? PinpointAnimations.staggerDelay,
      itemCount: widget.index + 1,
    );

    _animationController = AnimationController(
      vsync: this,
      duration: PinpointAnimations.itemEntrance.duration,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: PinpointAnimations.itemEntrance.curve,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: PinpointAnimations.itemEntrance.curve,
    ));

    // Start animation after delay
    Future.delayed(stagger.getDelay(widget.index), () {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motionSettings = MotionSettings.fromMediaQuery(context);

    // Skip animation if reduce motion is enabled
    if (motionSettings.reduceMotion) {
      return widget.child;
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

/// GridStagger - Staggered grid view with entrance animations
class AnimatedGridStagger extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final Duration? delay;
  final Duration? itemDelay;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsets? padding;

  const AnimatedGridStagger({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.crossAxisCount = 2,
    this.mainAxisSpacing = 8.0,
    this.crossAxisSpacing = 8.0,
    this.childAspectRatio = 1.0,
    this.delay,
    this.itemDelay,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: itemCount,
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) {
        return StaggeredListItem(
          index: index,
          delay: delay,
          itemDelay: itemDelay,
          child: itemBuilder(context, index),
        );
      },
    );
  }
}
