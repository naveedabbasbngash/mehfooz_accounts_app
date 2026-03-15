// lib/services/pdf/pending_pdf_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../model/pending_row.dart';
import 'base_pdf_service.dart';

class PendingPdfService extends BasePdfService {
  PendingPdfService._();
  static final PendingPdfService instance = PendingPdfService._();

  late pw.Font urduFont;

  // ----------------------- RTL Detector -------------------------
  bool _isRtl(String? s) {
    if (s == null || s.trim().isEmpty) return false;
    final r = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    return r.hasMatch(s);
  }

  pw.TextDirection _dir(String v) => _isRtl(v) ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  pw.Font _pickFont(String text, pw.Font latin, pw.Font latinBold, bool bold) {
    if (_isRtl(text)) return urduFont;
    return bold ? latinBold : latin;
  }

  // ======================================================================
  //                          MAIN RENDER (Top-Aligned)
  // ======================================================================
  Future<File> render({
    required String officeName,
    required List<PendingRow> rows,
    String title = 'Pending Amount',
  }) async {
    if (rows.isEmpty) throw StateError("No pending rows to export");

    debugPrint("🧾 [PendingPdfService] render start rows=${rows.length}");

    final fontData = await rootBundle.load("assets/fonts/NotoSansArabic-Regular.ttf");
    final payload = <String, dynamic>{
      'title': title,
      'fontBytes': fontData.buffer.asUint8List(),
      'rows': rows
          .map(
            (r) => <String, dynamic>{
              'voucherNo': r.voucherNo,
              'dateIso': r.dateIso,
              'pd': r.pd ?? "",
              'msg': r.msg ?? "",
              'sender': r.sender ?? "",
              'receiver': r.receiver ?? "",
              'description': r.description ?? "",
              'notPaidAmount': r.notPaidAmount,
              'paidAmount': r.paidAmount,
              'balance': r.balance,
              'currency': r.currency,
            },
          )
          .toList(),
    };

    final pdfBytes = await compute(_buildPendingPdfBytesInIsolate, payload);

    final dir = Directory.systemTemp;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/pending_report_$ts.pdf');
    await file.writeAsBytes(pdfBytes, flush: true);
    final bytes = await file.length();
    debugPrint(
      "🧾 [PendingPdfService] render done path=${file.path} bytes=$bytes",
    );
    return file;
  }

