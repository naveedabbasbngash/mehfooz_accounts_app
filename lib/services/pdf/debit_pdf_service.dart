import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../model/balance_row.dart';
import 'base_pdf_service.dart';

class DebitPdfService extends BasePdfService {
  DebitPdfService._();
  static final DebitPdfService instance = DebitPdfService._();

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
    debugPrint(
      "[DebitPdf] render:start rows=${rows.length} currencies=${currencies.length}",
    );
    final sw = Stopwatch()..start();

    final fontData = await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
    final payload = <String, dynamic>{
      'currencies': currencies,
      'rows': rows
          .map(
            (r) => <String, dynamic>{
              'name': r.name,
              'byCurrency': r.byCurrency,
            },
          )
          .toList(),
      'fontBytes': fontData.buffer.asUint8List(),
    };

    final pdfBytes = await compute(_buildDebitPdfBytesInIsolate, payload);

    final dir = Directory.systemTemp;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/debit_report_$ts.pdf');
    await file.writeAsBytes(pdfBytes, flush: true);

    sw.stop();
    debugPrint(
      "[DebitPdf] render:done path=${file.path} bytes=${pdfBytes.length} elapsedMs=${sw.elapsedMilliseconds}",
    );
    return file;
  }

  Future<Uint8List> _buildPdfBytes({
    required List<String> currencies,
    required List<BalanceRow> rows,
    required pw.Font font,
    required pw.Font fontBold,
  }) async {
    final pdf = pw.Document();

    final double pageWidth = PdfPageFormat.cm * 29.7;
    final double pageHeight = PdfPageFormat.cm * 55;
    final pageFormat = PdfPageFormat(pageWidth, pageHeight, marginAll: 12);

    final deepBlue = PdfColor.fromInt(0xFF0B1E3A);
    final negativeRed = PdfColor.fromInt(0xFFC62828);
    final white = PdfColors.white;
    final black = PdfColors.black;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(12),
        build: (context) => [
          _buildTitleOnly(
            title: 'Banam / Debit Report',
            fontBold: fontBold,
            titleColor: deepBlue,
          ),
          pw.SizedBox(height: 6),
          _buildMetaRow(
            fontBold: fontBold,
            generatedLabel:
                "Generated Date ${DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now())}",
          ),
          pw.SizedBox(height: 4),
          _buildTable(
            currencies: currencies,
            rows: rows,
            font: font,
            fontBold: fontBold,
            deepBlue: deepBlue,
            negativeRed: negativeRed,
            white: white,
            black: black,
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildTitleOnly({
    required String title,
    required pw.Font fontBold,
    required PdfColor titleColor,
  }) {
    return pw.Center(
      child: pw.Text(
        title,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          font: fontBold,
          fontSize: BasePdfService.titleSize,
          color: titleColor,
        ),
      ),
    );
  }

  pw.Widget _buildMetaRow({
    required pw.Font fontBold,
    required String generatedLabel,
  }) {
    final mahfoozLight = PdfColor.fromInt(0xFFC7CDD7);
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          generatedLabel,
          style: pw.TextStyle(font: fontBold, fontSize: 8),
        ),
        pw.Text(
          "Mahfooz Accounts",
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 8,
            color: mahfoozLight,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTable({
    required List<String> currencies,
    required List<BalanceRow> rows,
    required pw.Font font,
    required pw.Font fontBold,
    required PdfColor deepBlue,
    required PdfColor negativeRed,
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

    pw.Widget debitCell(double raw) {
      final v = _fixZero(raw);
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
            color: negativeRed,
          ),
        ),
      );
    }

    for (final row in rows) {
      tableRows.add(
        pw.TableRow(
          children: [
            nameCell(row.name),
            ...currencies.map((c) => debitCell(row.byCurrency[c] ?? 0.0)),
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
          'Total Debit:',
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
            color: negativeRed,
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

Future<Uint8List> _buildDebitPdfBytesInIsolate(
  Map<String, dynamic> payload,
) async {
  final currencies =
      (payload['currencies'] as List?)?.cast<String>() ?? const <String>[];
  final rawRows = (payload['rows'] as List?)?.cast<Map>() ?? const <Map>[];
  final fontBytes = payload['fontBytes'] as Uint8List;

  final rows = rawRows.map((m) {
    final row = Map<String, dynamic>.from(m.cast<String, dynamic>());
    final byCurrencyMap = Map<String, dynamic>.from(
      (row['byCurrency'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
    final byCurrency = <String, double>{};
    byCurrencyMap.forEach((key, value) {
      byCurrency[key] = (value is num) ? value.toDouble() : 0.0;
    });
    return BalanceRow(
      name: (row['name'] as String?) ?? '',
      byCurrency: byCurrency,
    );
  }).toList(growable: false);

  final service = DebitPdfService._();
  final fontData = fontBytes.buffer.asByteData(
    fontBytes.offsetInBytes,
    fontBytes.lengthInBytes,
  );
  final unicodeFont = pw.Font.ttf(fontData);

  return service._buildPdfBytes(
    currencies: currencies,
    rows: rows,
    font: unicodeFont,
    fontBold: unicodeFont,
  );
}
