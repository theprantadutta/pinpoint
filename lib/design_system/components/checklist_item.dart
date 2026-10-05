import 'package:flutter/material.dart';

import '../colors.dart';
import '../typography.dart';
import 'sketch/checklist_row.dart';

/// An editable checklist task: a [ChecklistRow] whose label turns into a text
/// field when tapped. The checkbox toggles; the text commits on Enter or when
/// the field loses focus (an emptied field reverts instead of committing —
/// deleting is a swipe).
///
/// [showDragHandle] adds the leading handle shown while the task is being
/// reordered.
class ChecklistItem extends StatefulWidget {
  final String text;
  final bool isChecked;
  final ValueChanged<bool>? onChanged;

  /// Called with the new text when an edit is committed.
  final ValueChanged<String>? onTextChanged;
  final bool showDragHandle;
  final String? dragHandleLabel;
  final String? editHint;
  final bool readOnly;

  const ChecklistItem({
    super.key,
    required this.text,
    this.isChecked = false,
    this.onChanged,
    this.onTextChanged,
    this.showDragHandle = false,
    this.dragHandleLabel,
    this.editHint,
    this.readOnly = false,
  });

  @override
  State<ChecklistItem> createState() => _ChecklistItemState();
}

class _ChecklistItemState extends State<ChecklistItem> {
  final FocusNode _focusNode = FocusNode();
  TextEditingController? _controller;
  bool _editing = false;

  bool get _canEdit => !widget.readOnly && widget.onTextChanged != null;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editing) _commit();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _startEdit() {
    _controller ??= TextEditingController();
    _controller!
      ..text = widget.text
      ..selection = TextSelection.collapsed(offset: widget.text.length);
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _commit() {
    final value = _controller?.text.trim() ?? '';
    setState(() => _editing = false);
    if (value.isNotEmpty && value != widget.text) {
      widget.onTextChanged?.call(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;

    Widget? field;
    if (_editing) {
      field = TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLines: null,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _focusNode.unfocus(),
        style: t.bodyLarge.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.35,
          color: s.ink,
        ),
        decoration: InputDecoration.collapsed(
          hintText: widget.editHint,
          hintStyle: t.bodyLarge.copyWith(color: s.muted, height: 1.35),
        ).copyWith(
          filled: false,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
      );
    }

    final handle = widget.showDragHandle
        ? Semantics(
            label: widget.dragHandleLabel,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 6),
              child:
                  Icon(Icons.drag_indicator_rounded, size: 20, color: s.muted),
            ),
          )
        : null;

    return ChecklistRow(
      label: widget.text,
      checked: widget.isChecked,
      onChanged: widget.readOnly ? null : widget.onChanged,
      leading: handle,
      onTap: _canEdit && !_editing ? _startEdit : null,
      child: field,
    );
  }
}
