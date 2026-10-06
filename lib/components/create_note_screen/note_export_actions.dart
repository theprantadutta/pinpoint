import 'dart:io';

import 'package:flutter/material.dart';
import 'package:parchment/codecs.dart';
import 'package:parchment/parchment.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';

import '../../design_system/design_system.dart';
import '../../service_locators/init_service_locators.dart';
import '../../services/analytics/analytics_facade.dart';
import '../../services/pdf_font_service.dart';
import '../../services/premium_service.dart';
import '../../util/localized_dates.dart';
import '../../util/show_a_toast.dart';
import '../../widgets/premium_gate_dialog.dart';

/// Markdown and PDF export of a text note.
///
/// The free-plan quota is checked first (and the premium gate shown when it
/// is spent), the file is shared, and the export is counted only when the
/// share went through — dismissing the share sheet costs nothing.
///
/// Both formats are built from the editor's document itself: Markdown via
/// Parchment's own encoder, the PDF by walking its lines and blocks, so
/// headings, lists, checklists, quotes, code and inline styles survive.
/// (These used to export the stored delta JSON as if it were text.)
class NoteExportActions {
  NoteExportActions._();

  static bool _nothingToExport(BuildContext context, String title, ParchmentDocument document) {
    if (title.isNotEmpty || document.toPlainText().trim().isNotEmpty) return false;
    final l10n = AppL10n.of(context);
    showWarningToast(
      context: context,
      title: l10n.edNothingToExport,
      description: l10n.edAddContentBeforeExport,
    );
    return true;
  }

  /// True when the export may proceed (premium, or free quota left).
  static bool _checkQuota(BuildContext context, PremiumService premium) {
    if (premium.isPremium || premium.canExport()) return true;
    PremiumGateDialog.showExportLimit(context);
    return false;
  }

  static String _fileName(String title, String extension) => title.isNotEmpty
      ? '${title.replaceAll(RegExp(r'[^\w\s-]'), '')}.$extension'
      : 'note_${DateTime.now().millisecondsSinceEpoch}.$extension';

  /// Whether a share counts as an export. Dismissing the sheet does not;
  /// a platform that cannot report the outcome is given the benefit of the
  /// doubt the other way, since the file was produced.
  @visibleForTesting
  static bool shareCounts(ShareResultStatus status) => status != ShareResultStatus.dismissed;

  /// The note as Markdown: a `# title`, the body, and a short footer.
  @visibleForTesting
  static String markdownFor(String title, ParchmentDocument document, {required String exportedLine}) {
    final out = StringBuffer();
    if (title.isNotEmpty) out.writeln('# $title\n');
    final body = const ParchmentMarkdownCodec(unorderedListToken: '-').encode(document).trimRight();
    if (body.isNotEmpty) out.writeln(body);
    out.writeln('\n---\n*$exportedLine*');
    return out.toString();
  }

