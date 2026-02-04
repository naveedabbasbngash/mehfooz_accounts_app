import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'base_pdf_service.dart';

class SummaryCombinedPdfService extends BasePdfService {
  SummaryCombinedPdfService._();
  static final SummaryCombinedPdfService instance =
  SummaryCombinedPdfService._();

  // 🔒 ONE formatter for money (always 2 decimals)
  static final NumberFormat _money = NumberFormat('#,##0.00');

  // 🔒 Fix -0.00 / rounding noise
  double _fixZero(double v) => v.abs() < 0.005 ? 0.0 : v;

  String _fmt(double v) => _money.format(_fixZero(v));

  /// [jbRows] and [acc1Rows] must have:
  ///   - currency : String
  ///   - amount   : double
  Future<File> render({
    required String companyName,
    required List<dynamic> jbRows,
    required List<dynamic> acc1Rows,
  }) async {
    final pdf = pw.Document();

    final (font, fontBold) = await createFonts();
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
        build: (_) => [
          // ===== HEADER =====
          buildHeader(
            title: "$companyName Summary Report",
            font: font,
            fontBold: fontBold,
            titleColor: blue,
          ),
          pw.SizedBox(height: 14),

          // ===== JB AMOUNT =====
          _sectionTitle("JB Amount Summary", fontBold, blue),
          pw.SizedBox(height: 6),
          _buildTable(
            rows: jbRows,
            font: font,
            fontBold: fontBold,
            blue: blue,
            black: black,
            white: white,
          ),

          pw.SizedBox(height: 24),

          // ===== CASH IN HAND =====
          _sectionTitle("Cash In Hand Summary", fontBold, blue),
          pw.SizedBox(height: 6),
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

  pw.Widget _sectionTitle(String text, pw.Font bold, PdfColor color) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 16,
        font: bold,
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
          alignment:
          align == pw.TextAlign.right ? pw.Alignment.centerRight : null,
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

    // ---- HEADER ----
    tableRows.add(
      pw.TableRow(
        children: [
          th("Currency"),
          th("Amount"),
        ],
      ),
    );

    // ---- DATA ----
    for (final row in rows) {
      final String currency = row.currency?.toString() ?? "-";
      final double amount =
      row.amount is num ? (row.amount as num).toDouble() : 0.0;

      // 🚫 HIDE ZERO ROWS (0, -0, rounding noise)
      if (_fixZero(amount) == 0.0) continue;

      tableRows.add(
        pw.TableRow(
          children: [
            td(currency),
            td(_fmt(amount), align: pw.TextAlign.right),
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
