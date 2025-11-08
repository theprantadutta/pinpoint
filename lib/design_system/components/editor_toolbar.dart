import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../animations.dart';

/// EditorToolbar - Floating toolbar for markdown/rich text controls
///
/// Features:
/// - Gradient background
/// - Scroll-aware collapse
/// - Markdown controls (bold, italic, code, etc.)
/// - Checklist and code block buttons
/// - Responsive to keyboard
class EditorToolbar extends StatefulWidget {
  final bool isVisible;
  final VoidCallback? onBold;
  final VoidCallback? onItalic;
  final VoidCallback? onCode;
  final VoidCallback? onCheckbox;
  final VoidCallback? onH1;
  final VoidCallback? onH2;
  final VoidCallback? onQuote;
  final VoidCallback? onLink;
  final VoidCallback? onImage;
  final ScrollController? scrollController;
  final bool floating;

  const EditorToolbar({
    super.key,
    this.isVisible = true,
    this.onBold,
    this.onItalic,
    this.onCode,
    this.onCheckbox,
    this.onH1,
    this.onH2,
    this.onQuote,
    this.onLink,
    this.onImage,
    this.scrollController,
    this.floating = true,
  });

  @override
  State<EditorToolbar> createState() => _EditorToolbarState();
}

class _EditorToolbarState extends State<EditorToolbar> {
  bool _isCollapsed = false;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(EditorToolbar oldWidget) {
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
      final offset = widget.scrollController!.offset;
      setState(() {
        _scrollOffset = offset;
        // Collapse when scrolling down past threshold
        _isCollapsed = offset > 100;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolbarStyle = theme.toolbarStyle;
    final motionSettings = MotionSettings.fromMediaQuery(context);

    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    final toolbar = ClipRRect(
      borderRadius: toolbarStyle.borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: toolbarStyle.padding,
          decoration: BoxDecoration(
            gradient: toolbarStyle.backgroundGradient,
            color: toolbarStyle.backgroundColor.withValues(alpha: 0.8),
            borderRadius: toolbarStyle.borderRadius,
            boxShadow: toolbarStyle.elevation,
          ),
          child: AnimatedSize(
            duration: motionSettings.getDuration(PinpointAnimations.normal),
            curve: motionSettings.getCurve(PinpointAnimations.emphasized),
            child: _isCollapsed
                ? _buildCollapsedToolbar(theme, toolbarStyle)
                : _buildFullToolbar(theme, toolbarStyle),
          ),
        ),
      ),
    );

    if (widget.floating) {
      return Positioned(
        bottom: 24,
        left: 16,
        right: 16,
        child: toolbar,
      );
    }

    return toolbar;
  }

  Widget _buildFullToolbar(ThemeData theme, ToolbarStyle toolbarStyle) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        // Text formatting
        if (widget.onBold != null)
          _ToolbarButton(
            icon: Icons.format_bold_rounded,
            label: 'Bold',
            onTap: widget.onBold!,
            toolbarStyle: toolbarStyle,
          ),
        if (widget.onItalic != null)
          _ToolbarButton(
            icon: Icons.format_italic_rounded,
            label: 'Italic',
            onTap: widget.onItalic!,
            toolbarStyle: toolbarStyle,
          ),
        if (widget.onCode != null)
          _ToolbarButton(
            icon: Icons.code_rounded,
            label: 'Code',
            onTap: widget.onCode!,
            toolbarStyle: toolbarStyle,
          ),

        // Divider
        _ToolbarDivider(),

        // Headings
        if (widget.onH1 != null)
          _ToolbarButton(
            icon: Icons.title_rounded,
            label: 'H1',
            onTap: widget.onH1!,
            toolbarStyle: toolbarStyle,
          ),
        if (widget.onH2 != null)
          _ToolbarButton(
            icon: Icons.text_fields_rounded,
            label: 'H2',
            onTap: widget.onH2!,
            toolbarStyle: toolbarStyle,
          ),

        // Divider
        _ToolbarDivider(),

        // Lists & blocks
        if (widget.onCheckbox != null)
          _ToolbarButton(
            icon: Icons.check_box_outlined,
            label: 'Checklist',
            onTap: widget.onCheckbox!,
            toolbarStyle: toolbarStyle,
          ),
        if (widget.onQuote != null)
          _ToolbarButton(
            icon: Icons.format_quote_rounded,
            label: 'Quote',
            onTap: widget.onQuote!,
            toolbarStyle: toolbarStyle,
          ),

        // Divider
        _ToolbarDivider(),

        // Media
        if (widget.onLink != null)
          _ToolbarButton(
            icon: Icons.link_rounded,
            label: 'Link',
            onTap: widget.onLink!,
            toolbarStyle: toolbarStyle,
          ),
        if (widget.onImage != null)
          _ToolbarButton(
            icon: Icons.image_outlined,
            label: 'Image',
            onTap: widget.onImage!,
            toolbarStyle: toolbarStyle,
          ),
      ],
    );
  }

  Widget _buildCollapsedToolbar(ThemeData theme, ToolbarStyle toolbarStyle) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.edit_rounded,
          size: 20,
          color: toolbarStyle.iconColor,
        ),
        const SizedBox(width: 8),
        Text(
          'Tap to expand',
          style: TextStyle(
            fontSize: 12,
            color: toolbarStyle.iconColor,
          ),
        ),
      ],
    );
  }
}

/// Toolbar button
class _ToolbarButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ToolbarStyle toolbarStyle;
  final bool isActive;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.toolbarStyle,
    this.isActive = false,
  });

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final motionSettings = MotionSettings.fromMediaQuery(context);

    return Semantics(
      label: widget.label,
      button: true,
      child: GestureDetector(
        onTap: () {
          PinpointHaptics.light();
          widget.onTap();
        },
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.9 : 1.0,
          duration: motionSettings.getDuration(PinpointAnimations.veryFast),
          curve: motionSettings.getCurve(PinpointAnimations.sharp),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? widget.toolbarStyle.activeIconColor.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              size: 20,
              color: widget.isActive
                  ? widget.toolbarStyle.activeIconColor
                  : widget.toolbarStyle.iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Toolbar divider
class _ToolbarDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 1,
      height: 24,
      color: theme.colorScheme.outline.withValues(alpha: 0.3),
    );
  }
}
