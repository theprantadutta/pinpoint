import 'package:flutter/material.dart';

import 'colors.dart';

/// Sketchbook is flat. These are the only two shadows.
class SketchShadows {
  SketchShadows._();

  /// The floating dock / editor toolbar.
  static const List<BoxShadow> dock = [
    BoxShadow(
      offset: Offset(0, 14),
      blurRadius: 30,
      spreadRadius: -12,
      color: Color(0x73000000),
    ),
  ];

  /// A sticker's hard offset. Always ink, in both themes.
  static List<BoxShadow> sticker([double offset = 3]) => [
        BoxShadow(
          offset: Offset(offset, offset),
          blurRadius: 0,
          color: SketchPastels.onPastel,
        ),
      ];
}
