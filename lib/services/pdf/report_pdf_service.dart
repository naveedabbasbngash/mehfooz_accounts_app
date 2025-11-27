// lib/services/pdf/report_pdf_service.dart
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../helpers/report_date_helper.dart';
import '../../model/balance_row.dart';

class ReportPdfService {
  ReportPdfService._();

  static final ReportPdfService instance = ReportPdfService._();

  // ====== Visual constants (mirroring your Kotlin PdfUtils) ======
  static const double _titleSize = 20;   // TITLE_SIZE
  static const double _headerSize = 16;  // HEADER_SIZE
  static const double _bodySize = 14;    // BODY_SIZE

  static const double _cellPadV = 2.5;   // CELL_PAD_V
  static const double _cellPadH = 3.0;   // CELL_PAD_H
  static const double _headerPadV = 3.5; // HEADER_PAD_V
  static const double _headerPadH = 3.0; // HEADER_PAD_H

  // Page margins (TOP, RIGHT, BOTTOM, LEFT)
  static const double _marginTop = 6;
  static const double _marginRight = 2;
  static const double _marginBottom = 6;
  static const double _marginLeft = 2;

  final NumberFormat _nf = NumberFormat.decimalPattern()
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = 0;

  // ==============================================================
  // PUBLIC ENTRY — BALANCE MATRIX (Option A)
  // ==============================================================

  /// EXACT Kotlin-style balance matrix:
  /// NAME | USD | PKR | SAR ...
  ///
  /// - [currencies] → column headers order
  /// - [rows]       → one row per account/person
  Future<File> renderBalanceReport({
    required List<String> currencies,
    required List<BalanceRow> rows,
  }) async {
    final pdf = pw.Document();

    final helvetica = pw.Font.helvetica();
    final helveticaBold = pw.Font.helveticaBold();

    // Colors
    final deepBlue = PdfColor.fromInt(0xFF0B1E3A);
    final greenBg = PdfColor.fromInt(0xFF4CAF50);
    final redBg = PdfColor.fromInt(0xFFC62828);
    final white = PdfColors.white;
    final black = PdfColors.black;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(
          _marginLeft,
          _marginTop,
          _marginRight,
          _marginBottom,
        ),
        build: (context) {
          return [
            _buildHeader(
              font: helvetica,
              fontBold: helveticaBold,
              titleColor: deepBlue,
            ),
            pw.SizedBox(height: 4),
            _buildMatrixTable(
              currencies: currencies,
              rows: rows,
              font: helvetica,
              fontBold: helveticaBold,
              deepBlue: deepBlue,
              greenBg: greenBg,
              redBg: redBg,
              white: white,
              black: black,
            ),
          ];
        },
      ),
    );

    return _savePdf(pdf, 'balance_report');
  }

  // ==============================================================
  // HEADER (similar to addHeaderWithZoom, but no JS zoom in Flutter)
  // ==============================================================

  pw.Widget _buildHeader({
    required pw.Font font,
    required pw.Font fontBold,
    required PdfColor titleColor,
  }) {
    final today = ReportDateHelper.nowIso(); // you can change format if needed

    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          children: [
            // Title (left)
            pw.Padding(
              padding: pw.EdgeInsets.zero,
              child: pw.Text(
                'Account Summary (All Currencies)',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: _titleSize,
                  color: titleColor,
                ),
              ),
            ),
            // Printed date (center)
            pw.Padding(
              padding: pw.EdgeInsets.zero,
              child: pw.Center(
                child: pw.Text(
                  'Printed $today',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            // Right cell: in Kotlin you had + / – zoom buttons (JS),
            // but that is not supported here, so we keep it blank.
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(),
            ),
          ],
        ),
      ],
    );
  }

  // ==============================================================
  // MATRIX TABLE (core of Kotlin renderMatrix)
  // ==============================================================

  pw.Widget _buildMatrixTable({
    required List<String> currencies,
    required List<BalanceRow> rows,
    required pw.Font font,
    required pw.Font fontBold,
    required PdfColor deepBlue,
    required PdfColor greenBg,
    required PdfColor redBg,
    required PdfColor white,
    required PdfColor black,
  }) {
    // Create list of TableRow (Flutter PDF format)
    final List<pw.TableRow> tableRows = [];

    // ---------- HEADER ROW ----------
    pw.Widget headerCell(String text, pw.TextAlign align) {
      return pw.Container(
        color: deepBlue,
        padding: const pw.EdgeInsets.symmetric(
          vertical: _headerPadV,
          horizontal: _headerPadH,
        ),
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: _headerSize,
            color: white,
          ),
        ),
      );
    }

    tableRows.add(
      pw.TableRow(
        children: [
          headerCell('NAME', pw.TextAlign.left),
          ...currencies.map((c) => headerCell(c, pw.TextAlign.center)),
        ],
      ),
    );

    // ---------- BODY ROWS ----------
    pw.Widget nameCell(String name) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(
          vertical: _cellPadV,
          horizontal: _cellPadH,
        ),
        child: pw.Text(
          name,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: _bodySize,
            color: deepBlue,
          ),
        ),
      );
    }

    pw.Widget valueCell(int value) {
      PdfColor bg;
      PdfColor textColor;

      if (value > 0) {
        bg = greenBg;
        textColor = white;
      } else if (value < 0) {
        bg = redBg;
        textColor = white;
      } else {
        bg = white;
        textColor = black;
      }

      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(
          vertical: _cellPadV,
          horizontal: _cellPadH,
        ),
        color: bg,
        child: pw.Center(
          child: pw.Text(
            _nf.format(value),
            style: pw.TextStyle(
              font: font,
              fontSize: _bodySize,
              color: textColor,
            ),
          ),
        ),
      );
    }

    for (final row in rows) {
      tableRows.add(
        pw.TableRow(
          children: [
            nameCell(row.name),
            ...currencies.map(
                  (c) => valueCell(row.byCurrency[c] ?? 0),
            ),
          ],
        ),
      );
    }

    // ---------- TOTALS ROW ----------
    final totals = currencies.map((cur) {
      return rows.fold<int>(0, (sum, r) => sum + (r.byCurrency[cur] ?? 0));
    }).toList();

    pw.Widget totalsLabelCell() {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(
          vertical: _cellPadV,
          horizontal: _cellPadH,
        ),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: deepBlue, width: 1),
          ),
        ),
        child: pw.Text(
          'Balance :',
          style: pw.TextStyle(
            font: fontBold,
            fontSize: _headerSize,
            color: deepBlue,
          ),
        ),
      );
    }

    pw.Widget totalsValueCell(int value) {
      PdfColor bg;
      PdfColor textColor;

      if (value > 0) {
        bg = greenBg;
        textColor = white;
      } else if (value < 0) {
        bg = redBg;
        textColor = white;
      } else {
        bg = white;
        textColor = black;
      }

      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(
          vertical: _cellPadV,
          horizontal: _cellPadH,
        ),
        decoration: pw.BoxDecoration(
          color: bg,
          border: pw.Border(
            top: pw.BorderSide(color: deepBlue, width: 1),
          ),
        ),
        child: pw.Center(
          child: pw.Text(
            _nf.format(value),
            style: pw.TextStyle(
              font: fontBold,
              fontSize: _headerSize,
              color: textColor,
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

    // Build final table
    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey300,
        width: 0.3,
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        for (int i = 0; i < currencies.length; i++)
          i + 1: const pw.FlexColumnWidth(1),
      },
      children: tableRows,
    );
  }
  // ==============================================================
  // SAVE HELPER
  // ==============================================================

  Future<File> _savePdf(pw.Document pdf, String baseName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$baseName.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}