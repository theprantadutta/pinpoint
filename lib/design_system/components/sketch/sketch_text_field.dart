import 'package:flutter/material.dart';

import '../../animations.dart';
import '../../colors.dart';
import '../../spacing.dart';
import '../../typography.dart';
import 'sketch_pressable.dart';

/// The Sketchbook text input: a 56px outline stadium (1.5px). Focused, the
/// outline becomes 2px ink with a 4px highlight-pastel ring outside it; in
/// error it turns the error colour and the message sits below.
///
/// It is a [FormField], so [validator] takes part in [Form.validate] exactly
/// like a `TextFormField`. [errorText] shows an external error (e.g. a wrong
/// passphrase) without a validator.
///
/// With [obscureText] and both [revealLabel] / [concealLabel] given, an eye
/// button toggles visibility.
class SketchTextField extends StatefulWidget {
  const SketchTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.semanticLabel,
    this.prefixIcon,
    this.obscureText = false,
    this.revealLabel,
    this.concealLabel,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.autofocus = false,
    this.enabled = true,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.errorText,
    this.invalid = false,
    this.height = 56,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;

  /// Read by screen readers; defaults to [hint].
  final String? semanticLabel;
  final IconData? prefixIcon;
  final bool obscureText;
  final String? revealLabel;
  final String? concealLabel;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool autofocus;
  final bool enabled;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;

  /// Error outline without a message under the field — for when the error
  /// is shown elsewhere (the unlock screen's error pill).
  final bool invalid;
  final double height;

  @override
  State<SketchTextField> createState() => _SketchTextFieldState();
}

class _SketchTextFieldState extends State<SketchTextField> {
  TextEditingController? _ownController;
  FocusNode? _ownFocus;
  bool _focused = false;
  bool _revealed = false;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(SketchTextField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
  }

  void _onFocus() {
    if (mounted && _focused != _focus.hasFocus) {
      setState(() => _focused = _focus.hasFocus);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    _ownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final dur = SketchMotion.of(context, SketchMotion.base);
    final canReveal = widget.obscureText &&
        widget.revealLabel != null &&
        widget.concealLabel != null;

    return FormField<String>(
      initialValue: _controller.text,
      validator: widget.validator == null
          ? null
          : (_) => widget.validator!(_controller.text),
      builder: (field) {
        final error = widget.errorText ?? field.errorText;
        final hasError = error != null || widget.invalid;
        final stroke = hasError
            ? SketchFunctional.error
            : _focused
                ? s.ink
                : s.outline;
        final strokeWidth = (_focused || hasError)
            ? SketchStroke.checkbox
            : SketchStroke.outline;

        final input = TextField(
          controller: _controller,
          focusNode: _focus,
          autofocus: widget.autofocus,
          enabled: widget.enabled,
          obscureText: widget.obscureText && !_revealed,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          autocorrect: !widget.obscureText,
          enableSuggestions: !widget.obscureText,
          cursorColor: s.ink,
          style: t.bodyRegular.copyWith(fontSize: 16, color: s.ink),
          onChanged: (v) {
            field.didChange(v);
            widget.onChanged?.call(v);
          },
          onSubmitted: widget.onSubmitted,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: t.bodyRegular.copyWith(fontSize: 16, color: s.muted),
            isDense: true,
            filled: false,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
          ),
        );

        final box = AnimatedContainer(
          duration: dur,
          curve: SketchMotion.enter,
          height: widget.height,
          padding: EdgeInsetsDirectional.only(
            start: widget.prefixIcon == null ? 22 : 16,
            end: canReveal ? 4 : 22,
          ),
          decoration: ShapeDecoration(
            color: s.surface,
            shape: StadiumBorder(
              side: BorderSide(color: stroke, width: strokeWidth),
            ),
          ),
          child: Row(
            children: [
              if (widget.prefixIcon != null) ...[
                Icon(widget.prefixIcon, size: 20, color: s.muted),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Semantics(
                  label: widget.semanticLabel ?? widget.hint,
                  child: input,
                ),
              ),
              if (canReveal)
                SketchPressable(
                  onTap: widget.enabled
                      ? () => setState(() => _revealed = !_revealed)
                      : null,
                  semanticLabel:
                      _revealed ? widget.concealLabel : widget.revealLabel,
                  child: SizedBox(
                    width: SketchSpace.minTap + 4,
                    height: SketchSpace.minTap + 4,
                    child: Icon(
                      _revealed
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: s.muted,
                    ),
                  ),
                ),
            ],
          ),
        );

        // The highlight ring sits outside the outline, so focus never
        // shifts the layout.
        final ringed = AnimatedContainer(
          duration: dur,
          curve: SketchMotion.enter,
          decoration: ShapeDecoration(
            shape: StadiumBorder(
              side: BorderSide(
                color: _focused && !hasError
                    ? s.highlight
                    : s.highlight.withValues(alpha: 0),
                width: 4,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            ),
          ),
          child: box,
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ringed,
            if (error != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(22, 6, 22, 0),
                child: Text(
                  error,
                  style: t.caption.copyWith(color: SketchFunctional.error),
                ),
              ),
          ],
        );
      },
    );
  }
}
