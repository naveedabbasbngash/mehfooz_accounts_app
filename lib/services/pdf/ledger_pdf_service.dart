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

  // ------------------------------------------------------------
  // Load Urdu-compatible font (NotoSansArabic-Regular.ttf)
  // ------------------------------------------------------------
  Future<void> _loadUrduFont() async {
    final data =
    await rootBundle.load("assets/fonts/NotoSansArabic-Regular.ttf");
    urduFont = pw.Font.ttf(data.buffer.asByteData());
    urduFontBold = urduFont;
  }

  // ------------------------------------------------------------
  // RTL helpers (works for Urdu / Arabic / Pashto / Persian)
  // ------------------------------------------------------------
  bool _isRtl(String? s) {
    if (s == null || s.trim().isEmpty) return false;
    final rx = RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
    );
    return rx.hasMatch(s);
  }

  pw.TextDirection _dir(String text) =>
      _isRtl(text) ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  pw.Font _fontFor(
      String text,
      pw.Font latin,
      pw.Font latinBold,
      bool bold,
      ) {
    if (_isRtl(text)) {
      return bold ? urduFontBold : urduFont;
    }
    return bold ? latinBold : latin;
  }

  // ------------------------------------------------------------
  // MAIN ENTRY
  // ------------------------------------------------------------
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
    final greyLine = PdfColor.fromInt(0xFF969696);
    final subtleBg = PdfColor.fromInt(0xFFF7F9FC);
    final red = PdfColor.fromInt(0xFFC62828);
    final green = PdfColor.fromInt(0xFF4CAF50);
    final black = PdfColors.black;

    final nf = NumberFormat('#,##0');

    // Pre-compute totals like Kotlin
    int opening = result.openingBalanceCents;
    int sumDr = 0;
    int sumCr = 0;
    for (final r in result.rows) {
      sumDr += r.dr;
      sumCr += r.cr;
    }
    final closing = opening + sumCr - sumDr;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(
          BasePdfService.marginLeft,
          BasePdfService.marginTop,
          BasePdfService.marginRight,
          BasePdfService.marginBottom,
        ),
        build: (_) {
          final widgets = <pw.Widget>[];

          // ---------------- TOP "Printed Date" row ----------------
          widgets.add(
            _buildPrintedRow(
              latin: latin,
              latinBold: latinBold,
              deepBlue: deepBlue,
            ),
          );

          widgets.add(pw.SizedBox(height: 4));

          // ---------------- Name / Company (underline rows) ----------------
          widgets.add(
            _buildNameAddressBlock(
              accountName: accountName,
              officeName: officeName,
              latin: latin,
              latinBold: latinBold,
              deepBlue: deepBlue,
              greyLine: greyLine,
            ),
          );

          widgets.add(pw.SizedBox(height: 6));

          // ---------------- Opening bar (Currency + Opening) ----------------
          widgets.add(
            _buildOpeningBar(
              currency: currency,
              opening: opening,
              nf: nf,
              latin: latin,
              latinBold: latinBold,
              green: green,
              red: red,
              black: black,
            ),
          );

          widgets.add(pw.SizedBox(height: 4));

          // ---------------- Black separator line ----------------
          widgets.add(
            pw.Container(
              height: 2,
              color: black,
            ),
          );

          widgets.add(pw.SizedBox(height: 6));

          // ---------------- LEDGER TABLE ----------------
          widgets.add(
            _buildLedgerTable(
              rows: result.rows,
              opening: opening,
              latin: latin,
              latinBold: latinBold,
              deepBlue: deepBlue,
              greyLine: greyLine,
              subtleBg: subtleBg,
              red: red,
              green: green,
              nf: nf,
            ),
          );

          widgets.add(pw.SizedBox(height: 6));

          // ---------------- Closing & totals under table ----------------
          widgets.add(
            _buildTotalsAndClosingBar(
              opening: opening,
              sumDr: sumDr,
              sumCr: sumCr,
              closing: closing,
              nf: nf,
              latin: latin,
              latinBold: latinBold,
              green: green,
              red: red,
              black: black,
            ),
          );

          widgets.add(pw.SizedBox(height: 12));

          // ---------------- Signature + Period (small) ----------------
          widgets.add(
            _buildSignatureAndPeriod(
              periodText: periodText,
              latin: latin,
              latinBold: latinBold,
              deepBlue: deepBlue,
            ),
          );

          return widgets;
        },
      ),
    );

    return savePdf(pdf, "ledger_report");
  }

  // ------------------------------------------------------------
  // Printed date row (top right)
  // ------------------------------------------------------------
  pw.Widget _buildPrintedRow({
    required pw.Font latin,
    required pw.Font latinBold,
    required PdfColor deepBlue,
  }) {
    final printedDate = DateFormat('d/M/yyyy').format(DateTime.now());
    final text = 'Printed Date $printedDate';

    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          children: [
            pw.Container(), // empty left cell
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                text,
                textDirection: _dir(text),
                style: pw.TextStyle(
                  font: _fontFor(text, latin, latinBold, true),
                  fontSize: 8,
                  color: deepBlue,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // Name + Company (underline rows)
  // ------------------------------------------------------------
  pw.Widget _buildNameAddressBlock({
    required String accountName,
    required String officeName,
    required pw.Font latin,
    required pw.Font latinBold,
    required PdfColor deepBlue,
    required PdfColor greyLine,
  }) {
    pw.Table table = pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(0.12),
        1: pw.FlexColumnWidth(0.88),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [],
    );

    pw.Border underline = pw.Border(
      bottom: pw.BorderSide(color: greyLine, width: 1.2),
    );

    // Name row
    table.children.add(
      pw.TableRow(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 2),
            decoration: pw.BoxDecoration(border: underline),
            child: pw.Text(
              "Name:",
              style: pw.TextStyle(
                font: latinBold,
                fontSize: 12,
                color: deepBlue,
              ),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 2),
            decoration: pw.BoxDecoration(border: underline),
            child: pw.Text(
              accountName,
              textDirection: _dir(accountName),
              style: pw.TextStyle(
                font: _fontFor(accountName, latin, latinBold, true),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );

    // "Company" row (was Address in Kotlin; mapped to officeName)
    if (officeName.trim().isNotEmpty) {
      table.children.add(
        pw.TableRow(
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.only(top: 2, bottom: 2),
              decoration: pw.BoxDecoration(border: underline),
              child: pw.Text(
                "Company:",
                style: pw.TextStyle(
                  font: latinBold,
                  fontSize: 12,
                  color: deepBlue,
                ),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.only(top: 2, bottom: 2),
              decoration: pw.BoxDecoration(border: underline),
              child: pw.Text(
                officeName,
                textDirection: _dir(officeName),
                style: pw.TextStyle(
                  font: _fontFor(officeName, latin, latinBold, true),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return table;
  }

  // ------------------------------------------------------------
  // Opening bar (Currency + Opening Balance)
  // ------------------------------------------------------------
  pw.Widget _buildOpeningBar({
    required String currency,
    required int opening,
    required NumberFormat nf,
    required pw.Font latin,
    required pw.Font latinBold,
    required PdfColor green,
    required PdfColor red,
    required PdfColor black,
  }) {
    final isPositive = opening >= 0;
    final openingBg = isPositive ? green : red;
    final openingTextColor = isPositive ? black : PdfColors.white;

    final leftText = "Currency : $currency";
    final rightText = "Opening Balance : ${nf.format(opening)}";

    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          children: [
            // Currency (left)
            pw.Container(
              padding:
              const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
              child: pw.Text(
                leftText,
                textDirection: _dir(leftText),
                style: pw.TextStyle(
                  font: _fontFor(leftText, latin, latinBold, true),
                  fontSize: 9,
                  color: black,
                ),
              ),
            ),
            // Opening Balance (right chip)
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                padding:
                const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                decoration: pw.BoxDecoration(
                  color: openingBg,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  rightText,
                  textDirection: _dir(rightText),
                  style: pw.TextStyle(
                    font: _fontFor(rightText, latin, latinBold, true),
                    fontSize: 9,
                    color: openingTextColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // Ledger table (VNO | Date | Desc | Dr | Cr | Balance)
  // ------------------------------------------------------------
  pw.Widget _buildLedgerTable({
    required List<LedgerTxn> rows,
    required int opening,
    required pw.Font latin,
    required pw.Font latinBold,
    required PdfColor deepBlue,
    required PdfColor greyLine,
    required PdfColor subtleBg,
    required PdfColor red,
    required PdfColor green,
    required NumberFormat nf,
  }) {
    final dateFmt = DateFormat('d/M/yyyy');
    final cols = const <int, pw.FlexColumnWidth>{
      0: pw.FlexColumnWidth(0.10), // VNO
      1: pw.FlexColumnWidth(0.15), // Date
      2: pw.FlexColumnWidth(0.43), // Desc
      3: pw.FlexColumnWidth(0.11), // Dr
      4: pw.FlexColumnWidth(0.11), // Cr
      5: pw.FlexColumnWidth(0.10), // Balance
    };

    final table = pw.Table(
      columnWidths: cols,
      border: pw.TableBorder(
        left: pw.BorderSide(color: greyLine, width: 0.5),
        right: pw.BorderSide(color: greyLine, width: 0.5),
        top: pw.BorderSide(color: greyLine, width: 0.5),
        bottom: pw.BorderSide(color: greyLine, width: 0.5),
        horizontalInside: pw.BorderSide(color: greyLine, width: 0.25),
        verticalInside: pw.BorderSide(color: greyLine, width: 0.25),
      ),
      children: [],
    );

    // header cell (white text, black background, bottom black border)
    pw.Widget head(String text) {
      final isRtl = _isRtl(text);
      final fontToUse = isRtl ? urduFontBold : latinBold;

      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.black, width: 1.5),
          ),
        ),
        child: pw.Text(
          text,
          textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          style: pw.TextStyle(
            font: fontToUse,
            fontSize: 10,
            color: PdfColors.white,
          ),
        ),
      );
    }

    // header row
    table.children.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.black),
        children: [
          head("VNO"),
          head("Date"),
          head("Description"),
          head("Dr (بنام )"),
          head("Cr (جمع )"),
          head("Balance"),
        ],
      ),
    );

    // Running balance
    int running = opening;
    int rowIndex = 0;

    for (final t in rows) {
      final rowBg =
      (rowIndex++ % 2 == 0) ? PdfColors.white : subtleBg; // zebra rows
      running += (t.cr - t.dr);

      // Voucher color logic
      PdfColor vnoBg;
      PdfColor vnoTextColor;

      if (t.cr > 0 && t.dr == 0) {
        // pure credit
        vnoBg = green;
        vnoTextColor = PdfColors.white;
      } else if (t.dr > 0 && t.cr == 0) {
        // pure debit
        vnoBg = PdfColor.fromInt(0xFFFFFF96); // light yellow
        vnoTextColor = PdfColor.fromInt(0xFFC80000); // dark red
      } else {
        vnoBg = rowBg;
        vnoTextColor = PdfColors.black;
      }

      // Balance background
      final bool balPositive = running >= 0;
      final PdfColor balBg =
      balPositive ? PdfColor.fromInt(0xFF90EE90) : red;
      final PdfColor balTextColor =
      balPositive ? PdfColors.black : PdfColors.white;

      final dateStr = dateFmt.format(t.tDate);
      final descRaw = (t.description ?? "").trim();
      final desc =
      descRaw.length > 42 ? descRaw.substring(0, 42) : descRaw; // take(42)

      // Small helper for normal cells
      pw.Widget cell(
          String text, {
            bool bold = false,
            pw.TextAlign align = pw.TextAlign.left,
            PdfColor? bg,
            PdfColor? textColor,
          }) {
        final bgColor = bg ?? rowBg;
        final color = textColor ?? PdfColors.black;

        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          color: bgColor,
          child: pw.Text(
            text,
            textAlign: align,
            textDirection: _dir(text),
            style: pw.TextStyle(
              font: _fontFor(text, latin, latinBold, bold),
              fontSize: 9,
              color: color,
            ),
          ),
        );
      }

      // Build row
      table.children.add(
        pw.TableRow(
          children: [
            // VNO
            cell(
              t.voucherNo,
              bold: true,
              bg: vnoBg,
              textColor: vnoTextColor,
            ),

            // Date
            cell(dateStr),

            // Description (full RTL/LTR aware)
            cell(desc),

            // Dr
            cell(
              nf.format(t.dr),
              align: pw.TextAlign.right,
              textColor: t.dr > 0 ? red : PdfColors.black,
            ),

            // Cr
            cell(
              nf.format(t.cr),
              align: pw.TextAlign.right,
            ),

            // Balance
            cell(
              nf.format(running),
              bold: true,
              align: pw.TextAlign.right,
              bg: balBg,
              textColor: balTextColor,
            ),
          ],
        ),
      );
    }

    return table;
  }

  // ------------------------------------------------------------
  // Totals row & closing bar (under table)
  // ------------------------------------------------------------
  pw.Widget _buildTotalsAndClosingBar({
    required int opening,
    required int sumDr,
    required int sumCr,
    required int closing,
    required NumberFormat nf,
    required pw.Font latin,
    required pw.Font latinBold,
    required PdfColor green,
    required PdfColor red,
    required PdfColor black,
  }) {
    final cols = const <int, pw.FlexColumnWidth>{
      0: pw.FlexColumnWidth(0.10),
      1: pw.FlexColumnWidth(0.15),
      2: pw.FlexColumnWidth(0.43),
      3: pw.FlexColumnWidth(0.11),
      4: pw.FlexColumnWidth(0.11),
      5: pw.FlexColumnWidth(0.10),
    };

    // Totals row same layout as Kotlin (3 empty + Dr + Cr + Closing)
    final totalsTable = pw.Table(
      columnWidths: cols,
      children: [
        pw.TableRow(
          children: [
            // first 3 columns empty with top border
            _topBorderCell(),
            _topBorderCell(),
            _topBorderCell(),
            _topBorderCell(
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  nf.format(sumDr),
                  textDirection: _dir(nf.format(sumDr)),
                  style: pw.TextStyle(
                    font: _fontFor(nf.format(sumDr), latin, latinBold, true),
                    fontSize: 9,
                    color: black,
                  ),
                ),
              ),
            ),
            _topBorderCell(
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  nf.format(sumCr),
                  textDirection: _dir(nf.format(sumCr)),
                  style: pw.TextStyle(
                    font: _fontFor(nf.format(sumCr), latin, latinBold, true),
                    fontSize: 9,
                    color: black,
                  ),
                ),
              ),
            ),
            _topBorderCell(
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  nf.format(closing),
                  textDirection: _dir(nf.format(closing)),
                  style: pw.TextStyle(
                    font: _fontFor(nf.format(closing), latin, latinBold, true),
                    fontSize: 9,
                    color: black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    // Closing bar similar to Kotlin "Closing Balance : CR/DR ..."
    final isCr = closing >= 0;
    final absClosing = closing.abs();
    final closingBg = isCr ? green : red;
    final closingTextColor = isCr ? black : PdfColors.white;
    final crdrText = isCr ? "CR" : "DR -";
    final closingText =
        "Closing Balance : $crdrText ${nf.format(absClosing)}";

    final closingBar = pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          children: [
            pw.Container(), // empty left
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                padding:
                const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                decoration: pw.BoxDecoration(
                  color: closingBg,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  closingText,
                  textDirection: _dir(closingText),
                  style: pw.TextStyle(
                    font: _fontFor(closingText, latin, latinBold, true),
                    fontSize: 9,
                    color: closingTextColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        totalsTable,
        pw.SizedBox(height: 4),
        closingBar,
      ],
    );
  }

  pw.Widget _topBorderCell({pw.Widget? child}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.black, width: 1.5),
        ),
      ),
      child: child,
    );
  }

  // ------------------------------------------------------------
  // Signature + Period (bottom)
  // ------------------------------------------------------------
  pw.Widget _buildSignatureAndPeriod({
    required String periodText,
    required pw.Font latin,
    required pw.Font latinBold,
    required PdfColor deepBlue,
  }) {
    final children = <pw.Widget>[];

    // Signature row
    children.add(
      pw.Table(
        columnWidths: const {
          0: pw.FlexColumnWidth(0.3),
          1: pw.FlexColumnWidth(0.7),
        },
        children: [
          pw.TableRow(
            children: [
              pw.Container(
                child: pw.Text(
                  "Signature :",
                  style: pw.TextStyle(
                    font: latinBold,
                    fontSize: 10,
                    color: deepBlue,
                  ),
                ),
              ),
              pw.Container(),
            ],
          ),
        ],
      ),
    );

    // Period row (multi-language)
    if (periodText.trim().isNotEmpty) {
      children.add(pw.SizedBox(height: 4));
      children.add(
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(0.3),
            1: pw.FlexColumnWidth(0.7),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Container(
                  child: pw.Text(
                    periodText,
                    textDirection: _dir(periodText),
                    style: pw.TextStyle(
                      font: urduFont,         // ← ALWAYS use Urdu font
                      fontSize: 9,
                      color: deepBlue,
                    ),
                  ),
                ),
                pw.Container(),
              ],
            ),
          ],
        ),
      );
    }

    return pw.Column(children: children);
  }
}