  static Future<bool> _share(String path, String subject) async {
    final result = await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], subject: subject),
    );
    return shareCounts(result.status);
  }

  /// Exports the note as Markdown.
  static Future<void> exportMarkdown(
    BuildContext context, {
    required String title,
    required ParchmentDocument document,
  }) async {
    if (_nothingToExport(context, title, document)) return;
    final premiumService = PremiumService();
    if (!_checkQuota(context, premiumService)) return;

    try {
      // Read before the file I/O below; the context may be defunct after.
      final l10n = AppL10n.of(context);
      final exportedNoteSubject = l10n.edExportedNoteSubject;
      final exportedLine =
          '${l10n.edExportedFromApp} · ${l10n.edExportedDate(LocalizedDates.dateTime(context, DateTime.now()))}';

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/${_fileName(title, 'md')}');
      await file.writeAsString(markdownFor(title, document, exportedLine: exportedLine));

      final shared = await _share(file.path, title.isNotEmpty ? title : exportedNoteSubject);
      if (!shared) return;

      if (!premiumService.isPremium) {
        await premiumService.incrementExports();
      }

      getIt<AnalyticsFacade>().trackNoteExported(format: 'markdown');
      PinpointHaptics.success();

      if (context.mounted) {
        showSuccessToast(
          context: context,
          title: AppL10n.of(context).edExported,
          description: AppL10n.of(context).edMarkdownExported,
        );
      }
    } catch (e) {
      debugPrint('Error exporting markdown: $e');
      PinpointHaptics.error();
      if (context.mounted) {
        showErrorToast(
          context: context,
          title: AppL10n.of(context).edExportFailed,
          description: AppL10n.of(context).edMarkdownExportFailed,
        );
      }
    }
  }

  /// Exports the note as a PDF with embedded fonts, over as many A4 pages as
  /// it needs.
  static Future<void> exportPdf(
    BuildContext context, {
    required String title,
    required ParchmentDocument document,
  }) async {
    if (_nothingToExport(context, title, document)) return;
    final premiumService = PremiumService();
    if (!_checkQuota(context, premiumService)) return;

    try {
      // Read everything that needs the Flutter BuildContext before the
      // awaits below.
      final pageDirection =
          Directionality.of(context) == TextDirection.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
      final l10n = AppL10n.of(context);
      final exportedLine =
          '${l10n.edExportedFromApp} · ${l10n.edExportedDate(LocalizedDates.dateTime(context, DateTime.now()))}';
      final exportedNoteSubject = l10n.edExportedNoteSubject;

      // Embed real fonts: the PDF base-14 defaults are Latin-only, so a Thai,
      // Bengali, Arabic or Persian note would otherwise export as blank pages.
      final pdf = pw.Document(theme: await PdfFontService.theme());
      pdf.addPage(notePages(
        title: title,
        document: document,
        footer: exportedLine,
        textDirection: pageDirection,
      ));

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/${_fileName(title, 'pdf')}');
      await file.writeAsBytes(await pdf.save());

      final shared = await _share(file.path, title.isNotEmpty ? title : exportedNoteSubject);
      if (!shared) return;

      if (!premiumService.isPremium) {
        await premiumService.incrementExports();
      }

      getIt<AnalyticsFacade>().trackNoteExported(format: 'pdf');
      PinpointHaptics.success();

      if (context.mounted) {
        showSuccessToast(
          context: context,
          title: AppL10n.of(context).edExported,
          description: AppL10n.of(context).edPdfExported,
        );
      }
    } catch (e) {
      debugPrint('Error exporting PDF: $e');
      PinpointHaptics.error();
      if (context.mounted) {
        showErrorToast(
          context: context,
          title: AppL10n.of(context).edExportFailed,
          description: AppL10n.of(context).edPdfExportFailed,
        );
      }
    }
  }

  /// The note laid out over A4 pages: title, then one widget per line of the
  /// document, with the export line and page number at the foot of each page.
  @visibleForTesting
  static pw.MultiPage notePages({
    required String title,
    required ParchmentDocument document,
    required String footer,
    pw.TextDirection textDirection = pw.TextDirection.ltr,
  }) {
    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 52, 48, 40),
      textDirection: textDirection,
      footer: (ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 16),
        padding: const pw.EdgeInsets.only(top: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(footer, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ],
        ),
      ),
      build: (ctx) => [
        if (title.isNotEmpty) ...[
          pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 16),
        ],
        ...PdfNoteRenderer.blocks(document),
      ],
    );
  }
}

/// Turns a Parchment document into PDF widgets, one per line, so a long note
/// flows across pages.
@visibleForTesting
class PdfNoteRenderer {
  PdfNoteRenderer._();

  static const double _body = 11.5;

  static List<pw.Widget> blocks(ParchmentDocument document) {
    final out = <pw.Widget>[];
    for (final node in document.root.children) {
      if (node is LineNode) {
        out.add(_line(node, null, 0));
      } else if (node is BlockNode) {
        final block = node.style.get(ParchmentAttribute.block);
        var index = 0;
        for (final child in node.children.whereType<LineNode>()) {
          index++;
          out.add(_line(child, block, index));
        }
      }
    }
    return out;
  }

