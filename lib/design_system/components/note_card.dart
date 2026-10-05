import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../colors.dart';
import '../spacing.dart';
import '../typography.dart';
import 'sketch/checklist_row.dart';
import 'sketch/sketch_card.dart';
import 'sketch/sketch_chip.dart';
import 'sketch/sticker_tile.dart';

/// A single checklist line shown in a note card preview.
class NoteChecklistItem {
  final String label;
  final bool isDone;
  const NoteChecklistItem({required this.label, this.isDone = false});
}

/// The Sketchbook note card. Its look follows the note:
///
/// - **text**: outlined surface card, title 15/700, up to a few muted lines
/// - **coloured**: the same on the note's pastel, ink text in both themes
/// - **pinned + short leading token** ("221B"): the token as a 40/800 display
///   number, the rest as a 12/500 line, and a "Pinned" pill
/// - **checklist**: open items with 12px boxes, then done items in mint
/// - **voice**: a mint card with a waveform and "Voice · 0:42"
/// - **reminder**: a lavender chip with the time at the top
class NoteCard extends StatelessWidget {
  final String title;
  final String? excerpt;
  final List<CardNoteTag>? tags;
  final DateTime? lastModified; // kept for API compat; not rendered
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

  /// Todo summary (fallback when [checklist] is absent).
  final int? totalTasks;
  final int? completedTasks;

  /// Optional checklist preview.
  final List<NoteChecklistItem>? checklist;

  /// Voice note duration label (e.g. "0:42").
  final String? voiceDuration;

  /// The note's pastel (resolved swatch). Null → surface card.
  final Color? backgroundColor;

  /// Localized reminder time ("Today, 6:00 PM"), shown as a lavender chip.
  final String? reminderLabel;

