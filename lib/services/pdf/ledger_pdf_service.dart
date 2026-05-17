// lib/services/pdf/ledger_pdf_service.dart

import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../model/ledger_models.dart';
import 'base_pdf_service.dart';

class LedgerPdfProgress {
  final String stage;
  final String message;
  final double progress;
  final int pagesDone;
  final int pagesTotal;
  final bool estimated;

  const LedgerPdfProgress({
    required this.stage,
    required this.message,
    required this.progress,
    required this.pagesDone,
    required this.pagesTotal,
    required this.estimated,
  });

  factory LedgerPdfProgress.fromMap(Map<dynamic, dynamic> data) {
    int toInt(dynamic v) => (v is num) ? v.toInt() : 0;
    double toDouble(dynamic v) => (v is num) ? v.toDouble() : 0.0;
    String toStr(dynamic v) => v?.toString() ?? "";

    return LedgerPdfProgress(
      stage: toStr(data['stage']),
      message: toStr(data['message']),
      progress: toDouble(data['progress']).clamp(0.0, 1.0),
      pagesDone: toInt(data['pagesDone']),
      pagesTotal: toInt(data['pagesTotal']),
      estimated: data['estimated'] == true,
    );
  }
}

class LedgerPdfService extends BasePdfService {
  LedgerPdfService._();
  static final LedgerPdfService instance = LedgerPdfService._();
  static final NumberFormat _wholeFmt = NumberFormat('#,##0');
  static final NumberFormat _decimalFmt = NumberFormat('#,##0.######');

  late pw.Font urduFont;
  late pw.Font urduFontBold;

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

  pw.Font _fontFor(String text, pw.Font latin, pw.Font latinBold, bool bold) {
    if (_isRtl(text)) {
      return bold ? urduFontBold : urduFont;
    }
    return bold ? latinBold : latin;
  }

  String _formatSmartNumber(num value) {
    final d = value.toDouble();
    final safe = d.abs() < 0.0000005 ? 0.0 : d;
    final whole = safe.truncateToDouble();
    final isWhole = (safe - whole).abs() < 0.0000005;
    return isWhole ? _wholeFmt.format(safe) : _decimalFmt.format(safe);
  }