  // ======================================================================
  //                       Header (Same Style)
  // ======================================================================
  pw.Widget _buildHeader({
    required String title,
    required pw.Font font,
    required pw.Font fontBold,
    required PdfColor deepBlue,
  }) {
    final generated = DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now());
    final mahfoozLight = PdfColor.fromInt(0xFFC7CDD7);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SizedBox(height: 3),
        pw.Center(
          child: pw.Text(
            title,
            style: pw.TextStyle(font: fontBold, fontSize: 18, color: deepBlue),
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              "Generated Date $generated",
              style: pw.TextStyle(font: fontBold, fontSize: 8, color: deepBlue),
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
        ),
        pw.SizedBox(height: 1),
        pw.Container(height: 1.5, color: deepBlue),
      ],
    );
  }

  // ======================================================================
  //                       Currency Sections
  // ======================================================================
  List<pw.Widget> _buildCurrencySections({
    required List<PendingRow> rows,
    required pw.Font latin,
    required pw.Font latinBold,
    required PdfColor deepBlue,
    required PdfColor greyLine,
    required PdfColor subtleBg,
  }) {
    final widgets = <pw.Widget>[];

    // Group by currency
    final map = <String, List<PendingRow>>{};
    for (final r in rows) {
      final key = r.currency.trim().isEmpty ? "Unknown" : r.currency.trim();
      map.putIfAbsent(key, () => []).add(r);
    }

    final currencies = map.keys.toList()..sort();
    const rowsPerChunk = 12;

    for (final cur in currencies) {
      final currencyRows = map[cur]!;
      final chunks = _chunkRows(currencyRows, rowsPerChunk);
      debugPrint(
        "🧾 [PendingPdfService] currency=$cur rows=${currencyRows.length} "
            "chunks=${chunks.length}",
      );

      for (int i = 0; i < chunks.length; i++) {
        final label = chunks.length == 1
            ? "Currency: $cur"
            : "Currency: $cur (${i + 1}/${chunks.length})";

        widgets.add(
          pw.Text(
            label,
            style: pw.TextStyle(font: latinBold, fontSize: 12, color: deepBlue),
          ),
        );

        widgets.add(pw.SizedBox(height: 4));

        widgets.add(
          _buildCurrencyTable(
            rows: chunks[i],
            latinFont: latin,
            latinBold: latinBold,
            deepBlue: deepBlue,
            greyLine: greyLine,
            subtleBg: subtleBg,
            showTotals: i == chunks.length - 1,
            totalsSource: currencyRows,
          ),
        );

        widgets.add(pw.SizedBox(height: 12));
      }
    }

    return widgets;
  }

  // ======================================================================
  //                            TABLE BUILDER
  // ======================================================================
  pw.Widget _buildCurrencyTable({
    required List<PendingRow> rows,
    required pw.Font latinFont,
    required pw.Font latinBold,
    required PdfColor deepBlue,
    required PdfColor greyLine,
    required PdfColor subtleBg,
    bool showTotals = true,
    List<PendingRow>? totalsSource,
  }) {
    const colFlex = <double>[0.12, 0.12, 0.12, 0.16, 0.16, 0.11, 0.11, 0.12];

    final table = pw.Table(
      border: pw.TableBorder.all(color: greyLine, width: 0.4),
      columnWidths: {
        for (int i = 0; i < colFlex.length; i++)
          i: pw.FlexColumnWidth(colFlex[i]),
      },
      children: [],
    );

    // ---------- HEADER ----------
    pw.Widget head(String text) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        color: deepBlue,
        child: pw.Text(
          text,
          textDirection: _dir(text),
          style: pw.TextStyle(
            font: latinBold,
            fontSize: 10,
            color: PdfColors.white,
          ),
        ),
      );
    }

    table.children.add(
      pw.TableRow(
        children: [
          head("Date"),
          head("PD"),
          head("Msg#"),
          head("Sender"),
          head("Receiver"),
          head("Invoice Amount"),
          head("Paid"),
          head("Balance"),
        ],
      ),
    );

    int i = 0;
    final sorted = [...rows]..sort((a, b) => a.dateIso.compareTo(b.dateIso));

    // ---------- HELPERS ----------
    String money(double v) => nf.format(v.abs());

    PdfColor moneyColor(double v) =>
        v < 0 ? PdfColors.red : PdfColors.green;

    pw.Widget cell(
        String v, {
          bool bold = false,
          pw.TextAlign align = pw.TextAlign.left,
          PdfColor? color,
          PdfColor? bg,
        }) {
      return pw.Container(
        color: bg,
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: pw.Text(
          v,
          textDirection: _dir(v),
          textAlign: align,
          style: pw.TextStyle(
            font: _pickFont(v, latinFont, latinBold, bold),
            fontSize: 10,
            color: color,
          ),
        ),
      );
    }

    // ---------- ROWS ----------
    for (final r in sorted) {
      final rowBg = i.isEven ? PdfColors.white : subtleBg;
      i++;

      table.children.add(
        pw.TableRow(
          children: [
            cell(_formatDate(r.dateIso), bg: rowBg),
            cell(r.pd ?? "", bg: rowBg),
            cell(r.msg ?? "", bg: rowBg),
            cell(r.sender ?? "", bg: rowBg),
            cell(r.receiver ?? "", bg: rowBg),

            // Not Paid
            cell(
              money(r.notPaidAmount),
              bold: true,
              align: pw.TextAlign.right,
              color: moneyColor(r.notPaidAmount),
              bg: rowBg,
            ),

            // Paid
            cell(
              money(r.paidAmount),
              bold: true,
              align: pw.TextAlign.right,
              color: moneyColor(r.paidAmount),
              bg: rowBg,
            ),

            // Balance (shows minus for debit)
            cell(
              r.balance < 0
                  ? "-${money(r.balance)}"
                  : money(r.balance),
              bold: true,
              align: pw.TextAlign.right,
              color: moneyColor(r.balance),
              bg: rowBg,
            ),
          ],
        ),
      );
    }

    // ---------- TOTALS ROW ----------
    pw.Widget totalsCell(String text,
        {pw.TextAlign align = pw.TextAlign.right}) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: pw.BoxDecoration(
          color: deepBlue,
          border: pw.Border(
            top: pw.BorderSide(color: deepBlue, width: 1),
          ),
        ),
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
            font: latinBold,
            fontSize: 11,
            color: PdfColors.white,
          ),
        ),
      );
    }

    final totalsInput = totalsSource ?? rows;
    final totalNotPaidAll = totalsInput.fold<double>(
      0.0,
      (sum, r) => sum + r.notPaidAmount,
    );
    final totalPaidAll = totalsInput.fold<double>(
      0.0,
      (sum, r) => sum + r.paidAmount,
    );
    final totalBalanceAll = totalsInput.fold<double>(
      0.0,
      (sum, r) => sum + r.balance,
    );

    final totals = pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          children: [
            totalsCell("Totals:", align: pw.TextAlign.left),
            totalsCell("Not Paid: ${money(totalNotPaidAll)}"),
            totalsCell("Paid: ${money(totalPaidAll)}"),
            totalsCell(
              totalBalanceAll < 0
                  ? "Balance: -${money(totalBalanceAll)}"
                  : "Balance: ${money(totalBalanceAll)}",
            ),
          ],
        ),
      ],
    );

    if (!showTotals) return table;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        table,
        pw.SizedBox(height: 6),
        totals,
      ],
    );
  }

  List<List<PendingRow>> _chunkRows(List<PendingRow> rows, int chunkSize) {
    final chunks = <List<PendingRow>>[];
    for (int i = 0; i < rows.length; i += chunkSize) {
      final end = (i + chunkSize < rows.length) ? i + chunkSize : rows.length;
      chunks.add(rows.sublist(i, end));
    }
    return chunks;
  }

  String _formatDate(String iso) {
    try {
      final p = iso.split("-");
      return "${p[2]}/${p[1]}/${p[0]}";
    } catch (_) {
      return iso;
    }
  }
}

