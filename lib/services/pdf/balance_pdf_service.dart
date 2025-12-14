// lib/services/pdf/balance_pdf_service.dart
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../model/balance_row.dart';
import 'base_pdf_service.dart';

class BalancePdfService extends BasePdfService {
  BalancePdfService._();
  static final BalancePdfService instance = BalancePdfService._();

  Future<File> render({
    required List<String> currencies,
    required List<BalanceRow> rows,
  }) async {
    final pdf = pw.Document();

    // Mobile-friendly tall page to avoid vertical centering in viewers
    final double pageWidth = PdfPageFormat.cm * 29.7;   // ~A4 width
    final double pageHeight = PdfPageFormat.cm * 55;    // tall page

    final pageFormat = PdfPageFormat(
      pageWidth,
      pageHeight,
      marginAll: 12,
    );

    final (font, fontBold) = createFonts();
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

  pw.Widget _buildTable({
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
          style: pw.TextStyle(
            font: fontBold,
            fontSize: BasePdfService.headerSize,
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
              font: font,
              fontSize: BasePdfService.bodySize,
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
            ...currencies.map((c) => valueCell(row.byCurrency[c] ?? 0)),
          ],
        ),
      );
    }

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
            font: fontBold,
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
        // ❗ FIX: use ONLY decoration, no separate `color:` param
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
              font: fontBold,
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