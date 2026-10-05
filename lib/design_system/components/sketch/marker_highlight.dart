import 'package:flutter/material.dart';

import '../../colors.dart';
import '../../spacing.dart';

/// The yellow marker highlight behind a word or two: highlight pastel, ink
/// text, radius 4, 1×4 padding. Wraps with the text across lines.
class MarkerHighlight extends StatelessWidget {
  const MarkerHighlight({
    super.key,
    required this.text,
    required this.style,
    this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
  });

  final String text;
  final TextStyle style;
  final Color? color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? context.sketch.highlight,
        borderRadius: BorderRadius.circular(SketchRadius.highlight),
      ),
      child: Text(text, style: style.copyWith(color: SketchPastels.onPastel)),
    );
  }
}

/// A headline where one marked part sits on the highlight. The marked part
/// is written as `[[...]]` inside a single localized string, so translators
/// choose which words get the marker:
///
/// `"Write it down. [[Your way.]]"`
///
/// Each word of the marked part is its own highlighted box so the marker
/// wraps naturally; unmarked text flows around it.
class HighlightedText extends StatelessWidget {
  const HighlightedText(
    this.source, {
    super.key,
    required this.style,
    this.textAlign = TextAlign.start,
    this.highlight,
  });

  final String source;
  final TextStyle style;
  final TextAlign textAlign;
  final Color? highlight;

  static final RegExp _mark = RegExp(r'\[\[(.+?)\]\]');

  /// [source] with the markers removed — for semantics and plain contexts.
  static String plain(String source) =>
      source.replaceAllMapped(_mark, (m) => m.group(1)!);

  @override
  Widget build(BuildContext context) {
    final hl = highlight ?? context.sketch.highlight;
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _mark.allMatches(source)) {
      if (m.start > last) {
        spans.add(TextSpan(text: source.substring(last, m.start)));
      }
      final words = m.group(1)!.split(' ');
      for (var i = 0; i < words.length; i++) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Container(
            margin:
                EdgeInsetsDirectional.only(end: i < words.length - 1 ? 0 : 0),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: hl,
              borderRadius: BorderRadius.circular(SketchRadius.highlight),
            ),
            child: Text(words[i],
                style: style.copyWith(color: SketchPastels.onPastel)),
          ),
        ));
        if (i < words.length - 1) {
          // A highlighted space keeps the marker continuous between words.
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: ColoredBox(
              color: hl,
              child: Text(' ', style: style),
            ),
          ));
        }
      }
      last = m.end;
    }
    if (last < source.length) spans.add(TextSpan(text: source.substring(last)));

    return Semantics(
      label: plain(source),
      excludeSemantics: true,
      child: Text.rich(TextSpan(style: style, children: spans),
          textAlign: textAlign),
    );
  }
}

/// The [TextStyle] for an inline highlight inside rich text (the editor's
/// `H` attribute): highlight background, ink text.
TextStyle markerTextStyle(BuildContext context, TextStyle base) =>
    base.copyWith(
      color: SketchPastels.onPastel,
      background: Paint()..color = context.sketch.highlight,
    );
