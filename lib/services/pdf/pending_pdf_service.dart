// lib/services/pdf/pending_pdf_service.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../model/pending_row.dart';
import 'base_pdf_service.dart';

class PendingPdfService extends BasePdfService {
  PendingPdfService._();
  static final PendingPdfService instance = PendingPdfService._();

  late pw.Font urduFont;

  // ----------------------- Load Urdu Font -----------------------
  Future<void> _loadUrduFont() async {
    final data = await rootBundle.load("assets/fonts/NotoSansArabic-Regular.ttf");
    urduFont = pw.Font.ttf(data.buffer.asByteData());
  }

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

    await _loadUrduFont();

    final pdf = pw.Document();

    final (latin, latinBold) = createFonts();

    // ---------------- FIX: Always top-aligned PDF ----------------
    final double pageWidth = PdfPageFormat.cm * 29.7;   // A4 width
    final double pageHeight = PdfPageFormat.cm * 55.0;  // Tall (prevents centering)
    final pageFormat = PdfPageFormat(pageWidth, pageHeight, marginAll: 12);

    final deepBlue = PdfColor.fromInt(0xFF0B1E3A);
    final greyLine = PdfColor.fromInt(0xFFBEC3C8);
    final subtleBg = PdfColor.fromInt(0xFFF7F9FC);

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(
                officeName: officeName,
                title: title,
                font: latin,
                fontBold: latinBold,
                deepBlue: deepBlue,
              ),
              pw.SizedBox(height: 12),

              ..._buildCurrencySections(
                rows: rows,
                latin: latin,
                latinBold: latinBold,
                deepBlue: deepBlue,
                greyLine: greyLine,
                subtleBg: subtleBg,
              ),
            ],
          );
        },
      ),
    );

    return savePdf(pdf, "pending_report");
  }

  // ======================================================================
  //                       Header (Same Style)
  // ======================================================================
  pw.Widget _buildHeader({
    required String officeName,
    required String title,
    required pw.Font font,
    required pw.Font fontBold,
    required PdfColor deepBlue,
  }) {
    final today =
        "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              officeName,
              style: pw.TextStyle(font: fontBold, fontSize: 12, color: deepBlue),
            ),
            pw.Text(
              "Printed $today",
              style: pw.TextStyle(font: fontBold, fontSize: 10, color: deepBlue),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Center(
          child: pw.Text(
            title,
            style: pw.TextStyle(font: fontBold, fontSize: 18, color: deepBlue),
          ),
        ),
        pw.SizedBox(height: 6),
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

    for (final cur in currencies) {
      widgets.add(
        pw.Text(
          "Currency: $cur",
          style: pw.TextStyle(font: latinBold, fontSize: 12, color: deepBlue),
        ),
      );

      widgets.add(pw.SizedBox(height: 4));

      widgets.add(
        _buildCurrencyTable(
          rows: map[cur]!,
          latinFont: latin,
          latinBold: latinBold,
          deepBlue: deepBlue,
          greyLine: greyLine,
          subtleBg: subtleBg,
        ),
      );

      widgets.add(pw.SizedBox(height: 12));
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
          head("P.Amount"),
          head("Paid"),
          head("Balance"),
        ],
      ),
    );

    // ---------- TOTALS (DOUBLE SAFE) ----------
    double totalNotPaid = 0;
    double totalPaid = 0;
    double totalBalance = 0;

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

      totalNotPaid += r.notPaidAmount;
      totalPaid += r.paidAmount;
      totalBalance += r.balance;

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
            totalsCell("Not Paid: ${money(totalNotPaid)}"),
            totalsCell("Paid: ${money(totalPaid)}"),
            totalsCell(
              totalBalance < 0
                  ? "Balance: -${money(totalBalance)}"
                  : "Balance: ${money(totalBalance)}",
            ),
          ],
        ),
      ],
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        table,
        pw.SizedBox(height: 6),
        totals,
      ],
    );
  }
  pw.Widget _totalsCell(String text, pw.Font font, PdfColor deepBlue,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.Text(
        text,
        textDirection: _dir(text),
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 11, color: deepBlue),
      ),
    );
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