Future<Uint8List> _buildPendingPdfBytesInIsolate(
  Map<String, dynamic> payload,
) async {
  final title = (payload['title'] as String?) ?? 'Pending Amount';
  final fontBytes = payload['fontBytes'] as Uint8List;
  final rawRows = (payload['rows'] as List).cast<Map>();

  final rows = rawRows.map((m) {
    final row = Map<String, dynamic>.from(m.cast<String, dynamic>());
    double toDouble(dynamic v) => (v is num) ? v.toDouble() : 0.0;
    int toInt(dynamic v) => (v is num) ? v.toInt() : 0;
    String toStr(dynamic v) => v?.toString() ?? "";
    return PendingRow(
      voucherNo: toInt(row['voucherNo']),
      dateIso: toStr(row['dateIso']),
      pd: toStr(row['pd']),
      msg: toStr(row['msg']),
      sender: toStr(row['sender']),
      receiver: toStr(row['receiver']),
      description: toStr(row['description']),
      notPaidAmount: toDouble(row['notPaidAmount']),
      paidAmount: toDouble(row['paidAmount']),
      balance: toDouble(row['balance']),
      currency: toStr(row['currency']),
    );
  }).toList();

  final service = PendingPdfService._();
  final fontData = fontBytes.buffer.asByteData(
    fontBytes.offsetInBytes,
    fontBytes.lengthInBytes,
  );
  final unicodeFont = pw.Font.ttf(fontData);
  service.urduFont = unicodeFont;

  final pdf = pw.Document();
  final latin = unicodeFont;
  final latinBold = unicodeFont;

  final pageFormat = PdfPageFormat.a4.landscape;
  final deepBlue = PdfColor.fromInt(0xFF0B1E3A);
  final greyLine = PdfColor.fromInt(0xFFBEC3C8);
  final subtleBg = PdfColor.fromInt(0xFFF7F9FC);

  final sections = service._buildCurrencySections(
    rows: rows,
    latin: latin,
    latinBold: latinBold,
    deepBlue: deepBlue,
    greyLine: greyLine,
    subtleBg: subtleBg,
  );

  pdf.addPage(
    pw.MultiPage(
      pageFormat: pageFormat,
      maxPages: 5000,
      margin: const pw.EdgeInsets.all(12),
      mainAxisAlignment: pw.MainAxisAlignment.start,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      header: (_) => service._buildHeader(
        title: title,
        font: latin,
        fontBold: latinBold,
        deepBlue: deepBlue,
      ),
      build: (_) => [...sections],
    ),
  );

  return await pdf.save();
}
