// lib/services/pdf/base_pdf_service.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../helpers/report_date_helper.dart';

abstract class BasePdfService {
  // ====== Visual constants ======
  static const double titleSize = 20;
  static const double headerSize = 16;
  static const double bodySize = 14;

  static const double cellPadV = 2.5;
  static const double cellPadH = 3.0;
  static const double headerPadV = 3.5;
  static const double headerPadH = 3.0;

  // Number formatter
  final NumberFormat nf = NumberFormat.decimalPattern()
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = 0;

  // 🔥 FIXED: Correct asset-based font loading
  static pw.Font? _latin;
  static pw.Font? _latinBold;

  static Future<void> loadFonts() async {
    _latin ??= pw.Font.ttf(
      (await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
          .buffer
          .asByteData(),
    );

    _latinBold ??= pw.Font.ttf(
      (await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'))
          .buffer
          .asByteData(),
    );
  }

  (pw.Font regular, pw.Font bold) createFonts() {
    if (_latin == null || _latinBold == null) {
      throw StateError('Fonts not loaded. Call BasePdfService.loadFonts() first.');
    }
    return (_latin!, _latinBold!);
  }

  pw.Widget buildHeader({
    required String title,
    required pw.Font font,
    required pw.Font fontBold,
    PdfColor titleColor = PdfColors.black, // ✅ ADD THIS

  }) {
    final today = ReportDateHelper.nowIso();

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: titleSize)),
        pw.Text('Printed $today', style: pw.TextStyle(font: font, fontSize: 10)),
      ],
    );
  }

  Future<File> savePdf(pw.Document pdf, String baseName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$baseName.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}