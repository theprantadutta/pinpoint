import 'package:flutter/material.dart';
import '../theme.dart';
import '../typography.dart';
import '../animations.dart';

/// A single checklist line shown in a note card preview.
class NoteChecklistItem {
  final String label;
  final bool isDone;
  const NoteChecklistItem({required this.label, this.isDone = false});
}

/// NoteCard — borderless, flat, Google-Keep-style note tile.
///
/// Clean by design: no inline pin/star buttons, no type badges, no accent bars,
/// no timestamps. Separation comes from surface contrast + spacing (dark) or a
/// hairline outline (light). A note may show a body excerpt OR a checklist
/// preview, optionally on a colored background.
class NoteCard extends StatefulWidget {
  final String title;
  final String? excerpt;
  final List<CardNoteTag>? tags;
  final DateTime? lastModified; // kept for API compat; not rendered (Keep-style)
  final bool isPinned;
  final bool isStarred; // kept for API compat
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onPinToggle; // kept for API compat
  final VoidCallback? onStarToggle; // kept for API compat
  final Widget? thumbnail;

  /// Display hint: 'text', 'todo', 'voice', 'reminder'.
  final String? noteType;

  /// Todo summary (kept for API compat / fallback).
  final int? totalTasks;
  final int? completedTasks;

  /// Optional checklist preview (Keep-style). When provided, shows unchecked
  /// items then a "+N checked items" summary.
  final List<NoteChecklistItem>? checklist;

  /// Voice note duration label (e.g. "0:42").
  final String? voiceDuration;

  /// Optional note background color (resolved swatch). Null → theme card color.
  final Color? backgroundColor;

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
    this.noteType,
    this.totalTasks,
    this.completedTasks,
    this.checklist,
    this.voiceDuration,
    this.backgroundColor,
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
    final cs = theme.colorScheme;
    final listItemStyle = theme.listItemStyle;
    final motionSettings = MotionSettings.fromMediaQuery(context);
    final isDark = theme.brightness == Brightness.dark;

    final baseColor = widget.backgroundColor ?? listItemStyle.backgroundColor;

    // Resolve background per interaction state.
    Color backgroundColor = baseColor;
    if (_isPressed) {
      backgroundColor = Color.alphaBlend(
        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        baseColor,
      );
    } else if (_isHovered) {
      backgroundColor = Color.alphaBlend(
        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
        baseColor,
      );
    }

    // Border: selection ring > colored-note hairline > light-mode hairline.
    Color borderColor;
    double borderWidth;
    if (widget.isSelected) {
      borderColor = cs.primary;
      borderWidth = 2;
    } else if (widget.backgroundColor != null) {
      // Colored notes get a faint matching outline so they read as a tile.
      borderColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06);
      borderWidth = 1;
    } else if (!isDark) {
      borderColor = listItemStyle.borderColor; // hairline in light mode
      borderWidth = 1;
    } else {
      borderColor = Colors.transparent; // borderless in dark
      borderWidth = 1;
    }

    final hasTitle = widget.title.trim().isNotEmpty;

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
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Thumbnail (e.g. attached image) above content.
                if (widget.thumbnail != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: double.infinity,
                      height: 120,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: widget.thumbnail,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Title + subtle pin indicator (no button).
                if (hasTitle)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: PinpointTypography.noteCardTitle(
                            brightness: theme.brightness,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.isPinned) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.push_pin,
                            size: 16, color: cs.onSurfaceVariant),
                      ],
                    ],
                  ),

                // Body / checklist / voice.
                _buildBody(context, theme, cs, hasTitle),

                // Label chips at the bottom (Keep-style).
                if (widget.tags != null && widget.tags!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: widget.tags!
                        .take(3)
                        .map((tag) => _LabelChip(label: tag.label))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, ThemeData theme, ColorScheme cs, bool hasTitle) {
    final topGap = hasTitle ? const SizedBox(height: 8) : const SizedBox.shrink();

    // Checklist preview.
    if (widget.checklist != null && widget.checklist!.isNotEmpty) {
      final items = widget.checklist!;
      final unchecked = items.where((i) => !i.isDone).toList();
      final checkedCount = items.length - unchecked.length;
      final shown = unchecked.take(7).toList();
      final hiddenUnchecked = unchecked.length - shown.length;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          topGap,
          ...shown.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_box_outline_blank,
                        size: 18, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.label,
                        style: PinpointTypography.noteCardExcerpt(
                          brightness: theme.brightness,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
          if (hiddenUnchecked > 0)
            _summaryLine(theme, cs, '+ $hiddenUnchecked more items'),
          if (checkedCount > 0)
            _summaryLine(theme, cs, '+ $checkedCount checked items'),
        ],
      );
    }

    // Voice note row.
    if (widget.noteType == 'voice' && widget.voiceDuration != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_outline, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              widget.voiceDuration!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Plain body excerpt.
    if (widget.excerpt != null && widget.excerpt!.trim().isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          topGap,
          Text(
            widget.excerpt!,
            style: PinpointTypography.noteCardExcerpt(
              brightness: theme.brightness,
            ),
            maxLines: hasTitle ? 8 : 12,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    // Empty note (no title, no body).
    if (!hasTitle) {
      return Text(
        'Empty note',
        style: PinpointTypography.noteCardExcerpt(
          brightness: theme.brightness,
        ).copyWith(
          fontStyle: FontStyle.italic,
          color: cs.onSurfaceVariant,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _summaryLine(ThemeData theme, ColorScheme cs, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Small label/folder chip rendered at the bottom of a card.
class _LabelChip extends StatelessWidget {
  final String label;
  const _LabelChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Note tag data model for card display.
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
