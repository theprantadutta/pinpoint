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
      const r = Radius.circular(SketchRadius.highlight);
      for (var i = 0; i < words.length; i++) {
        final first = i == 0, lastWord = i == words.length - 1;
        // Each word carries the space after it inside its own box, and only
        // the outer ends are rounded and padded, so neighbouring boxes join
        // into one continuous marker stroke. A separate highlighted space
        // box left a visible seam between words, and a stray sliver at the
        // end of a line when the phrase wrapped there.
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Container(
            padding: EdgeInsetsDirectional.only(
              start: first ? 4 : 0,
              end: lastWord ? 4 : 0,
            ),
            decoration: BoxDecoration(
              color: hl,
              borderRadius: BorderRadiusDirectional.horizontal(
                start: first ? r : Radius.zero,
                end: lastWord ? r : Radius.zero,
              ),
            ),
            child: Text(lastWord ? words[i] : '${words[i]} ',
                style: style.copyWith(color: SketchPastels.onPastel)),
          ),
        ));
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
