// lib/services/pdf/base_pdf_service.dart
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../helpers/report_date_helper.dart';

abstract class BasePdfService {
  // ====== Visual constants (shared) ======
  static const double titleSize = 20;   // TITLE_SIZE
  static const double headerSize = 16;  // HEADER_SIZE
  static const double bodySize = 14;    // BODY_SIZE

  static const double cellPadV = 2.5;   // CELL_PAD_V
  static const double cellPadH = 3.0;   // CELL_PAD_H
  static const double headerPadV = 3.5; // HEADER_PAD_V
  static const double headerPadH = 3.0; // HEADER_PAD_H

  // Page margins (TOP, RIGHT, BOTTOM, LEFT)
  static const double marginTop = 6;
  static const double marginRight = 2;
  static const double marginBottom = 6;
  static const double marginLeft = 2;

  // Number formatter (0 decimals)
  final NumberFormat nf = NumberFormat.decimalPattern()
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = 0;

  static pw.Font? _unicodeRegular;
  static pw.Font? _unicodeBold;

  // Unicode-safe fonts for Urdu/Arabic/Pashto + Latin.
  Future<(pw.Font regular, pw.Font bold)> createFonts() async {
    _unicodeRegular ??= pw.Font.ttf(
      (await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'))
          .buffer
          .asByteData(),
    );

    // Keep bold same unicode font to avoid missing glyphs in bold text.
    _unicodeBold ??= _unicodeRegular;

    return (_unicodeRegular!, _unicodeBold!);
  }

  // Shared header (same as your _buildHeader)
  pw.Widget buildHeader({
    required String title,
    required pw.Font font,
    required pw.Font fontBold,
    PdfColor titleColor = PdfColors.black,
  }) {
    final today = ReportDateHelper.nowIso();

    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.zero,
              child: pw.Text(
                title,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: titleSize,
                  color: titleColor,
                ),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'Printed $today',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 10,
                ),
              ),
            ),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(),
            ),
          ],
        ),
      ],
    );
  }

  // Save helper
  Future<File> savePdf(pw.Document pdf, String baseName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$baseName.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