  /// Dim the card (archive / trash lists).
  final bool muted;

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
    this.reminderLabel,
    this.muted = false,
  });

  /// A short leading token worth showing big: up to 6 characters, at least
  /// one digit, on its own first line ("221B", "42", "9:30").
  static ({String token, String rest})? displayToken(String? excerpt) {
    if (excerpt == null) return null;
    final lines = excerpt
        .trim()
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;
    bool isToken(String w) => w.length <= 6 && w.contains(RegExp(r'\d'));

    final first = lines.first;
    if (isToken(first)) return (token: first, rest: lines.skip(1).join(' '));
    final words = first.split(RegExp(r'\s+'));
    if (words.length > 1 && isToken(words.first)) {
      return (
        token: words.first,
        rest: [words.skip(1).join(' '), ...lines.skip(1)].join(' '),
      );
    }
    return null;
  }

  /// Turns markdown-ish bullets into "•" so a card preview reads cleanly.
  static String previewText(String text) => text
      .split('\n')
      .map((l) {
        final m = RegExp(r'^\s*(?:[-*+]|\d+\.)\s+(?:\[[ xX]\]\s*)?(.*)$')
            .firstMatch(l);
        if (m != null) return '• ${m.group(1)}';
        return l.replaceFirst(RegExp(r'^#{1,6}\s+'), '');
      })
      .where((l) => l.trim().isNotEmpty)
      .join('\n');

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final l10n = AppL10n.of(context);
    final isVoice = noteType == 'voice';

    // Voice notes default to mint; everything else to the surface.
    final pastel = backgroundColor ?? (isVoice ? SketchPastels.mint : null);
    final onPastel = pastel != null;
    final hasTitle = title.trim().isNotEmpty;
    final token = isPinned && onPastel ? displayToken(excerpt) : null;

    final children = <Widget>[];

    if (reminderLabel != null) {
      children.add(Align(
        alignment: AlignmentDirectional.centerStart,
        child: SketchTag(
          label: reminderLabel!,
          pastel: SketchPastels.lavender,
          icon: Icons.alarm_rounded,
        ),
      ));
    }

    if (thumbnail != null) {
      children.add(ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: double.infinity,
          height: 120,
          child: FittedBox(
              fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: thumbnail),
        ),
      ));
    }

    if (token != null) {
      children.addAll(_featured(context, token, hasTitle));
    } else {
      if (hasTitle) children.add(_title(context, onPastel));
      final body = _body(context, onPastel, hasTitle);
      if (body != null) children.add(body);
      if (isPinned) {
        children.add(Align(
          alignment: AlignmentDirectional.centerStart,
          child: SketchTag(label: l10n.noteCardPinned, onPastel: onPastel),
        ));
      }
    }

    if (tags != null && tags!.isNotEmpty) {
      children.add(Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final tag in tags!.take(3))
            SketchTag(label: tag.label, onPastel: onPastel),
        ],
      ));
    }

    final card = SketchCard(
      pastel: pastel,
      padding: const EdgeInsets.all(SketchSpace.cardPad),
      borderWidth: isSelected ? 3 : null,
      onTap: onTap,
      onLongPress: onLongPress,
      selected: isSelected,
      semanticLabel: l10n.a11yNoteLabel(hasTitle ? title : l10n.dsEmptyNote),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              children[i],
            ],
          ],
        ),
      ),
    );

    final sized = isSelected
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              card,
              PositionedDirectional(
                top: -6,
                end: -6,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: s.inverse,
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(Icons.check_rounded, size: 16, color: s.onInverse),
                ),
              ),
            ],
          )
        : card;

    return muted ? Opacity(opacity: 0.7, child: sized) : sized;
  }

  Widget _title(BuildContext context, bool onPastel) {
    return Text(
      title,
      style: context.type.cardTitle
          .copyWith(color: onPastel ? SketchPastels.onPastel : null),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  List<Widget> _featured(BuildContext context,
      ({String token, String rest}) token, bool hasTitle) {
    final t = context.type;
    const ink = SketchPastels.onPastel;
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              hasTitle ? title : '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.chip.copyWith(fontWeight: FontWeight.w700, color: ink),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: ink, shape: BoxShape.circle),
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(token.token,
              maxLines: 1, style: t.displayNumber.copyWith(color: ink)),
        ),
      ),
      if (token.rest.isNotEmpty)
        Text(token.rest,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.caption.copyWith(color: ink)),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: SketchTag(
            label: AppL10n.of(context).noteCardPinned, onPastel: true),
      ),
    ];
  }

  Widget? _body(BuildContext context, bool onPastel, bool hasTitle) {
    final s = context.sketch;
    final t = context.type;
    final l10n = AppL10n.of(context);
    final mutedColor =
        onPastel ? SketchPastels.onPastel.withValues(alpha: 0.72) : s.muted;

    // Checklist preview.
    final items = checklist;
    if (items != null && items.isNotEmpty) {
      final open = items.where((i) => !i.isDone).toList();
      final done = items.where((i) => i.isDone).toList();
      const maxShown = 4;
      final shown = [...open, ...done].take(maxShown).toList();
      final hidden = items.length - shown.length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ChecklistPreviewLine(
                label: item.label,
                checked: item.isDone,
                onPastel: onPastel,
              ),
            ),
          if (hidden > 0)
            Text(l10n.noteCardMoreItems(hidden),
                style: t.caption.copyWith(color: mutedColor)),
        ],
      );
    }

    if (noteType == 'voice' && voiceDuration != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Waveform(seed: title.hashCode),
          const SizedBox(height: 10),
          Text(
            l10n.noteCardVoice(voiceDuration!),
            style: t.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: onPastel ? SketchPastels.onPastel : s.ink),
          ),
        ],
      );
    }

    if (excerpt != null && excerpt!.trim().isNotEmpty) {
      return Text(
        previewText(excerpt!),
        style: t.caption.copyWith(height: 1.5, color: mutedColor),
        maxLines: hasTitle ? 6 : 10,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (!hasTitle) {
      return Text(
        l10n.dsEmptyNote,
        style:
            t.caption.copyWith(fontStyle: FontStyle.italic, color: mutedColor),
      );
    }
    return null;
  }
}

/// A decorative waveform: 3px bars, the "played" part in ink and the rest at
/// 35%. Bar heights are derived from [seed] so a note always draws the same
/// shape.
class _Waveform extends StatelessWidget {
  const _Waveform({required this.seed});

  final int seed;

  @override
  Widget build(BuildContext context) {
    const heights = <double>[10, 20, 14, 24, 9, 17, 12, 20, 15, 22, 11, 18];
    final offset = seed.abs() % heights.length;
    return SizedBox(
      height: 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < 10; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Container(
              width: 3,
              height: heights[(i + offset) % heights.length],
              decoration: BoxDecoration(
                color:
                    SketchPastels.onPastel.withValues(alpha: i < 5 ? 1 : 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A small sticker shown on a card (26px, −8°).
class NoteCardSticker extends StatelessWidget {
  const NoteCardSticker({super.key, required this.glyph, this.color});

  final String glyph;
  final Color? color;

  @override
  Widget build(BuildContext context) => StickerTile(
        color: color ?? context.sketch.highlight,
        size: 26,
        angle: -8,
        glyph: glyph,
        shadowOffset: 0,
        radiusFactor: 0.31,
      );
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
