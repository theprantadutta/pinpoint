import 'package:flutter/material.dart';

class NoteInputField extends StatelessWidget {
  final String title;
  final TextEditingController textEditingController;
  final int maxLines;

  const NoteInputField({
    super.key,
    required this.title,
    required this.textEditingController,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: textEditingController,
      onTapOutside: (event) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      maxLines: maxLines,
      // textAlign: TextAlign.center,
      decoration: InputDecoration(
        hintText: title,
        hintStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: isDarkTheme
              ? Colors.white.withValues(alpha: 0.7)
              : Colors.black.withValues(alpha: 0.4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: isDarkTheme
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: isDarkTheme
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: Colors.red,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: Colors.red,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        fillColor: isDarkTheme
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.01),
        filled: true,
      ),
    );
  }
}
