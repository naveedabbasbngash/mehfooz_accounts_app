import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../model/balance_row.dart';
import 'base_pdf_service.dart';

class CreditPdfService extends BasePdfService {
  CreditPdfService._();
  static final CreditPdfService instance = CreditPdfService._();

  static final NumberFormat _money = NumberFormat('#,##0.00');

  bool _isRtl(String? s) {
    if (s == null || s.trim().isEmpty) return false;
    return RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
    ).hasMatch(s);
  }

  pw.TextDirection _dir(String text) =>
      _isRtl(text) ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  double _fixZero(double v) => v.abs() < 0.005 ? 0.0 : v;

  String _fmtMoney(double v) => _money.format(_fixZero(v));

  Future<File> render({
    required List<String> currencies,
    required List<BalanceRow> rows,
  }) async {
    final pdf = pw.Document();

    final (font, fontBold) = await createFonts();
    final deepBlue = PdfColor.fromInt(0xFF0B1E3A);
    final white = PdfColors.white;
    final black = PdfColors.black;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(12),
        build: (context) => [
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
      ),
    );

    return savePdf(pdf, 'credit_report');
  }

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

    pw.Widget headerCell(String text, pw.TextAlign align) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(
          vertical: BasePdfService.headerPadV,
          horizontal: BasePdfService.headerPadH,
        ),
        color: deepBlue,
        alignment: align == pw.TextAlign.left
            ? pw.Alignment.centerLeft
            : pw.Alignment.center,
        child: pw.Text(
          text,
          textDirection: _dir(text),
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
          textDirection: _dir(name),
          style: pw.TextStyle(
            font: fontBold,
            fontSize: BasePdfService.bodySize,
            color: deepBlue,
          ),
        ),
      );
    }

    pw.Widget valueCell(double rawNet) {
      final v = _fixZero(rawNet);
      if (v <= 0) return pw.Container();

      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(
          vertical: BasePdfService.cellPadV,
          horizontal: BasePdfService.cellPadH,
        ),
        alignment: pw.Alignment.center,
        child: pw.Text(
          _fmtMoney(v),
          style: pw.TextStyle(
            font: font,
            fontSize: BasePdfService.bodySize,
            color: black,
          ),
        ),
      );
    }

    for (final row in rows) {
      tableRows.add(
        pw.TableRow(
          children: [
            nameCell(row.name),
            ...currencies.map((c) => valueCell(row.byCurrency[c] ?? 0.0)),
          ],
        ),
      );
    }

    final totals = currencies.map((cur) {
      return rows.fold<double>(0.0, (sum, r) {
        final raw = _fixZero(r.byCurrency[cur] ?? 0.0);
        return sum + (raw > 0 ? raw : 0.0);
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

    pw.Widget totalsValueCell(double value) {
      final v = _fixZero(value);
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(
          vertical: BasePdfService.cellPadV,
          horizontal: BasePdfService.cellPadH,
        ),
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: deepBlue, width: 1),
          ),
        ),
        child: pw.Text(
          v > 0 ? _fmtMoney(v) : '',
          style: pw.TextStyle(
            font: fontBold,
            fontSize: BasePdfService.headerSize,
            color: deepBlue,
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
        0: const pw.FlexColumnWidth(2),
        for (int i = 0; i < currencies.length; i++)
          i + 1: const pw.FlexColumnWidth(1),
      },
      children: tableRows,
    );
  }
}
