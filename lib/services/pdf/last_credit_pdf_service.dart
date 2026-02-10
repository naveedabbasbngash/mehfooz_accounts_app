import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../model/last_credit_row.dart';
import 'base_pdf_service.dart';

class LastCreditPdfService extends BasePdfService {
  LastCreditPdfService._();
  static final LastCreditPdfService instance = LastCreditPdfService._();

  bool _isRtl(String? s) {
    if (s == null || s.trim().isEmpty) return false;
    return RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
    ).hasMatch(s);
  }

  pw.TextDirection _dir(String text) =>
      _isRtl(text) ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  Future<File> render({
    required String currencyName,
    required List<LastCreditRow> rows,
  }) async {
    final pdf = pw.Document();

    final (latin, latinBold) = await createFonts();
    final deepBlue = PdfColor.fromInt(0xFF0B1E3A);

    // ✅ Decimal-safe formatter for money
    final nf = NumberFormat('#,##0.00');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            // --------------------------------------------------
            // HEADER
            // --------------------------------------------------
            pw.Text(
              'Last Credit Summary',
              style: pw.TextStyle(
                font: latinBold,
                fontSize: 20,
                color: deepBlue,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              children: [
                pw.Text(
                  'Currency:',
                  style: pw.TextStyle(
                    font: latin,
                    fontSize: 11,
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: pw.Text(
                    currencyName,
                    textDirection: _dir(currencyName),
                    style: pw.TextStyle(
                      font: latin,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // --------------------------------------------------
            // TABLE
            // --------------------------------------------------
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey300,
                width: 0.4,
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(3), // Customer
                1: pw.FlexColumnWidth(2), // Balance
                2: pw.FlexColumnWidth(2), // Date
                3: pw.FlexColumnWidth(2), // No Days
                4: pw.FlexColumnWidth(2), // جمع Cr
              },
              children: [
                // ---------------- HEADER ROW ----------------
                pw.TableRow(
                  decoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _headerCell(
                      'Customer',
                      font: latinBold,
                    ),
                    _headerCell(
                      'Balance',
                      font: latinBold,
                      align: pw.TextAlign.center,
                    ),
                    _headerCell(
                      'Date',
                      font: latinBold,
                      align: pw.TextAlign.center,
                    ),
                    _headerCell(
                      'No Days',
                      font: latinBold,
                      align: pw.TextAlign.center,
                    ),
                    _headerCell(
                      'جمع Cr',
                      font: latinBold,
                      align: pw.TextAlign.center,
                    ),
                  ],
                ),

                // ---------------- DATA ROWS ----------------
                ...rows.map((row) {
                  // ---------------- SAFE DOUBLE NORMALIZATION ----------------
                  final double balance =
                  (row.netBalance as num).toDouble();
                  final double lastCr =
                  (row.lastCreditAmount as num).toDouble();

                  final balanceFormatted =
                  nf.format(balance.abs() < 0.005 ? 0.0 : balance);
                  final crFormatted =
                  nf.format(lastCr.abs() < 0.005 ? 0.0 : lastCr);

                  // ---------------- DATE ----------------
                  String cleanDate;
                  try {
                    cleanDate =
                        row.lastTransactionDate?.substring(0, 10) ?? '-';
                  } catch (_) {
                    cleanDate = row.lastTransactionDate ?? '-';
                  }

                  // ---------------- DAYS (INT ONLY) ----------------
                  final int days =
                  (row.daysSinceLastCredit as num).round();
                  final double months = days / 30.0;

                  PdfColor bg;
                  PdfColor fg;

                  if (months > 12) {
                    bg = PdfColors.red;
                    fg = PdfColors.white;
                  } else if (months > 6) {
                    bg = PdfColors.yellow;
                    fg = PdfColors.black;
                  } else {
                    bg = PdfColors.white;
                    fg = PdfColors.black;
                  }

                  return pw.TableRow(
                    children: [
                      // Customer
                      _bodyCell(
                        row.customer,
                        font: latin,
                        align: pw.TextAlign.left,
                      ),

                      // Balance (RED)
                      _bodyCell(
                        balanceFormatted,
                        font: latin,
                        align: pw.TextAlign.center,
                        color: PdfColors.red,
                      ),

                      // Date
                      _bodyCell(
                        cleanDate,
                        font: latin,
                        align: pw.TextAlign.center,
                      ),

                      // No Days (colored cell)
                      pw.Container(
                        color: bg,
                        padding: const pw.EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 4,
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          days.toString(), // ✅ NO formatter
                          style: pw.TextStyle(
                            font: latin,
                            fontSize: 9,
                            color: fg,
                          ),
                        ),
                      ),

                      // جمع Cr
                      _bodyCell(
                        crFormatted,
                        font: latin,
                        align: pw.TextAlign.center,
                      ),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 12),

            // --------------------------------------------------
            // FOOTER
            // --------------------------------------------------
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Generated on: ${DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now())}',
                style: pw.TextStyle(
                  font: latin,
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
            ),
          ];
        },
      ),
    );

    return savePdf(pdf, 'last_credit_summary');
  }

  // ==========================================================
  // HEADER CELL
  // ==========================================================
  pw.Widget _headerCell(
      String text, {
        required pw.Font font,
        pw.TextAlign align = pw.TextAlign.left,
      }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: align,
          style: pw.TextStyle(
            font: font,
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
        ),
        textDirection: _dir(text),
      ),
    );
  }

  // ==========================================================
  // BODY CELL
  // ==========================================================
  pw.Widget _bodyCell(
      String text, {
        required pw.Font font,
        pw.TextAlign align = pw.TextAlign.left,
        PdfColor color = PdfColors.black,
      }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: 9,
          color: color,
        ),
        textDirection: _dir(text),
      ),
    );
  }
}
