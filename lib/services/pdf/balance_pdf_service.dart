// lib/services/pdf/balance_pdf_service.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../model/balance_row.dart';
import 'base_pdf_service.dart';

class BalancePdfService extends BasePdfService {
  BalancePdfService._();
  static final BalancePdfService instance = BalancePdfService._();

  late pw.Font urduFont;
  late pw.Font urduFontBold;

  static final NumberFormat _money = NumberFormat('#,##0.00');

  // ⚠️ DISPLAY ONLY (never use for logic)
  double _fixForDisplay(double v) =>
      v.abs() < 0.005 ? 0.0 : v;

  String _fmtMoney(double v) =>
      _money.format(_fixForDisplay(v));

  Future<void> _loadUrduFont() async {
    final regularData =
    await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');

    urduFont = pw.Font.ttf(regularData.buffer.asByteData());
    // Keep bold same unicode font to avoid broken Arabic shaping in faux bold.
    urduFontBold = urduFont;
  }

  bool _isRtl(String? s) {
    if (s == null || s.trim().isEmpty) return false;
    return RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
    ).hasMatch(s);
  }

  pw.TextDirection _dir(String v) =>
      _isRtl(v) ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  pw.Font _pickFont(
      String text,
      pw.Font latin,
      pw.Font latinBold,
      bool bold,
      ) {
    if (_isRtl(text)) return urduFont;
    return bold ? latinBold : latin;
  }

  Future<File> render({
    required List<String> currencies,
    required List<BalanceRow> rows,
  }) async {
    await _loadUrduFont();

    final pdf = pw.Document();
    final (latin, latinBold) = await createFonts();

    final deepBlue = PdfColor.fromInt(0xFF0B1E3A);
    final greenBg = PdfColor.fromInt(0xFF4CAF50);
    final redBg = PdfColor.fromInt(0xFFC62828);

    final pageFormat = PdfPageFormat(
      PdfPageFormat.cm * 29.7,
      PdfPageFormat.cm * 55,
      marginAll: 12,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        build: (_) => [
          buildHeader(
            title: 'Account Summary (All Currencies)',
            font: latin,
            fontBold: latinBold,
            titleColor: deepBlue,
          ),
          pw.SizedBox(height: 10),
          _buildTable(
            currencies: currencies,
            rows: rows,
            latin: latin,
            latinBold: latinBold,
            deepBlue: deepBlue,
            greenBg: greenBg,
            redBg: redBg,
          ),
        ],
      ),
    );

    return savePdf(pdf, 'balance_report');
  }

  pw.Widget _buildTable({
    required List<String> currencies,
    required List<BalanceRow> rows,
    required pw.Font latin,
    required pw.Font latinBold,
    required PdfColor deepBlue,
    required PdfColor greenBg,
    required PdfColor redBg,
  }) {
    final tableRows = <pw.TableRow>[];

    // Header
    tableRows.add(
      pw.TableRow(
        children: [
          _header('NAME', latinBold, deepBlue),
          ...currencies.map((c) => _header(c, latinBold, deepBlue)),
        ],
      ),
    );

    for (final row in rows) {
      tableRows.add(
        pw.TableRow(
          children: [
            _nameCell(row.name, latin, latinBold, deepBlue),
            ...currencies.map((c) {
              final value = row.byCurrency[c];

              // ✅ ONLY skip exact zero
              if (value == null || value == 0.0) {
                return pw.Container();
              }

              return _valueCell(
                value,
                latin,
                greenBg,
                redBg,
              );
            }),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(width: 0.3),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        for (int i = 0; i < currencies.length; i++)
          i + 1: const pw.FlexColumnWidth(1),
      },
      children: tableRows,
    );
  }

  pw.Widget _header(String text, pw.Font bold, PdfColor bg) {
    return pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textDirection: _dir(text),
        style: pw.TextStyle(font: bold, color: PdfColors.white),
      ),
    );
  }

  pw.Widget _nameCell(
      String name,
      pw.Font latin,
      pw.Font latinBold,
      PdfColor color,
      ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        name,
        textDirection: _dir(name),
        style: pw.TextStyle(
          font: _pickFont(name, latin, latinBold, true),
          color: color,
        ),
      ),
    );
  }

  pw.Widget _valueCell(
      double value,
      pw.Font latin,
      PdfColor green,
      PdfColor red,
      ) {
    final isCredit = value > 0;

    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.all(4),
      color: isCredit ? green : red,
      child: pw.Text(
        _fmtMoney(value),
        style: pw.TextStyle(
          font: latin,
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }
}
