import 'package:flutter/material.dart';

import '../../design_system/components/empty_state.dart' as sketch;

/// Legacy empty state. Delegates to the Sketchbook [sketch.EmptyState]
/// (sticker cluster, 22/800 title, muted line); new code should use that
/// directly.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) =>
      sketch.EmptyState(icon: icon, title: title, message: message);
}
