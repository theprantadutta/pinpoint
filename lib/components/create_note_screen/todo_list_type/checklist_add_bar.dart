import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../../../design_system/design_system.dart';

/// The checklist's add bar: a 60px inverse stadium with "Add a task…" and a
/// 44px mint "+" button. Enter adds the task and keeps the keyboard open, so
/// a list can be typed in one go.
class ChecklistAddBar extends StatefulWidget {
  const ChecklistAddBar({
    super.key,
    required this.onAdd,
    this.focusNode,
  });

  /// Called with the trimmed, non-empty text.
  final ValueChanged<String> onAdd;
  final FocusNode? focusNode;

  static const double height = 60;

  @override
  State<ChecklistAddBar> createState() => _ChecklistAddBarState();
}

class _ChecklistAddBarState extends State<ChecklistAddBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onAdd(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = context.sketch;
    final t = context.type;

    return Container(
      height: ChecklistAddBar.height,
      padding: const EdgeInsetsDirectional.only(start: 22, end: 8),
      decoration: ShapeDecoration(
        color: s.inverse,
        shape: const StadiumBorder(),
        shadows: SketchShadows.dock,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: widget.focusNode,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              cursorColor: s.onInverse,
              style: t.bodyRegular.copyWith(color: s.onInverse),
              onSubmitted: (_) => _submit(),
              // Keep the keyboard up after Enter.
              onEditingComplete: () {},
              decoration: InputDecoration.collapsed(
                hintText: l10n.edAddTaskHint,
                hintStyle: t.bodyRegular.copyWith(
                    fontWeight: FontWeight.w400,
                    color: s.onInverse.withValues(alpha: 0.6)),
              ).copyWith(
                filled: false,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SketchPressable(
            onTap: _submit,
            semanticLabel: l10n.edAddTask,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: SketchPastels.mint,
                shape: BoxShape.circle,
                border: Border.all(
                    color: SketchPastels.onPastel, width: SketchStroke.pastel),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.add_rounded,
                  size: 24, color: SketchPastels.onPastel),
            ),
          ),
        ],
      ),
    );
  }
}
