// lib/services/pdf/ledger_pdf_service.dart

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../model/ledger_models.dart';
import 'base_pdf_service.dart';

class LedgerPdfService extends BasePdfService {
  LedgerPdfService._();
  static final LedgerPdfService instance = LedgerPdfService._();

  late pw.Font urduFont;
  late pw.Font urduFontBold;

  // ------------------------------------------------------------------
  // LOAD URDU-COMPATIBLE FONT
  // ------------------------------------------------------------------
  Future<void> _loadUrduFont() async {
    final data =
    await rootBundle.load("assets/fonts/NotoSansArabic-Regular.ttf");
    urduFont = pw.Font.ttf(data.buffer.asByteData());
    urduFontBold = urduFont;
  }

  // ------------------------------------------------------------------
  // RTL HELPERS
  // ------------------------------------------------------------------
  bool _isRtl(String? s) {
    if (s == null || s.isEmpty) return false;
    final rx = RegExp(r'[\u0600-\u06FF]');
    return rx.hasMatch(s);
  }

  pw.TextDirection _dir(String t) =>
      _isRtl(t) ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  pw.Font _fontFor(String text, pw.Font latin, pw.Font latinBold, bool bold) {
    return _isRtl(text)
        ? (bold ? urduFontBold : urduFont)
        : (bold ? latinBold : latin);
  }

