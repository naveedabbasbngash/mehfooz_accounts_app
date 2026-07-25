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
  PdfColor _moneyColor(double v) {
    final fixed = _fixZero(v);
    if (fixed < 0) return PdfColors.red700;
    if (fixed > 0) return PdfColors.green700;
    return PdfColors.black;
  }

  /// [jbRows] and [acc1Rows] must have:
  ///   - currency : String
  ///   - amount   : double
  Future<File> render({
    required String companyName,
    required List<dynamic> jbRows,
    required List<dynamic> acc1Rows,
    String? jbBaseCurrency,
  }) async {
    final pdf = pw.Document();

    final (font, fontBold) = await createFonts();
    final blue = PdfColor.fromInt(0xFF0B1E3A);
    final white = PdfColors.white;
    final black = PdfColors.black;
    final hasBase = (jbBaseCurrency ?? '').trim().isNotEmpty;

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
          pw.Center(
            child: pw.Text(
              "Combined Summery Report",
              style: pw.TextStyle(
                fontSize: 18,
                font: fontBold,
                color: blue,
              ),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "Generated Date & Time: ${DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now())}",
                style: pw.TextStyle(
                  font: font,
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                "Mahfooz Accounts",
                style: pw.TextStyle(
                  font: font,
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          _buildJbTable(
            rows: jbRows,
            baseCurrency: hasBase ? jbBaseCurrency : null,
            centerCells: true,
            font: font,
            fontBold: fontBold,
            blue: blue,
            black: black,
            white: white,
          ),
          pw.SizedBox(height: 18),
          pw.Center(
            child: _sectionTitle("Cash In Hand Summary", fontBold, blue),
          ),
          pw.SizedBox(height: 6),
          _buildTable(
            rows: acc1Rows,
            centerCells: true,
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
    bool centerCells = false,
  }) {
    final tableRows = <pw.TableRow>[];

    pw.Widget th(String text) => pw.Container(
      color: blue,
      padding: const pw.EdgeInsets.all(8),
      alignment: centerCells ? pw.Alignment.center : null,
      child: pw.Text(
        text,
        textAlign: centerCells ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(
          font: fontBold,
          color: white,
          fontSize: 12,
        ),
      ),
    );

    pw.Widget td(
      String text, {
      pw.TextAlign align = pw.TextAlign.left,
      PdfColor color = PdfColors.black,
    }) =>
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          alignment: align == pw.TextAlign.right
              ? pw.Alignment.centerRight
              : align == pw.TextAlign.center
                  ? pw.Alignment.center
                  : null,
          child: pw.Text(
            text,
            textAlign: align,
            style: pw.TextStyle(
              font: font,
              color: color,
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
            td(
              currency,
              align:
                  centerCells ? pw.TextAlign.center : pw.TextAlign.left,
            ),
            td(
              _fmt(amount),
              align:
                  centerCells ? pw.TextAlign.center : pw.TextAlign.right,
              color: _moneyColor(amount),
            ),
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

  String _rowCurrency(dynamic row) {
    try {
      final dynamic value = row is Map ? row['currency'] : row.currency;
      return (value?.toString() ?? '-').trim().isEmpty
          ? '-'
          : value.toString().trim();
    } catch (_) {
      return '-';
    }
  }

  double _rowAmount(dynamic row) {
    try {
      final dynamic value = row is Map ? row['amount'] : row.amount;
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  double? _rowRate(dynamic row) {
    try {
      final dynamic value = row is Map ? row['rate'] : null;
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    } catch (_) {
      return null;
    }
  }

  double? _rowConverted(dynamic row) {
    try {
      final dynamic value = row is Map ? row['converted'] : null;
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    } catch (_) {
      return null;
    }
  }

  pw.Widget _buildJbTable({
    required List<dynamic> rows,
    required String? baseCurrency,
    required pw.Font font,
    required pw.Font fontBold,
    required PdfColor blue,
    required PdfColor black,
    required PdfColor white,
    bool centerCells = false,
  }) {
    final base = (baseCurrency ?? '').trim().toUpperCase();
    final showBase = base.isNotEmpty;
    final tableRows = <pw.TableRow>[];

    pw.Widget th(String text) => pw.Container(
          color: blue,
          padding: const pw.EdgeInsets.all(8),
          alignment: centerCells ? pw.Alignment.center : null,
          child: pw.Text(
            text,
            textAlign: centerCells ? pw.TextAlign.center : pw.TextAlign.left,
            style: pw.TextStyle(
              font: fontBold,
              color: white,
              fontSize: 12,
            ),
          ),
        );

    pw.Widget td(
      String text, {
      pw.TextAlign align = pw.TextAlign.left,
      PdfColor color = PdfColors.black,
    }) =>
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          alignment:
              align == pw.TextAlign.right
                  ? pw.Alignment.centerRight
                  : align == pw.TextAlign.center
                      ? pw.Alignment.center
                      : null,
          child: pw.Text(
            text,
            textAlign: align,
            style: pw.TextStyle(
              font: font,
              color: color,
              fontSize: 11,
            ),
          ),
        );

    final headerCells = <pw.Widget>[
      th("Currency"),
      th("Amount"),
      if (showBase) th("Rate"),
      if (showBase) th('Base "$base"'),
    ];

    tableRows.add(pw.TableRow(children: headerCells));

    double convertedTotal = 0.0;
    bool hasConverted = false;

    for (final row in rows) {
      final currency = _rowCurrency(row);
      final amount = _rowAmount(row);
      if (_fixZero(amount) == 0.0) continue;

      final rate = _rowRate(row);
      double? converted = _rowConverted(row);
      if (showBase && converted == null && rate != null && rate > 0) {
        converted = amount * rate;
      }
      if (showBase && _normCurrency(currency) == base) {
        converted ??= amount;
      }

      if (showBase && converted != null) {
        convertedTotal += converted;
        hasConverted = true;
      }

      final rowCells = <pw.Widget>[
        td(
          currency,
          align: centerCells ? pw.TextAlign.center : pw.TextAlign.left,
        ),
        td(
          _fmt(amount),
          align:
              centerCells ? pw.TextAlign.center : pw.TextAlign.right,
          color: _moneyColor(amount),
        ),
      ];

      if (showBase) {
        rowCells.add(
          td(
            rate == null || rate <= 0 ? '--' : rate.toStringAsFixed(4),
            align:
                centerCells ? pw.TextAlign.center : pw.TextAlign.right,
          ),
        );
        rowCells.add(
          td(
            converted == null ? '--' : _fmt(converted),
            align:
                centerCells ? pw.TextAlign.center : pw.TextAlign.right,
            color: converted == null ? PdfColors.black : _moneyColor(converted),
          ),
        );
      }

      tableRows.add(pw.TableRow(children: rowCells));
    }

    if (showBase) {
      final totalCells = <pw.Widget>[
        td(
          '',
          align: centerCells ? pw.TextAlign.center : pw.TextAlign.left,
        ),
        td(
          '',
          align: centerCells ? pw.TextAlign.center : pw.TextAlign.right,
        ),
        td(
          'Total ($base)',
          align: centerCells ? pw.TextAlign.center : pw.TextAlign.right,
        ),
        td(
          hasConverted ? _fmt(convertedTotal) : '--',
          align:
              centerCells ? pw.TextAlign.center : pw.TextAlign.right,
          color: hasConverted ? _moneyColor(convertedTotal) : PdfColors.black,
        ),
      ];
      tableRows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: totalCells,
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

  String _normCurrency(String value) => value.trim().toUpperCase();
}