  static pw.Widget _line(LineNode line, ParchmentAttribute? block, int index) {
    final int? heading = line.style.get(ParchmentAttribute.heading)?.value;
    final size = switch (heading) { 1 => 20.0, 2 => 16.5, 3 => 14.0, _ => _body };
    final base = pw.TextStyle(
      fontSize: size,
      lineSpacing: heading == null ? 3 : 1,
      fontWeight: heading == null ? pw.FontWeight.normal : pw.FontWeight.bold,
    );

    final spans = <pw.InlineSpan>[];
    for (final leaf in line.children.whereType<TextNode>()) {
      spans.add(pw.TextSpan(text: leaf.value, style: _inline(leaf.style, base)));
    }
    final text = spans.isEmpty
        ? pw.SizedBox(height: size * 0.9)
        : pw.RichText(text: pw.TextSpan(children: spans, style: base));

    final indent = (line.style.get(ParchmentAttribute.indent)?.value ?? 0) * 16.0;
    final top = heading != null ? 10.0 : 2.0;

    pw.Widget body;
    switch (block?.value) {
      case 'ul':
        body = _marker(_bullet(size), text);
      case 'ol':
        body = _marker(pw.Text('$index.', style: base), text);
      case 'cl':
        final checked = line.style.contains(ParchmentAttribute.checked);
        body = _marker(_checkbox(checked), checked ? pw.Opacity(opacity: 0.6, child: text) : text);
      case 'quote':
        body = pw.Container(
          padding: const pw.EdgeInsets.only(left: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(left: pw.BorderSide(color: PdfColors.grey500, width: 2)),
          ),
          child: text,
        );
      case 'code':
        body = pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          color: PdfColors.grey200,
          child: text,
        );
      default:
        body = text;
    }

    return pw.Padding(padding: pw.EdgeInsets.only(left: indent, top: top, bottom: 2), child: body);
  }

  static pw.TextStyle _inline(ParchmentStyle style, pw.TextStyle base) {
    var s = base;
    if (style.contains(ParchmentAttribute.bold)) s = s.copyWith(fontWeight: pw.FontWeight.bold);
    if (style.contains(ParchmentAttribute.italic)) s = s.copyWith(fontStyle: pw.FontStyle.italic);
    final decorations = <pw.TextDecoration>[
      if (style.contains(ParchmentAttribute.underline)) pw.TextDecoration.underline,
      if (style.contains(ParchmentAttribute.strikethrough)) pw.TextDecoration.lineThrough,
    ];
    if (decorations.isNotEmpty) s = s.copyWith(decoration: pw.TextDecoration.combine(decorations));
    if (style.contains(ParchmentAttribute.inlineCode)) {
      s = s.copyWith(background: const pw.BoxDecoration(color: PdfColors.grey200));
    }
    if (style.contains(ParchmentAttribute.link)) {
      s = s.copyWith(color: PdfColors.blue800, decoration: pw.TextDecoration.underline);
    }
    return s;
  }

  static pw.Widget _marker(pw.Widget marker, pw.Widget text) => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Aligned, or the fixed-width slot stretches the marker to fill it.
          pw.SizedBox(width: 18, child: pw.Align(alignment: pw.Alignment.topLeft, child: marker)),
          pw.Expanded(child: text),
        ],
      );

  /// Drawn, not a "•" glyph: not every embedded script font has one.
  static pw.Widget _bullet(double fontSize) => pw.Container(
        width: 4.5,
        height: 4.5,
        margin: pw.EdgeInsets.only(top: fontSize * 0.45, left: 3),
        decoration: const pw.BoxDecoration(color: PdfColors.grey800, shape: pw.BoxShape.circle),
      );

  static pw.Widget _checkbox(bool checked) => pw.Container(
        width: 10,
        height: 10,
        margin: const pw.EdgeInsets.only(top: 3),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey800, width: 1),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
          color: checked ? PdfColors.grey800 : null,
        ),
      );
}