  String _formatSmartNullable(num? value) {
    if (value == null) return '';
    return _formatSmartNumber(value);
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
    String reportTitle = 'Ledger Report',
    bool includeProductColumns = false,
    ValueChanged<LedgerPdfProgress>? onProgress,
  }) async {
    final totalSw = Stopwatch()..start();
    debugPrint(
      "[LedgerPerf][PDF] render:start rows=${result.rows.length} "
      "account='$accountName' currency='$currency'",
    );

    final prepSw = Stopwatch()..start();
    final fontData = await rootBundle.load(
      "assets/fonts/NotoSansArabic-Regular.ttf",
    );
    final ReceivePort? progressPort = onProgress != null ? ReceivePort() : null;
    final progressSub = progressPort?.listen((dynamic event) {
      if (event is Map) {
        onProgress?.call(LedgerPdfProgress.fromMap(event));
      }
    });

    final payload = <String, dynamic>{
      'officeName': officeName,
      'accountName': accountName,
      'currency': currency,
      'periodText': periodText,
      'reportTitle': reportTitle,
      'includeProductColumns': includeProductColumns,
      'fastMode': result.rows.length > 2500,
      'openingBalance': result.openingBalance,
      'fontBytes': fontData.buffer.asUint8List(),
      'rows': result.rows
          .map(
            (r) => <String, dynamic>{
              'voucherNo': r.voucherNo,
              'tDate': r.tDate.toIso8601String(),
              'description': r.description,
              'quality': r.quality,
              'rate': r.rate,
              'weight': r.weight,
              'dr': r.dr,
              'cr': r.cr,
            },
          )
          .toList(),
      if (progressPort != null) 'progressPort': progressPort.sendPort,
    };
    prepSw.stop();
    debugPrint(
      "[LedgerPerf][PDF] payload:done elapsedMs=${prepSw.elapsedMilliseconds}",
    );

    final buildSw = Stopwatch()..start();
    Uint8List pdfBytes;
    try {
      pdfBytes = await compute(_buildLedgerPdfBytesInIsolate, payload);
    } finally {
      await progressSub?.cancel();
      progressPort?.close();
    }
    buildSw.stop();
    debugPrint(
      "[LedgerPerf][PDF] isolateBuild:done bytes=${pdfBytes.length} "
      "elapsedMs=${buildSw.elapsedMilliseconds}",
    );

    final saveSw = Stopwatch()..start();
    final dir = Directory.systemTemp;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/ledger_report_$ts.pdf');
    await file.writeAsBytes(pdfBytes, flush: true);
    saveSw.stop();
    totalSw.stop();
    debugPrint(
      "[LedgerPerf][PDF] render:done path=${file.path} "
      "saveElapsedMs=${saveSw.elapsedMilliseconds} totalElapsedMs=${totalSw.elapsedMilliseconds}",
    );
    return file;
  }

  // ------------------------------------------------------------
  // Main title
  // ------------------------------------------------------------
  pw.Widget _buildMainHeader({
    required String title,
    required pw.Font latinBold,
    required PdfColor deepBlue,
  }) {
    return pw.Center(
      child: pw.Text(
        title,
        textDirection: _dir(title),
        style: pw.TextStyle(
          font: _fontFor(title, latinBold, latinBold, true),
          fontSize: 17,
          fontWeight: pw.FontWeight.bold,
          color: deepBlue,
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Name + Company (underline rows)
  // ------------------------------------------------------------
  pw.Widget _buildNameAddressBlock({
    required String accountName,
    required String officeName, // ← can stay (API compatibility)
    required String generatedText,
    required pw.Font latin,
    required pw.Font latinBold,
    required PdfColor deepBlue,
    required PdfColor greyLine,
  }) {
    final table = pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(0.12),
        1: pw.FlexColumnWidth(0.55),
        2: pw.FlexColumnWidth(0.33),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 1),
              child: pw.Text(
                "Name:",
                style: pw.TextStyle(
                  font: latinBold,
                  fontSize: 12,
                  color: deepBlue,
                ),
                maxLines: 1,
                softWrap: false,
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 1),
              child: pw.Text(
                accountName,
                textDirection: _dir(accountName),
                style: pw.TextStyle(
                  font: _fontFor(accountName, latin, latinBold, true),
                  fontSize: 11,
                ),
                maxLines: 1,
                softWrap: false,
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 1),
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  generatedText,
                  textDirection: _dir(generatedText),
                  style: pw.TextStyle(
                    font: _fontFor(generatedText, latin, latinBold, true),
                    fontSize: 7,
                    color: deepBlue,
                  ),
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: greyLine, width: 1.2)),
      ),
      child: table,
    );
  }

  // ------------------------------------------------------------
  // Opening bar (Currency + Opening Balance)
  // ------------------------------------------------------------
  pw.Widget _buildOpeningBar({
    required String currency,
    required double opening, // ✅ FIXED
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
    final rightText = "Opening Balance : ${_formatSmartNumber(opening)}";

    return pw.Table(
      columnWidths: const {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(1)},
      children: [
        pw.TableRow(
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 2,
                horizontal: 2,
              ),
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
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 2,
                  horizontal: 6,
                ),
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
    required double opening, // ✅ changed from int → double
    required bool includeProductColumns,
    required pw.Font latin,
    required pw.Font latinBold,
    required PdfColor deepBlue,
    required PdfColor greyLine,
    required PdfColor subtleBg,
    required PdfColor red,
    required PdfColor green,
  }) {
    final dateFmt = DateFormat('d/M/yyyy');

    final cols = includeProductColumns
        ? const <int, pw.FlexColumnWidth>{
            0: pw.FlexColumnWidth(0.10), // VNO
            1: pw.FlexColumnWidth(0.10), // Date
            2: pw.FlexColumnWidth(0.11), // Quality
            3: pw.FlexColumnWidth(0.10), // Weight
            4: pw.FlexColumnWidth(0.09), // Rate
            5: pw.FlexColumnWidth(0.25), // Description
            6: pw.FlexColumnWidth(0.08), // Dr
            7: pw.FlexColumnWidth(0.08), // Cr
            8: pw.FlexColumnWidth(0.12), // Balance
          }
        : const <int, pw.FlexColumnWidth>{
            0: pw.FlexColumnWidth(0.10), // VNO
            1: pw.FlexColumnWidth(0.11), // Date
            2: pw.FlexColumnWidth(0.45), // Desc
            3: pw.FlexColumnWidth(0.11), // Dr
            4: pw.FlexColumnWidth(0.11), // Cr
            5: pw.FlexColumnWidth(0.12), // Balance
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

    // ------------------------------------------------------------
    // Header cell
    // ------------------------------------------------------------
    pw.Widget head(
      String text, {
      pw.TextAlign align = pw.TextAlign.left,
      double hPad = 4,
    }) {
      final isRtl = _isRtl(text);
      final fontToUse = isRtl ? urduFontBold : latinBold;

      return pw.Container(
        padding: pw.EdgeInsets.symmetric(vertical: 5, horizontal: hPad),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.black, width: 1.5),
          ),
        ),
        child: pw.Text(
          text,
          textAlign: align,
          textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          style: pw.TextStyle(
            font: fontToUse,
            fontSize: 10,
            color: PdfColors.white,
          ),
        ),
      );
    }

    // ------------------------------------------------------------
    // Header row
    // ------------------------------------------------------------
    table.children.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.black),
        children: includeProductColumns
            ? [
                head("VNO", align: pw.TextAlign.center),
                head("Date", align: pw.TextAlign.center, hPad: 1),
                head("Quality", align: pw.TextAlign.center, hPad: 2),
                head("Weight", align: pw.TextAlign.center, hPad: 2),
                head("Rate", align: pw.TextAlign.center, hPad: 2),
                head("Description"),
                head("Dr", align: pw.TextAlign.center),
                head("Cr", align: pw.TextAlign.center),
                head("Balance", align: pw.TextAlign.center),
              ]
            : [
                head("VNO"),
                head("Date", align: pw.TextAlign.center, hPad: 1),
                head("Description"),
                head("Dr", align: pw.TextAlign.center),
                head("Cr", align: pw.TextAlign.center),
                head("Balance", align: pw.TextAlign.center),
              ],
      ),
    );

    // ------------------------------------------------------------
    // Running balance (DOUBLE ✅)
    // ------------------------------------------------------------
    double running = opening;
    int rowIndex = 0;

    for (final t in rows) {
      final rowBg = (rowIndex++ % 2 == 0) ? PdfColors.white : subtleBg;

      final double dr = t.dr.toDouble();
      final double cr = t.cr.toDouble();

      running += (cr - dr);

      // Voucher color logic
      PdfColor vnoBg;
      PdfColor vnoTextColor;

      if (cr > 0 && dr == 0) {
        vnoBg = green;
        vnoTextColor = PdfColors.white;
      } else if (dr > 0 && cr == 0) {
        vnoBg = PdfColor.fromInt(0xFFFFFF96);
        vnoTextColor = PdfColor.fromInt(0xFFC80000);
      } else {
        vnoBg = rowBg;
        vnoTextColor = PdfColors.black;
      }

      // Balance background
      final bool balPositive = running >= 0;
      final PdfColor balBg = balPositive ? PdfColor.fromInt(0xFF90EE90) : red;
      final PdfColor balTextColor = balPositive
          ? PdfColors.black
          : PdfColors.white;

      final dateStr = dateFmt.format(t.tDate);
      final descRaw = t.description.trim();
      final descMax = includeProductColumns ? 24 : 42;
      final desc = descRaw.length > descMax
          ? descRaw.substring(0, descMax)
          : descRaw;
      final quality = t.quality.trim();
      final qualityText = quality.length > 12
          ? quality.substring(0, 12)
          : quality;
      final weightValue = (includeProductColumns && t.weight != null)
          ? ((cr > 0 && dr == 0) ? -t.weight!.abs() : t.weight!.abs())
          : t.weight;
      final weightText = _formatSmartNullable(weightValue);
      final rateText = _formatSmartNullable(t.rate);

      // ------------------------------------------------------------
      // Cell helper
      // ------------------------------------------------------------
      pw.Widget cell(
        String text, {
        bool bold = false,
        pw.TextAlign align = pw.TextAlign.left,
        PdfColor? bg,
        PdfColor? textColor,
        double hPad = 4,
      }) {
        return pw.Container(
          padding: pw.EdgeInsets.symmetric(vertical: 4, horizontal: hPad),
          color: bg ?? rowBg,
          child: pw.Text(
            text,
            textAlign: align,
            textDirection: _dir(text),
            style: pw.TextStyle(
              font: _fontFor(text, latin, latinBold, bold),
              fontSize: 9,
              color: textColor ?? PdfColors.black,
            ),
          ),
        );
      }

      // ------------------------------------------------------------
      // Row
      // ------------------------------------------------------------
      table.children.add(
        pw.TableRow(
          children: includeProductColumns
              ? [
                  cell(
                    t.voucherNo,
                    bold: true,
                    align: pw.TextAlign.center,
                    bg: vnoBg,
                    textColor: vnoTextColor,
                  ),
                  cell(dateStr, align: pw.TextAlign.center, hPad: 1),
                  cell(qualityText, align: pw.TextAlign.center, hPad: 2),
                  cell(weightText, align: pw.TextAlign.center, hPad: 2),
                  cell(rateText, align: pw.TextAlign.center, hPad: 2),
                  cell(desc),
                  cell(
                    _formatSmartNumber(dr),
                    align: pw.TextAlign.center,
                    textColor: dr > 0 ? red : PdfColors.black,
                  ),
                  cell(_formatSmartNumber(cr), align: pw.TextAlign.center),
                  cell(
                    _formatSmartNumber(running),
                    bold: true,
                    align: pw.TextAlign.center,
                    bg: balBg,
                    textColor: balTextColor,
                  ),
                ]
              : [
                  cell(
                    t.voucherNo,
                    bold: true,
                    bg: vnoBg,
                    textColor: vnoTextColor,
                  ),
                  cell(dateStr, align: pw.TextAlign.center, hPad: 1),
                  cell(desc),
                  cell(
                    _formatSmartNumber(dr),
                    align: pw.TextAlign.center,
                    textColor: dr > 0 ? red : PdfColors.black,
                  ),
                  cell(_formatSmartNumber(cr), align: pw.TextAlign.center),
                  cell(
                    _formatSmartNumber(running),
                    bold: true,
                    align: pw.TextAlign.center,
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
  // Fast mode for large ranges
  // Keeps the same table styling, but chunks rows to avoid
  // one giant table layout pass on very large datasets.
  // ------------------------------------------------------------
  List<pw.Widget> _buildLedgerTableSections({
    required List<LedgerTxn> rows,
    required double opening,
    required bool includeProductColumns,
    required pw.Font latin,
    required pw.Font latinBold,
    required PdfColor deepBlue,
    required PdfColor greyLine,
    required PdfColor subtleBg,
    required PdfColor red,
    required PdfColor green,
    void Function(int processedRows, int totalRows)? onChunkBuilt,
  }) {
    const fastModeThreshold = 2500;
    const chunkSize = 36;

    if (rows.length <= fastModeThreshold) {
      return [
        _buildLedgerTable(
          rows: rows,
          opening: opening,
          includeProductColumns: includeProductColumns,
          latin: latin,
          latinBold: latinBold,
          deepBlue: deepBlue,
          greyLine: greyLine,
          subtleBg: subtleBg,
          red: red,
          green: green,
        ),
      ];
    }

    final widgets = <pw.Widget>[];
    double runningOpening = opening;

    for (int start = 0; start < rows.length; start += chunkSize) {
      final end = (start + chunkSize < rows.length)
          ? start + chunkSize
          : rows.length;
      final chunk = rows.sublist(start, end);

      widgets.add(
        _buildLedgerTable(
          rows: chunk,
          opening: runningOpening,
          includeProductColumns: includeProductColumns,
          latin: latin,
          latinBold: latinBold,
          deepBlue: deepBlue,
          greyLine: greyLine,
          subtleBg: subtleBg,
          red: red,
          green: green,
        ),
      );
      onChunkBuilt?.call(end, rows.length);

      if (end < rows.length) {
        widgets.add(pw.SizedBox(height: 6));
      }

      for (final t in chunk) {
        runningOpening += t.cr - t.dr;
      }
    }

    return widgets;
  }

  // ------------------------------------------------------------
  // Totals row & closing bar (under table)
  // ------------------------------------------------------------
  pw.Widget _buildTotalsAndClosingBar({
    required double opening,
    required double sumDr,
    required double sumCr,
    required double closing,
    required bool includeProductColumns,
    required pw.Font latin,
    required pw.Font latinBold,
    required PdfColor green,
    required PdfColor red,
    required PdfColor black,
  }) {
    final cols = includeProductColumns
        ? const <int, pw.FlexColumnWidth>{
            0: pw.FlexColumnWidth(0.10),
            1: pw.FlexColumnWidth(0.10),
            2: pw.FlexColumnWidth(0.10),
            3: pw.FlexColumnWidth(0.11),
            4: pw.FlexColumnWidth(0.09),
            5: pw.FlexColumnWidth(0.25),
            6: pw.FlexColumnWidth(0.08),
            7: pw.FlexColumnWidth(0.08),
            8: pw.FlexColumnWidth(0.12),
          }
        : const <int, pw.FlexColumnWidth>{
            0: pw.FlexColumnWidth(0.10),
            1: pw.FlexColumnWidth(0.11),
            2: pw.FlexColumnWidth(0.45),
            3: pw.FlexColumnWidth(0.11),
            4: pw.FlexColumnWidth(0.11),
            5: pw.FlexColumnWidth(0.12),
          };

    // ------------------------------------------------------------
    // TOTALS ROW (Dr | Cr | Closing)
    // ------------------------------------------------------------
    final totalsTable = pw.Table(
      columnWidths: cols,
      children: [
        pw.TableRow(
          children: includeProductColumns
              ? [
                  _topBorderCell(),
                  _topBorderCell(),
                  _topBorderCell(),
                  _topBorderCell(),
                  _topBorderCell(),
                  _topBorderCell(),
                  _topBorderCell(
                    child: pw.Align(
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        _formatSmartNumber(sumDr),
                        textDirection: _dir(_formatSmartNumber(sumDr)),
                        style: pw.TextStyle(
                          font: _fontFor(
                            _formatSmartNumber(sumDr),
                            latin,
                            latinBold,
                            true,
                          ),
                          fontSize: 9,
                          color: black,
                        ),
                      ),
                    ),
                  ),
                  _topBorderCell(
                    child: pw.Align(
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        _formatSmartNumber(sumCr),
                        textDirection: _dir(_formatSmartNumber(sumCr)),
                        style: pw.TextStyle(
                          font: _fontFor(
                            _formatSmartNumber(sumCr),
                            latin,
                            latinBold,
                            true,
                          ),
                          fontSize: 9,
                          color: black,
                        ),
                      ),
                    ),
                  ),
                  _topBorderCell(
                    child: pw.Align(
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        _formatSmartNumber(closing),
                        textDirection: _dir(_formatSmartNumber(closing)),
                        style: pw.TextStyle(
                          font: _fontFor(
                            _formatSmartNumber(closing),
                            latin,
                            latinBold,
                            true,
                          ),
                          fontSize: 9,
                          color: black,
                        ),
                      ),
                    ),
                  ),
                ]
              : [
                  _topBorderCell(),
                  _topBorderCell(),
                  _topBorderCell(),

                  // Total Dr
                  _topBorderCell(
                    child: pw.Align(
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        _formatSmartNumber(sumDr),
                        textDirection: _dir(_formatSmartNumber(sumDr)),
                        style: pw.TextStyle(
                          font: _fontFor(
                            _formatSmartNumber(sumDr),
                            latin,
                            latinBold,
                            true,
                          ),
                          fontSize: 9,
                          color: black,
                        ),
                      ),
                    ),
                  ),

                  // Total Cr
                  _topBorderCell(
                    child: pw.Align(
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        _formatSmartNumber(sumCr),
                        textDirection: _dir(_formatSmartNumber(sumCr)),
                        style: pw.TextStyle(
                          font: _fontFor(
                            _formatSmartNumber(sumCr),
                            latin,
                            latinBold,
                            true,
                          ),
                          fontSize: 9,
                          color: black,
                        ),
                      ),
                    ),
                  ),

                  // Closing
                  _topBorderCell(
                    child: pw.Align(
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        _formatSmartNumber(closing),
                        textDirection: _dir(_formatSmartNumber(closing)),
                        style: pw.TextStyle(
                          font: _fontFor(
                            _formatSmartNumber(closing),
                            latin,
                            latinBold,
                            true,
                          ),
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

    // ------------------------------------------------------------
    // CLOSING BALANCE BAR (CR / DR)
    // ------------------------------------------------------------
    final bool isCr = closing >= 0;
    final double absClosing = closing.abs() < 0.005 ? 0.0 : closing.abs();

    final PdfColor closingBg = isCr ? green : red;
    final PdfColor closingTextColor = isCr ? black : PdfColors.white;

    final String crdrText = isCr ? "CR" : "DR";
    final String closingText =
        "Closing Balance : $crdrText ${_formatSmartNumber(absClosing)}";

    final closingBar = pw.Table(
      columnWidths: const {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(1)},
      children: [
        pw.TableRow(
          children: [
            pw.Container(),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 2,
                  horizontal: 6,
                ),
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
      children: [totalsTable, pw.SizedBox(height: 4), closingBar],
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
                      font: urduFont, // ← ALWAYS use Urdu font
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

Future<Uint8List> _buildLedgerPdfBytesInIsolate(
  Map<String, dynamic> payload,
) async {
  final totalSw = Stopwatch()..start();
  final officeName = (payload['officeName'] as String?) ?? '';
  final accountName = (payload['accountName'] as String?) ?? '';
  final currency = (payload['currency'] as String?) ?? '';
  final periodText = (payload['periodText'] as String?) ?? '';
  final reportTitle =
      (payload['reportTitle'] as String?)?.trim().isNotEmpty == true
      ? (payload['reportTitle'] as String).trim()
      : 'Ledger Report';
  final includeProductColumns =
      (payload['includeProductColumns'] as bool?) ?? false;
  final fastMode = (payload['fastMode'] as bool?) ?? false;
  final opening = (payload['openingBalance'] as num?)?.toDouble() ?? 0.0;
  final fontBytes = payload['fontBytes'] as Uint8List;
  final SendPort? progressPort = payload['progressPort'] as SendPort?;
  final rawRows = (payload['rows'] as List).cast<Map>();
  const rowsPerPageEstimate = 28;
  int safeMax(int a, int b) => a > b ? a : b;
  final estimatedTotalPages = safeMax(
    1,
    (rawRows.length / rowsPerPageEstimate).ceil(),
  );

  void emitProgress({
    required String stage,
    required String message,
    required double progress,
    required int pagesDone,
    required int pagesTotal,
    bool estimated = true,
  }) {
    progressPort?.send({
      'stage': stage,
      'message': message,
      'progress': progress.clamp(0.0, 1.0),
      'pagesDone': pagesDone,
      'pagesTotal': pagesTotal,
      'estimated': estimated,
    });
  }

  emitProgress(
    stage: 'prepare',
    message: 'Preparing PDF data...',
    progress: 0.08,
    pagesDone: 0,
    pagesTotal: estimatedTotalPages,
  );

  debugPrint(
    "[LedgerPerf][PDF:Isolate] start rawRows=${rawRows.length} "
    "account='$accountName' currency='$currency' fastMode=$fastMode",
  );

  final mapSw = Stopwatch()..start();
  final rows = rawRows.map((m) {
    final row = Map<String, dynamic>.from(m.cast<String, dynamic>());
    String toStr(dynamic v) => v?.toString() ?? '';
    double toDouble(dynamic v) => (v is num) ? v.toDouble() : 0.0;
    double? toDoubleOrNull(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return LedgerTxn(
      voucherNo: toStr(row['voucherNo']),
      tDate: DateTime.tryParse(toStr(row['tDate'])) ?? DateTime.now(),
      description: toStr(row['description']),
      quality: toStr(row['quality']),
      rate: toDoubleOrNull(row['rate']),
      weight: toDoubleOrNull(row['weight']),
      dr: toDouble(row['dr']),
      cr: toDouble(row['cr']),
    );
  }).toList();
  mapSw.stop();
  emitProgress(
    stage: 'prepare',
    message: 'Preparing rows...',
    progress: 0.18,
    pagesDone: 0,
    pagesTotal: estimatedTotalPages,
  );
  debugPrint(
    "[LedgerPerf][PDF:Isolate] rowMap:done count=${rows.length} "
    "elapsedMs=${mapSw.elapsedMilliseconds}",
  );

  final result = LedgerResult(openingBalance: opening, rows: rows);
  final isLargeRange = result.rows.length > 2500;
  emitProgress(
    stage: 'layout',
    message: isLargeRange ? 'Building ledger pages...' : 'Building pages...',
    progress: 0.24,
    pagesDone: 0,
    pagesTotal: estimatedTotalPages,
  );
  debugPrint(
    "[LedgerPerf][PDF:Isolate] mode=${isLargeRange ? 'fast-large-range' : 'normal'} "
    "rows=${result.rows.length}",
  );

  final fontSw = Stopwatch()..start();
  final service = LedgerPdfService._();
  final fontData = fontBytes.buffer.asByteData(
    fontBytes.offsetInBytes,
    fontBytes.lengthInBytes,
  );
  final unicodeFont = pw.Font.ttf(fontData);
  service.urduFont = unicodeFont;
  service.urduFontBold = unicodeFont;
  final latin = unicodeFont;
  final latinBold = unicodeFont;
  fontSw.stop();
  debugPrint(
    "[LedgerPerf][PDF:Isolate] fontInit:done elapsedMs=${fontSw.elapsedMilliseconds}",
  );

  final buildSw = Stopwatch()..start();
  final pdf = fastMode ? pw.Document(compress: false) : pw.Document();
  debugPrint("[LedgerPerf][PDF:Isolate] docConfig compress=${!fastMode}");

  final deepBlue = PdfColor.fromInt(0xFF0B1E3A);
  final greyLine = PdfColor.fromInt(0xFF969696);
  final subtleBg = PdfColor.fromInt(0xFFF7F9FC);
  final red = PdfColor.fromInt(0xFFC62828);
  final green = PdfColor.fromInt(0xFF4CAF50);
  final black = PdfColors.black;

  double sumDr = 0.0;
  double sumCr = 0.0;
  for (final r in result.rows) {
    sumDr += r.dr.toDouble();
    sumCr += r.cr.toDouble();
  }
  final closing = opening + sumCr - sumDr;
  final generatedText =
      'Generated Date ${DateFormat('d/M/yyyy hh:mm a').format(DateTime.now())}';

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(
          BasePdfService.marginLeft,
          BasePdfService.marginTop,
          BasePdfService.marginRight,
          BasePdfService.marginBottom,
        ),
        buildForeground: (_) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 95),
            child: pw.Center(
              child: pw.Opacity(
                opacity: 0.10,
                child: pw.Transform.rotateBox(
                  angle: 0.78,
                  child: pw.Text(
                    'Mahfooz Accounts',
                    textAlign: pw.TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    style: pw.TextStyle(
                      font: latinBold,
                      fontSize: 34,
                      color: PdfColor.fromInt(0xFF5F6E80),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      maxPages: 5000,
      build: (_) {
        final widgets = <pw.Widget>[];

        widgets.add(
          service._buildMainHeader(
            title: reportTitle,
            latinBold: latinBold,
            deepBlue: deepBlue,
          ),
        );
        widgets.add(pw.SizedBox(height: 1));

        widgets.add(
          service._buildNameAddressBlock(
            accountName: accountName,
            officeName: officeName,
            generatedText: generatedText,
            latin: latin,
            latinBold: latinBold,
            deepBlue: deepBlue,
            greyLine: greyLine,
          ),
        );

        widgets.add(pw.SizedBox(height: 1));

        widgets.add(
          service._buildOpeningBar(
            currency: currency,
            opening: opening,
            latin: latin,
            latinBold: latinBold,
            green: green,
            red: red,
            black: black,
          ),
        );

        widgets.add(pw.SizedBox(height: 4));
        widgets.add(pw.Container(height: 2, color: black));
        widgets.add(pw.SizedBox(height: 6));

        widgets.addAll(
          service._buildLedgerTableSections(
            rows: result.rows,
            opening: opening,
            includeProductColumns: includeProductColumns,
            latin: latin,
            latinBold: latinBold,
            deepBlue: deepBlue,
            greyLine: greyLine,
            subtleBg: subtleBg,
            red: red,
            green: green,
            onChunkBuilt: (processedRows, totalRows) {
              final ratio = totalRows == 0 ? 0.0 : processedRows / totalRows;
              final pagesDone = (ratio * estimatedTotalPages).floor().clamp(
                0,
                estimatedTotalPages,
              );
              emitProgress(
                stage: 'layout',
                message: 'Building pages ($pagesDone/$estimatedTotalPages)...',
                progress: 0.24 + (0.58 * ratio),
                pagesDone: pagesDone,
                pagesTotal: estimatedTotalPages,
              );
            },
          ),
        );

        widgets.add(pw.SizedBox(height: 6));

        widgets.add(
          service._buildTotalsAndClosingBar(
            opening: opening,
            sumDr: sumDr,
            sumCr: sumCr,
            closing: closing,
            includeProductColumns: includeProductColumns,
            latin: latin,
            latinBold: latinBold,
            green: green,
            red: red,
            black: black,
          ),
        );

        widgets.add(pw.SizedBox(height: 12));

        widgets.add(
          service._buildSignatureAndPeriod(
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
  emitProgress(
    stage: 'finalize',
    message: 'Finalizing document...',
    progress: 0.92,
    pagesDone: (estimatedTotalPages - 1).clamp(0, estimatedTotalPages),
    pagesTotal: estimatedTotalPages,
  );
  final bytes = await pdf.save();
  buildSw.stop();
  totalSw.stop();
  emitProgress(
    stage: 'done',
    message: 'PDF ready',
    progress: 1.0,
    pagesDone: estimatedTotalPages,
    pagesTotal: estimatedTotalPages,
    estimated: true,
  );
  debugPrint(
    "[LedgerPerf][PDF:Isolate] pdfSave:done bytes=${bytes.length} "
    "buildElapsedMs=${buildSw.elapsedMilliseconds} totalElapsedMs=${totalSw.elapsedMilliseconds}",
  );
  return bytes;
}
