import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'base_pdf_service.dart';

class SummaryCombinedPdfService extends BasePdfService {
  SummaryCombinedPdfService._();
  static final SummaryCombinedPdfService instance =
  SummaryCombinedPdfService._();

  /// [jbRows] and [acc1Rows] are the same objects you use in your cards:
  /// they must have `.currency` (String) and `.amount` (double/int).
  Future<File> render({
    required String companyName,
    required List<dynamic> jbRows,
    required List<dynamic> acc1Rows,
  }) async {
    final pdf = pw.Document();

    final (font, fontBold) = createFonts();
    final blue = PdfColor.fromInt(0xFF0B1E3A);
    final white = PdfColors.white;
    final black = PdfColors.black;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(
          BasePdfService.marginLeft,
          BasePdfService.marginTop,
          BasePdfService.marginRight,
          BasePdfService.marginBottom,
        ),
        build: (context) => [
          // ====== HEADER ======
          buildHeader(
            title: "$companyName Summary Report",
            font: font,
            fontBold: fontBold,
            titleColor: blue,
          ),
          pw.SizedBox(height: 12),

          // ====== SECTION 1: JB Amount ======
          _sectionTitle("JB Amount Summary", fontBold, blue),
          pw.SizedBox(height: 4),
          _buildTable(
            rows: jbRows,
            font: font,
            fontBold: fontBold,
            blue: blue,
            black: black,
            white: white,
          ),

          pw.SizedBox(height: 22),

          // ====== SECTION 2: AccID = 1 ======
          _sectionTitle(" Cash In Hand Summary", fontBold, blue),
          pw.SizedBox(height: 4),
          _buildTable(
            rows: acc1Rows,
            font: font,
            fontBold: fontBold,
            blue: blue,
            black: black,
            white: white,
          ),
        ],
      ),
    );

    return savePdf(pdf, 'combined_summary');
  }

  pw.Widget _sectionTitle(String text, pw.Font fontBold, PdfColor color) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 16,
        font: fontBold,
        color: color,
      ),
    );
  }

  pw.Widget _buildTable({
    required List<dynamic> rows,
    required pw.Font font,
    required pw.Font fontBold,
    required PdfColor blue,
    required PdfColor black,
    required PdfColor white,
  }) {
    final tableRows = <pw.TableRow>[];

    pw.Widget th(String text) => pw.Container(
      color: blue,
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: fontBold,
          color: white,
          fontSize: 12,
        ),
      ),
    );

    pw.Widget td(String text, {pw.TextAlign align = pw.TextAlign.left}) =>
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            text,
            textAlign: align,
            style: pw.TextStyle(
              font: font,
              color: black,
              fontSize: 11,
            ),
          ),
        );

    // ---- Header row ----
    tableRows.add(
      pw.TableRow(
        children: [
          th("Currency"),
          th("Amount"),
        ],
      ),
    );

    // ---- Data rows ----
    for (final row in rows) {
      final String currency = row.currency?.toString() ?? "-";
      final num amountNum = (row.amount is num) ? row.amount as num : 0;
      final String amountText = nf.format(amountNum);

      tableRows.add(
        pw.TableRow(
          children: [
            td(currency),
            td(amountText, align: pw.TextAlign.right),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey300,
        width: 0.3,
      ),
      children: tableRows,
    );
  }
}