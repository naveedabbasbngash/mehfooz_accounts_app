// lib/services/pdf/credit_pdf_service.dart
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../model/balance_row.dart';
import 'base_pdf_service.dart';

class CreditPdfService extends BasePdfService {
  CreditPdfService._();
  static final CreditPdfService instance = CreditPdfService._();

  Future<File> render({
    required List<String> currencies,
    required List<BalanceRow> rows,
  }) async {
    final pdf = pw.Document();

    // 📌 Mobile-friendly tall page to avoid vertical-centering problem
    final double pageWidth = PdfPageFormat.cm * 29.7;   // A4 width
    final double pageHeight = PdfPageFormat.cm * 55;    // tall page

    final pageFormat = PdfPageFormat(
      pageWidth,
      pageHeight,
      marginAll: 12,
    );

    final (font, fontBold) = createFonts();
    final deepBlue = PdfColor.fromInt(0xFF0B1E3A);
    final white = PdfColors.white;
    final black = PdfColors.black;

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildHeader(
                title: 'Jama / Credit Report',
                font: font,
                fontBold: fontBold,
                titleColor: deepBlue,
              ),
              pw.SizedBox(height: 10),
              _buildTable(
                currencies: currencies,
                rows: rows,
                font: font,
                fontBold: fontBold,
                deepBlue: deepBlue,
                white: white,
                black: black,
              ),
            ],
          );
        },
      ),
    );

    return savePdf(pdf, 'credit_report');
  }

  // ===================================================================
  // TABLE BUILDER
  // ===================================================================
  pw.Widget _buildTable({
    required List<String> currencies,
    required List<BalanceRow> rows,
    required pw.Font font,
    required pw.Font fontBold,
    required PdfColor deepBlue,
    required PdfColor white,
    required PdfColor black,
  }) {
    final List<pw.TableRow> tableRows = [];

    // ---------------- HEADER CELL ----------------
    pw.Widget headerCell(String text, pw.TextAlign align) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(
          vertical: BasePdfService.headerPadV,
          horizontal: BasePdfService.headerPadH,
        ),
        color: deepBlue,
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: BasePdfService.headerSize,
            color: white,
          ),
        ),
      );
    }

    // Add header row
    tableRows.add(
      pw.TableRow(
        children: [
          headerCell('NAME', pw.TextAlign.left),
          ...currencies.map((c) => headerCell(c, pw.TextAlign.center)),
        ],
      ),
    );

    // ---------------- NAME CELL ----------------
    pw.Widget nameCell(String name) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(
          vertical: BasePdfService.cellPadV,
          horizontal: BasePdfService.cellPadH,
        ),
        child: pw.Text(
          name,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: BasePdfService.bodySize,
            color: deepBlue,
          ),
        ),
      );
    }

    // ---------------- VALUE CELL ----------------
    pw.Widget valueCell(int rawNet) {
      final int value = rawNet > 0 ? rawNet : 0;

      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(
          vertical: BasePdfService.cellPadV,
          horizontal: BasePdfService.cellPadH,
        ),
        child: pw.Center(
          child: pw.Text(
            nf.format(value),
            style: pw.TextStyle(
              font: font,
              fontSize: BasePdfService.bodySize,
              color: black,
            ),
          ),
        ),
      );
    }

    // ---------------- DATA ROWS ----------------
    for (final row in rows) {
      tableRows.add(
        pw.TableRow(
          children: [
            nameCell(row.name),
            ...currencies.map((c) => valueCell(row.byCurrency[c] ?? 0)),
          ],
        ),
      );
    }

    // ---------------- TOTALS ----------------
    final totals = currencies.map((cur) {
      return rows.fold<int>(0, (sum, r) {
        final raw = r.byCurrency[cur] ?? 0;
        return sum + (raw > 0 ? raw : 0);
      });
    }).toList();

    pw.Widget totalsLabelCell() {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(
          vertical: BasePdfService.cellPadV,
          horizontal: BasePdfService.cellPadH,
        ),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: deepBlue, width: 1),
          ),
        ),
        child: pw.Text(
          'Total Credit:',
          style: pw.TextStyle(
            font: fontBold,
            fontSize: BasePdfService.headerSize,
            color: deepBlue,
          ),
        ),
      );
    }

    pw.Widget totalsValueCell(int value) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(
          vertical: BasePdfService.cellPadV,
          horizontal: BasePdfService.cellPadH,
        ),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: deepBlue, width: 1),
          ),
        ),
        child: pw.Center(
          child: pw.Text(
            nf.format(value),
            style: pw.TextStyle(
              font: fontBold,
              fontSize: BasePdfService.headerSize,
              color: deepBlue,
            ),
          ),
        ),
      );
    }

    tableRows.add(
      pw.TableRow(
        children: [
          totalsLabelCell(),
          ...totals.map((v) => totalsValueCell(v)),
        ],
      ),
    );

    // ---------------- FINAL TABLE ----------------
    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey300,
        width: 0.3,
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        for (int i = 0; i < currencies.length; i++)
          i + 1: const pw.FlexColumnWidth(1),
      },
      children: tableRows,
    );
  }
}