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

  // Urdu font (works for Urdu, Arabic, Persian)
  late pw.Font urduFont;

  // -------- LOAD URDU FONT (NO STYLE CHANGE) --------
  Future<void> _loadUrduFont() async {
    final data =
    await rootBundle.load("assets/fonts/NotoSansArabic-Regular.ttf");
    urduFont = pw.Font.ttf(data.buffer.asByteData());
  }

  // -------- SMALL RTL CHECK --------
  bool _isRtl(String? s) {
    if (s == null || s.trim().isEmpty) return false;
    final r = RegExp(
        r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    return r.hasMatch(s);
  }

  pw.TextDirection _dir(String value) =>
      _isRtl(value) ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  // -------- Font selector --------
  pw.Font _pickFont(String text, pw.Font latin, pw.Font boldLatin, bool bold) {
    return _isRtl(text)
        ? urduFont // Urdu font for Urdu text
        : bold
        ? boldLatin
        : latin;
  }

  // ================================================================
  // MAIN RENDER — SAME LAYOUT AS YOUR OLD CODE
  // ================================================================
  Future<File> render({
    required String officeName,
    required List<PendingRow> rows,
    String title = 'Pending Amount',
  }) async {
    if (rows.isEmpty) throw StateError('No pending rows to render');

    await _loadUrduFont();

    final pdf = pw.Document();

    final (latinFont, latinBold) = createFonts();
    final deepBlue = PdfColor.fromInt(0xFF0B1E3A);
    final greyLine = PdfColor.fromInt(0xFFBEC3C8);
    final subtleBg = PdfColor.fromInt(0xFFF7F9FC);

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
          final widgets = <pw.Widget>[];

          widgets.add(
            _buildHeader(
              officeName: officeName,
              title: title,
              font: latinFont,
              fontBold: latinBold,
              deepBlue: deepBlue,
            ),
          );

          widgets.add(pw.SizedBox(height: 8));

          // Group by currency
          final grouped = <String, List<PendingRow>>{};
          for (final r in rows) {
            final key =
            r.currency.trim().isEmpty ? 'Unknown' : r.currency.trim();
            grouped.putIfAbsent(key, () => []).add(r);
          }

          final currencyKeys = grouped.keys.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

          for (final cur in currencyKeys) {
            widgets.add(
              pw.Text(
                'Currency: $cur',
                style: pw.TextStyle(
                  font: latinBold,
                  fontSize: 12,
                  color: deepBlue,
                ),
              ),
            );

            widgets.add(pw.SizedBox(height: 4));

            widgets.add(
              _buildCurrencyTable(
                rows: grouped[cur]!,
                latinFont: latinFont,
                latinBold: latinBold,
                deepBlue: deepBlue,
                greyLine: greyLine,
                subtleBg: subtleBg,
              ),
            );

            widgets.add(pw.SizedBox(height: 10));
          }

          return widgets;
        },
      ),
    );

    return savePdf(pdf, 'pending_report');
  }

  // ========================== HEADER (UNCHANGED) ==========================
  pw.Widget _buildHeader({
    required String officeName,
    required String title,
    required pw.Font font,
    required pw.Font fontBold,
    required PdfColor deepBlue,
  }) {
    final printed = 'Printed ${reportDateToday()}';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(1),
            1: pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Text(
                  officeName,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 12,
                    color: deepBlue,
                  ),
                ),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    printed,
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 10,
                      color: deepBlue,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            title,
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 18,
              color: deepBlue,
            ),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Container(height: 1.5, color: deepBlue),
        pw.SizedBox(height: 4),
      ],
    );
  }

  // ========================== TABLE (same layout + Urdu fix) ==========================
  pw.Widget _buildCurrencyTable({
    required List<PendingRow> rows,
    required pw.Font latinFont,
    required pw.Font latinBold,
    required PdfColor deepBlue,
    required PdfColor greyLine,
    required PdfColor subtleBg,
  }) {
    const cols = <double>[0.12, 0.12, 0.12, 0.12, 0.12, 0.12, 0.16, 0.16];

    final table = pw.Table(
      columnWidths: {
        for (var i = 0; i < cols.length; i++) i: pw.FlexColumnWidth(cols[i]),
      },
      border: pw.TableBorder(
        left: pw.BorderSide(color: greyLine, width: 0.5),
        right: pw.BorderSide(color: greyLine, width: 0.5),
        bottom: pw.BorderSide(color: greyLine, width: 0.5),
        top: pw.BorderSide(color: greyLine, width: 0.5),
      ),
      children: [],
    );

    // ----- Header -----
    pw.Widget head(String text) {
      return pw.Container(
        color: deepBlue,
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
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
          head('Date'),
          head('PD'),
          head('Msg#'),
          head('Sender'),
          head('Receiver'),
          head('P.Amount'),
          head('Paid'),
          head('Balance'),
        ],
      ),
    );

    int i = 0;
    int totalNotPaid = 0, totalPaid = 0, totalBalance = 0;

    final sorted = [...rows]
      ..sort((a, b) {
        final d = a.dateIso.compareTo(b.dateIso);
        return d != 0 ? d : (a.msg ?? '').compareTo(b.msg ?? '');
      });

    for (final r in sorted) {
      final bg = (i % 2 == 0) ? PdfColors.white : subtleBg;
      i++;

      totalNotPaid += r.notPaidAmount;
      totalPaid += r.paidAmount;
      totalBalance += r.balance;

      pw.Widget cell(String v,
          {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) {
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
            ),
          ),
        );
      }

      table.children.add(
        pw.TableRow(
          children: [
            cell(_formatDate(r.dateIso)),
            cell(r.pd ?? ''),
            cell(r.msg ?? ''),
            cell(r.sender ?? ''),
            cell(r.receiver ?? ''),
            cell(nf.format(r.notPaidAmount),
                bold: true, align: pw.TextAlign.right),
            cell(nf.format(r.paidAmount),
                bold: true, align: pw.TextAlign.right),
            cell(nf.format(r.balance),
                bold: true, align: pw.TextAlign.right),
          ],
        ),
      );
    }

    // ---- Totals (unchanged) ----
    final totalsTable = pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          children: [
            _totalsCell('Totals:', latinBold, deepBlue),
            _totalsCell('Not Paid: ${nf.format(totalNotPaid)}', latinBold,
                deepBlue),
            _totalsCell(
                'Paid: ${nf.format(totalPaid)}', latinBold, deepBlue),
            _totalsCell('Balance: ${nf.format(totalBalance)}', latinBold,
                deepBlue,
                align: pw.TextAlign.right),
          ],
        ),
      ],
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        table,
        pw.SizedBox(height: 4),
        totalsTable,
      ],
    );
  }

  pw.Widget _totalsCell(String text, pw.Font bold, PdfColor deepBlue,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.Text(
        text,
        textDirection: _dir(text),
        textAlign: align,
        style: pw.TextStyle(
          font: bold,
          fontSize: 11,
          color: deepBlue,
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final p = iso.split('-');
      return '${p[2]}/${p[1]}/${p[0]}';
    } catch (_) {
      return iso;
    }
  }

  String reportDateToday() {
    final n = DateTime.now();
    return '${n.day}/${n.month}/${n.year}';
  }
}