  // ------------------------------------------------------------------
  // MAIN RENDER
  // ------------------------------------------------------------------
  Future<File> render({
    required String officeName,
    required String accountName,
    required String currency,
    required String periodText,
    required LedgerResult result,
  }) async {
    await _loadUrduFont();

    final pdf = pw.Document();
    final (latin, latinBold) = createFonts();

    final deepBlue = PdfColor.fromInt(0xFF0B1E3A);
    final greyLine = PdfColor.fromInt(0xFFBEC3C8);
    final subtleBg = PdfColor.fromInt(0xFFF7F9FC);

    final nf = NumberFormat('#,##0');

    // Pre-compute totals & closing balance
    int totalDr = 0;
    int totalCr = 0;
    int running = result.openingBalanceCents;

    for (final r in result.rows) {
      totalDr += r.dr;
      totalCr += r.cr;
      running += r.cr - r.dr;
    }
    final closingBalance = running;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(
          BasePdfService.marginLeft,
          BasePdfService.marginTop,
          BasePdfService.marginRight,
          BasePdfService.marginBottom,
        ),
        build: (context) {
          return [
            // ---------------- HEADER ----------------
            _buildHeader(
              officeName: officeName,
              accountName: accountName,
              currency: currency,
              periodText: periodText,
              latin: latin,
              latinBold: latinBold,
              deepBlue: deepBlue,
            ),
            pw.SizedBox(height: 10),

            // ---------------- SUMMARY STRIP ----------------
            _buildSummaryStrip(
              opening: result.openingBalanceCents,
              totalDr: totalDr,
              totalCr: totalCr,
              closing: closingBalance,
              nf: nf,
              latin: latin,
              latinBold: latinBold,
              deepBlue: deepBlue,
              subtleBg: subtleBg,
            ),
            pw.SizedBox(height: 10),

            // ---------------- TABLE ----------------
            _buildTable(
              rows: result.rows,
              opening: result.openingBalanceCents,
              latin: latin,
              latinBold: latinBold,
              deepBlue: deepBlue,
              grey: greyLine,
              subtleBg: subtleBg,
            ),
          ];
        },
      ),
    );

    return savePdf(pdf, "ledger_report");
  }

  // ------------------------------------------------------------------
  // HEADER (similar style as Pending PDF)
  // ------------------------------------------------------------------
  pw.Widget _buildHeader({
    required String officeName,
    required String accountName,
    required String currency,
    required String periodText,
    required pw.Font latin,
    required pw.Font latinBold,
    required PdfColor deepBlue,
  }) {
    final printed =
        "Printed ${reportDateToday()}"; // or use your own helper if needed

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              officeName,
              style: pw.TextStyle(
                font: latinBold,
                fontSize: 12,
                color: deepBlue,
              ),
            ),
            pw.Text(
              printed,
              style: pw.TextStyle(
                font: latinBold,
                fontSize: 10,
                color: deepBlue,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            "Ledger Report",
            style: pw.TextStyle(
              font: latinBold,
              fontSize: 18,
              color: deepBlue,
            ),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text(
                "Account: $accountName",
                style: pw.TextStyle(font: latinBold, fontSize: 11),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              "Currency: $currency",
              style: pw.TextStyle(font: latinBold, fontSize: 11),
            ),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          periodText,
          style: pw.TextStyle(font: latinBold, fontSize: 10),
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          height: 1.5,
          color: deepBlue,
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // SUMMARY STRIP (Opening / Debit / Credit / Closing)
  // ------------------------------------------------------------------
  pw.Widget _buildSummaryStrip({
    required int opening,
    required int totalDr,
    required int totalCr,
    required int closing,
    required NumberFormat nf,
    required pw.Font latin,
    required pw.Font latinBold,
    required PdfColor deepBlue,
    required PdfColor subtleBg,
  }) {
    pw.Widget box(String label, String value) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: pw.BoxDecoration(
          color: subtleBg,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                font: latin,
                fontSize: 9,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(
                font: latinBold,
                fontSize: 11,
                color: deepBlue,
              ),
            ),
          ],
        ),
      );
    }

    return pw.Row(
      children: [
        pw.Expanded(child: box("Opening", nf.format(opening))),
        pw.SizedBox(width: 6),
        pw.Expanded(child: box("Total Debit", nf.format(totalDr))),
        pw.SizedBox(width: 6),
        pw.Expanded(child: box("Total Credit", nf.format(totalCr))),
        pw.SizedBox(width: 6),
        pw.Expanded(child: box("Closing", nf.format(closing))),
      ],
    );
  }

  // ------------------------------------------------------------------
  // LEDGER TABLE
  // Date | Voucher# | Description | Debit | Credit | Balance
  // ------------------------------------------------------------------
  pw.Widget _buildTable({
    required List<LedgerTxn> rows,
    required int opening,
    required pw.Font latin,
    required pw.Font latinBold,
    required PdfColor deepBlue,
    required PdfColor grey,
    required PdfColor subtleBg,
  }) {
    final nf = NumberFormat('#,##0');

    int runningBalance = opening;
    int rowIndex = 0;

    final table = pw.Table(
      border: pw.TableBorder(
        left: pw.BorderSide(color: grey, width: 0.5),
        right: pw.BorderSide(color: grey, width: 0.5),
        bottom: pw.BorderSide(color: grey, width: 0.5),
        top: pw.BorderSide(color: grey, width: 0.5),
        horizontalInside: pw.BorderSide(color: grey, width: 0.25),
        verticalInside: pw.BorderSide(color: grey, width: 0.25),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.13), // Date
        1: pw.FlexColumnWidth(0.13), // Voucher
        2: pw.FlexColumnWidth(0.34), // Description
        3: pw.FlexColumnWidth(0.13), // Debit
        4: pw.FlexColumnWidth(0.13), // Credit
        5: pw.FlexColumnWidth(0.14), // Balance
      },
      children: [],
    );

    // Header cell
    pw.Widget head(String t, {pw.TextAlign align = pw.TextAlign.left}) {
      return pw.Container(
        color: deepBlue,
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        child: pw.Text(
          t,
          textAlign: align,
          style: pw.TextStyle(
            font: latinBold,
            fontSize: 9,
            color: PdfColors.white,
          ),
        ),
      );
    }

    // Header row
    table.children.add(
      pw.TableRow(
        children: [
          head("Date"),
          head("Voucher#"),
          head("Description"),
          head("Debit", align: pw.TextAlign.right),
          head("Credit", align: pw.TextAlign.right),
          head("Balance", align: pw.TextAlign.right),
        ],
      ),
    );

    // Helper: normal cell
    pw.Widget cell(
        String text, {
          bool bold = false,
          pw.TextAlign align = pw.TextAlign.left,
        }) {
      final bg =
      (rowIndex % 2 == 0) ? PdfColors.white : subtleBg; // zebra stripes

      return pw.Container(
        color: bg,
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: pw.Text(
          text,
          textDirection: _dir(text),
          textAlign: align,
          style: pw.TextStyle(
            font: _fontFor(text, latin, latinBold, bold),
            fontSize: 9,
          ),
        ),
      );
    }

    // Opening row
    rowIndex++;
    table.children.add(
      pw.TableRow(
        children: [
          cell(""),
          cell(""),
          cell("Opening Balance", bold: true),
          cell(""),
          cell(""),
          cell(nf.format(opening), bold: true, align: pw.TextAlign.right),
        ],
      ),
    );

    // Data rows
    for (final r in rows) {
      rowIndex++;

      runningBalance += r.cr - r.dr;

      final dateStr = DateFormat('dd/MM/yyyy').format(r.tDate);
      final voucherStr = r.voucherNo;
      final desc = r.description;
      final drStr = r.dr == 0 ? "" : nf.format(r.dr);
      final crStr = r.cr == 0 ? "" : nf.format(r.cr);
      final balStr = nf.format(runningBalance);

      table.children.add(
        pw.TableRow(
          children: [
            cell(dateStr),
            cell(voucherStr),
            cell(desc),
            cell(drStr, align: pw.TextAlign.right),
            cell(crStr, align: pw.TextAlign.right),
            cell(balStr, bold: true, align: pw.TextAlign.right),
          ],
        ),
      );
    }

    return table;
  }

  // ------------------------------------------------------------------
  // UTIL
  // ------------------------------------------------------------------
  String reportDateToday() {
    final now = DateTime.now();
    return "${now.day}/${now.month}/${now.year}";
  }
}