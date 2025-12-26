// lib/services/pdf/balance_pdf_service.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../model/balance_row.dart';
import 'base_pdf_service.dart';

class BalancePdfService extends BasePdfService {
  BalancePdfService._();
  static final BalancePdfService instance = BalancePdfService._();

  late pw.Font urduFont;

  // ------------------------------------------------------------------
  // Load Unicode (Arabic / Urdu / Pashto) font
  // ------------------------------------------------------------------
  Future<void> _loadUrduFont() async {
    final data =
    await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
    urduFont = pw.Font.ttf(data.buffer.asByteData());
  }

  // ------------------------------------------------------------------
  // RTL detection
  // ------------------------------------------------------------------
  bool _isRtl(String? s) {
    if (s == null || s.trim().isEmpty) return false;
    final r = RegExp(
        r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    return r.hasMatch(s);
  }

  pw.TextDirection _dir(String v) =>
      _isRtl(v) ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  pw.Font _pickFont(
      String text,
      pw.Font latin,
      pw.Font latinBold,
      bool bold,
      ) {
    if (_isRtl(text)) return urduFont;
    return bold ? latinBold : latin;
  }

  // ==================================================================
  // MAIN RENDER
  // ==================================================================
  Future<File> render({
    required List<String> currencies,
    required List<BalanceRow> rows,
  }) async {
    await _loadUrduFont();

    final pdf = pw.Document();

    // Tall page (same as before)
    final double pageWidth = PdfPageFormat.cm * 29.7;
    final double pageHeight = PdfPageFormat.cm * 55;
    final pageFormat = PdfPageFormat(pageWidth, pageHeight, marginAll: 12);

    final (latin, latinBold) = createFonts();

    final deepBlue = PdfColor.fromInt(0xFF0B1E3A);
    final greenBg = PdfColor.fromInt(0xFF4CAF50);
    final redBg = PdfColor.fromInt(0xFFC62828);
    final white = PdfColors.white;
    final black = PdfColors.black;

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (_) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildHeader(
                title: 'Account Summary (All Currencies)',
                font: latin,
                fontBold: latinBold,
                titleColor: deepBlue,
              ),
              pw.SizedBox(height: 10),
              _buildTable(
                currencies: currencies,
                rows: rows,
                latin: latin,
                latinBold: latinBold,
                deepBlue: deepBlue,
                greenBg: greenBg,
                redBg: redBg,
                white: white,
                black: black,
              ),
            ],
          );
        },
      ),
    );

    return savePdf(pdf, 'balance_report');
  }

  // ==================================================================
  // TABLE
  // ==================================================================
  pw.Widget _buildTable({
    required List<String> currencies,
    required List<BalanceRow> rows,
    required pw.Font latin,
    required pw.Font latinBold,
    required PdfColor deepBlue,
    required PdfColor greenBg,
    required PdfColor redBg,
    required PdfColor white,
    required PdfColor black,
  }) {
    final List<pw.TableRow> tableRows = [];

    pw.Widget headerCell(String text, pw.TextAlign align) {
      return pw.Container(
        color: deepBlue,
        padding: const pw.EdgeInsets.symmetric(
          vertical: BasePdfService.headerPadV,
          horizontal: BasePdfService.headerPadH,
        ),
        child: pw.Text(
          text,
          textAlign: align,
          textDirection: _dir(text),
          style: pw.TextStyle(
            font: latinBold,
            fontSize: BasePdfService.headerSize,
            color: white,
          ),
        ),
      );
    }

    // ---------------- HEADER ROW ----------------
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
          textDirection: _dir(name),
          style: pw.TextStyle(
            font: _pickFont(name, latin, latinBold, true),
            fontSize: BasePdfService.bodySize,
            color: deepBlue,
          ),
        ),
      );
    }

    // ---------------- VALUE CELL ----------------
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
          vertical: BasePdfService.cellPadV,
          horizontal: BasePdfService.cellPadH,
        ),
        color: bg,
        child: pw.Center(
          child: pw.Text(
            nf.format(value),
            style: pw.TextStyle(
              font: latin,
              fontSize: BasePdfService.bodySize,
              color: textColor,
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
    final totals = currencies.map(
          (cur) => rows.fold<int>(0, (sum, r) => sum + (r.byCurrency[cur] ?? 0)),
    );

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
          'Balance :',
          style: pw.TextStyle(
            font: latinBold,
            fontSize: BasePdfService.headerSize,
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
          vertical: BasePdfService.cellPadV,
          horizontal: BasePdfService.cellPadH,
        ),
        decoration: pw.BoxDecoration(
          color: bg,
          border: pw.Border(
            top: pw.BorderSide(color: deepBlue, width: 1),
          ),
        ),
        child: pw.Center(
          child: pw.Text(
            nf.format(value),
            style: pw.TextStyle(
              font: latinBold,
              fontSize: BasePdfService.headerSize,
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
}