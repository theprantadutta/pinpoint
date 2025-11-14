import 'package:flutter/material.dart';
import '../theme.dart';
import '../typography.dart';
import '../animations.dart';
import 'tag_chip.dart';

/// NoteCard - Card component for displaying note previews
///
/// Features:
/// - Title, excerpt, tags, timestamp
/// - Press states (hover, pressed)
/// - Pin and star controls
/// - Long-press for selection
/// - Haptic feedback
/// - Accessibility support
class NoteCard extends StatefulWidget {
  final String title;
  final String? excerpt;
  final List<CardNoteTag>? tags;
  final DateTime? lastModified;
  final bool isPinned;
  final bool isStarred;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onPinToggle;
  final VoidCallback? onStarToggle;
  final Widget? thumbnail;

  const NoteCard({
    super.key,
    required this.title,
    this.excerpt,
    this.tags,
    this.lastModified,
    this.isPinned = false,
    this.isStarred = false,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
    this.onPinToggle,
    this.onStarToggle,
    this.thumbnail,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final listItemStyle = theme.listItemStyle;
    final motionSettings = MotionSettings.fromMediaQuery(context);

    // Determine background color based on state
    Color backgroundColor = listItemStyle.backgroundColor;
    if (widget.isSelected) {
      backgroundColor = theme.colorScheme.primaryContainer;
    } else if (_isPressed) {
      backgroundColor = listItemStyle.pressedColor;
    } else if (_isHovered) {
      backgroundColor = listItemStyle.hoverColor;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          if (widget.onTap != null) {
            PinpointHaptics.light();
            widget.onTap!();
          }
        },
        onLongPress: () {
          if (widget.onLongPress != null) {
            PinpointHaptics.medium();
            widget.onLongPress!();
          }
        },
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: Semantics(
          label: 'Note: ${widget.title}',
          button: true,
          selected: widget.isSelected,
          child: AnimatedContainer(
            duration: motionSettings.getDuration(PinpointAnimations.fast),
            curve: motionSettings.getCurve(PinpointAnimations.sharp),
            padding: listItemStyle.padding,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: listItemStyle.borderRadius,
              border: Border.all(
                color: widget.isSelected
                    ? theme.colorScheme.primary
                    : listItemStyle.borderColor,
                width: widget.isSelected ? 2 : 1,
              ),
              boxShadow: listItemStyle.elevation,
            ),
            child: ClipRect(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header row with title and controls
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thumbnail (if provided)
                      if (widget.thumbnail != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: widget.thumbnail,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],

                      // Title
                      Expanded(
                        child: Text(
                          widget.title.isEmpty ? 'Empty note' : widget.title,
                          style: PinpointTypography.noteCardTitle(
                            brightness: theme.brightness,
                          ).copyWith(
                            color: widget.title.isEmpty
                                ? theme.colorScheme.onSurfaceVariant
                                : null,
                            fontStyle: widget.title.isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Controls
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Star button
                          if (widget.onStarToggle != null)
                            _ControlButton(
                              icon: widget.isStarred
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              isActive: widget.isStarred,
                              onTap: () {
                                PinpointHaptics.light();
                                widget.onStarToggle!();
                              },
                              semanticLabel: widget.isStarred
                                  ? 'Unstar note'
                                  : 'Star note',
                            ),

                          const SizedBox(width: 4),

                          // Pin button
                          if (widget.onPinToggle != null)
                            _ControlButton(
                              icon: widget.isPinned
                                  ? Icons.push_pin_rounded
                                  : Icons.push_pin_outlined,
                              isActive: widget.isPinned,
                              onTap: () {
                                PinpointHaptics.light();
                                widget.onPinToggle!();
                              },
                              semanticLabel:
                                  widget.isPinned ? 'Unpin note' : 'Pin note',
                            ),
                        ],
                      ),
                    ],
                  ),

                  // Excerpt
                  if (widget.excerpt != null && widget.excerpt!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.excerpt!,
                      style: PinpointTypography.noteCardExcerpt(
                        brightness: theme.brightness,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Tags
                  if (widget.tags != null && widget.tags!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.tags!
                          .take(3)
                          .map((tag) => TagChip(
                                label: tag.label,
                                color: tag.color,
                                size: TagChipSize.small,
                              ))
                          .toList(),
                    ),
                  ],

                  // Timestamp
                  if (widget.lastModified != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _formatTimestamp(widget.lastModified!),
                      style: PinpointTypography.metadata(
                        brightness: theme.brightness,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }
}

/// Control button for pin/star actions
class _ControlButton extends StatefulWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final String semanticLabel;

  const _ControlButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.semanticLabel,
  });

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final motionSettings = MotionSettings.fromMediaQuery(context);

    return Semantics(
      label: widget.semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.9 : 1.0,
          duration: motionSettings.getDuration(PinpointAnimations.veryFast),
          curve: motionSettings.getCurve(PinpointAnimations.sharp),
          child: Container(
            padding: const EdgeInsets.all(4),
            child: Icon(
              widget.icon,
              size: 20,
              color: widget.isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Note tag data model for card display
class CardNoteTag {
  final String label;
  final Color? color;

  const CardNoteTag({
    required this.label,
    this.color,
  });
}

// Alias for backward compatibility
@Deprecated('Use CardNoteTag instead to avoid conflict with database NoteTag')
typedef NoteTag = CardNoteTag;
