import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../design_system/design_system.dart';
import '../screen_arguments/create_note_screen_arguments.dart';
import '../screens/create_note_screen_v2.dart';

/// Creating notes from the dock (and the tablet sidebar).
///
/// A tap on Create starts a text note — the common case, one tap. A long
/// press opens [showChooser] for the other types.
class NewNote {
  NewNote._();

  /// Editor note types, as `CreateNoteScreenArguments.noticeType` names them.
  static const String text = 'Title Content';
  static const String checklist = 'Todo List';
  static const String voice = 'Record Audio';
  static const String reminder = 'Reminder';

  static void open(BuildContext context, [String noticeType = text]) {
    context.push(
      CreateNoteScreenV2.kRouteName,
      extra: CreateNoteScreenArguments(noticeType: noticeType),
    );
  }

  /// A sheet of four sticker tiles: Text, Checklist, Voice, Reminder.
  static Future<void> showChooser(BuildContext context) async {
    final l10n = AppL10n.of(context);
    final picked = await showSketchSheet<String>(
      context: context,
      builder: (ctx) => SketchSheet(
        title: l10n.newNoteChooserTitle,
        scrollable: false,
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            _TypeTile(
              label: l10n.noteTypeText,
              icon: Icons.notes_rounded,
              pastel: SketchPastels.yellow,
              angle: -6,
              onTap: () => Navigator.of(ctx).pop(text),
            ),
            _TypeTile(
              label: l10n.noteTypeChecklist,
              icon: Icons.check_rounded,
              pastel: SketchPastels.mint,
              angle: 8,
              onTap: () => Navigator.of(ctx).pop(checklist),
            ),
            _TypeTile(
              label: l10n.noteTypeVoice,
              icon: Icons.mic_none_rounded,
              pastel: SketchPastels.sky,
              angle: -4,
              onTap: () => Navigator.of(ctx).pop(voice),
            ),
            _TypeTile(
              label: l10n.noteTypeReminder,
              icon: Icons.alarm_rounded,
              pastel: SketchPastels.lavender,
              angle: 10,
              onTap: () => Navigator.of(ctx).pop(reminder),
            ),
          ],
        ),
      ),
    );
    if (picked != null && context.mounted) open(context, picked);
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.label,
    required this.icon,
    required this.pastel,
    required this.angle,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color pastel;
  final double angle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SketchCard(
      onTap: onTap,
      semanticLabel: label,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          StickerTile(color: pastel, size: 40, angle: angle, icon: icon),
          Text(label, style: context.type.cardTitleLarge),
        ],
      ),
    );
  }
}
