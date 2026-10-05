import 'dart:io';

import 'package:flutter/material.dart';
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

/// Markdown and PDF export of a text note, moved out of the editor screen
/// unchanged: the free-plan quota is checked first (and the premium gate
/// shown when it is spent), the file is shared, the quota is counted only
/// after a successful share, and the same analytics events fire.
class NoteExportActions {
  NoteExportActions._();

  static bool _nothingToExport(
      BuildContext context, String title, String content) {
    if (title.isNotEmpty || content.isNotEmpty) return false;
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

  /// Exports [content] (the editor's stored delta JSON) as Markdown.
  static Future<void> exportMarkdown(
    BuildContext context, {
    required String title,
    required String content,
  }) async {
    if (_nothingToExport(context, title, content)) return;
    final premiumService = PremiumService();
    if (!_checkQuota(context, premiumService)) return;

    try {
      // Read before the file I/O below; the context may be defunct after.
      final exportedNoteSubject = AppL10n.of(context).edExportedNoteSubject;

      final markdown = StringBuffer();
      if (title.isNotEmpty) {
        markdown.writeln('# $title');
        markdown.writeln();
      }
      if (content.isNotEmpty) {
        markdown.writeln(content);
      }
      markdown.writeln();
      markdown.writeln('---');
      markdown.writeln('*Exported from Pinpoint*');
      markdown.writeln('*Date: ${DateTime.now().toString().split('.')[0]}*');

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/${_fileName(title, 'md')}');
      await file.writeAsString(markdown.toString());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: title.isNotEmpty ? title : exportedNoteSubject,
        ),
      );

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

  /// Exports the note as a PDF with embedded fonts.
  static Future<void> exportPdf(
    BuildContext context, {
    required String title,
    required String content,
  }) async {
    if (_nothingToExport(context, title, content)) return;
    final premiumService = PremiumService();
    if (!_checkQuota(context, premiumService)) return;

    try {
      // Read everything that needs the Flutter BuildContext before the await
      // below, and before entering pw.Page's builder — its `context` parameter
      // is a pw.Context that shadows this one.
      final pageDirection = Directionality.of(context) == TextDirection.rtl
          ? pw.TextDirection.rtl
          : pw.TextDirection.ltr;
      final exportedFromLine = AppL10n.of(context).edExportedFromApp;
      final exportedDateLine = AppL10n.of(context)
          .edExportedDate(LocalizedDates.dateTime(context, DateTime.now()));
      final exportedNoteSubject = AppL10n.of(context).edExportedNoteSubject;

      // Embed real fonts: the PDF base-14 defaults are Latin-only, so a Thai,
      // Bengali, Arabic or Persian note would otherwise export as blank pages.
      final pdf = pw.Document(theme: await PdfFontService.theme());

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          textDirection: pageDirection,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty) ...[
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],
                if (content.isNotEmpty) ...[
                  pw.Text(
                    content,
                    style: const pw.TextStyle(
                      fontSize: 12,
                      lineSpacing: 1.5,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],
                pw.Spacer(),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Text(
                  exportedFromLine,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
                pw.Text(
                  exportedDateLine,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ],
            );
          },
        ),
      );

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/${_fileName(title, 'pdf')}');
      await file.writeAsBytes(await pdf.save());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: title.isNotEmpty ? title : exportedNoteSubject,
        ),
      );

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
}
