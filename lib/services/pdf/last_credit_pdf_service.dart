import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../model/last_credit_row.dart';
import 'base_pdf_service.dart';

class LastCreditPdfService extends BasePdfService {
  LastCreditPdfService._();
  static final LastCreditPdfService instance = LastCreditPdfService._();

  Future<File> render({
    required String currencyName,
    required List<LastCreditRow> rows,
  }) async {
    final pdf = pw.Document();

    final (latin, latinBold) = createFonts();
    final deepBlue = PdfColor.fromInt(0xFF0B1E3A);

    final nf = NumberFormat('#,##0'); // comma, no decimals

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            // Header
            pw.Text(
              'Last Credit Summary',
              style: pw.TextStyle(
                font: latinBold,
                fontSize: 20,
                color: deepBlue,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Currency: $currencyName',
              style: pw.TextStyle(
                font: latin,
                fontSize: 11,
              ),
            ),
            pw.SizedBox(height: 16),

            // Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
              columnWidths: const {
                0: pw.FlexColumnWidth(3), // Customer
                1: pw.FlexColumnWidth(2), // Balance
                2: pw.FlexColumnWidth(2), // Date
                3: pw.FlexColumnWidth(2), // No Days
                4: pw.FlexColumnWidth(2), // جمع Cr
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _headerCell('Customer'),
                    _headerCell('Balance', align: pw.TextAlign.center),
                    _headerCell('Date', align: pw.TextAlign.center),
                    _headerCell('No Days', align: pw.TextAlign.center),
                    _headerCell('جمع Cr', align: pw.TextAlign.center),
                  ],
                ),

                // Data rows
                ...rows.map((row) {
                  // Balance (no /100, just like your Kotlin)
                  final balanceFormatted = nf.format(row.netBalance);

                  // Last credit amount
                  final crFormatted = nf.format(row.lastCreditAmount);

                  // Date: yyyy-MM-dd -> 10 chars max
                  String cleanDate;
                  try {
                    cleanDate = row.lastTransactionDate?.substring(0, 10) ?? '-';
                  } catch (_) {
                    cleanDate = row.lastTransactionDate ?? '-';
                  }

                  // Days + color logic (months = days/30.0)
                  final days = row.daysSinceLastCredit;
                  final months = days / 30.0;

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

                  final daysFormatted = nf.format(days);

                  return pw.TableRow(
                    children: [
                      // Customer
                      _bodyCell(row.customer, align: pw.TextAlign.left),
                      // Balance (red)
                      _bodyCell(
                        balanceFormatted,
                        align: pw.TextAlign.center,
                        color: PdfColors.red,
                      ),
                      // Date
                      _bodyCell(cleanDate, align: pw.TextAlign.center),
                      // No Days with background color
                      pw.Container(
                        color: bg,
                        padding:
                        const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          daysFormatted,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            font: latin,
                            fontSize: 9,
                            color: fg,
                          ),
                        ),
                      ),
                      // جمع Cr
                      _bodyCell(crFormatted, align: pw.TextAlign.center),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 12),
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

  pw.Widget _headerCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _bodyCell(
      String text, {
        pw.TextAlign align = pw.TextAlign.left,
        PdfColor color = PdfColors.black,
      }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          color: color,
        ),
      ),
    );
  }
}