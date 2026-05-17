import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../model/subgroup_balance_row.dart';
import 'base_pdf_service.dart';

/// Subgroup report styled to match the provided sample.
/// Layout: Date column on the left; subgroup/name stack under Date; currency columns to the right.
class SubgroupPdfService extends BasePdfService {
  SubgroupPdfService._();
  static final SubgroupPdfService instance = SubgroupPdfService._();
  static const double _rowHeight = 24;
  static const double _subgroupColWidth = 90;
  static const double _nameColWidth = 150;
  static const double _currencyColWidth = 95;

  bool _isRtl(String? s) {
    if (s == null || s.trim().isEmpty) return false;
    return RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
    ).hasMatch(s);
  }

  pw.TextDirection _dir(String text) =>
      _isRtl(text) ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  pw.Font _pickFont(String text, pw.Font latin, pw.Font latinBold, bool bold) {
    if (_isRtl(text)) return latin;
    return bold ? latinBold : latin;
  }

  Future<File> render({
    required List<SubgroupBalanceRow> rows,
    String title = 'Trial Balance',
    String? periodText,
    String? filterSummary,
  }) async {
    debugPrint("[SubgroupPdf] render:start rows=${rows.length}");
    final sw = Stopwatch()..start();

    final fontData = await rootBundle.load(
      'assets/fonts/NotoSansArabic-Regular.ttf',
    );
    final payload = <String, dynamic>{
      'title': title,
      'periodText': periodText,
      'filterSummary': filterSummary,
      'fontBytes': fontData.buffer.asUint8List(),
      'rows': rows
          .map(
            (r) => <String, dynamic>{
              'subgroup': r.subgroup,
              'name': r.name,
              'currency': r.currency,
              'balance': r.balance,
            },
          )
          .toList(),
    };

    final pdfBytes = await compute(_buildSubgroupPdfBytesInIsolate, payload);
    final dir = Directory.systemTemp;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/subgroup_report_$ts.pdf');
    await file.writeAsBytes(pdfBytes, flush: true);

    sw.stop();
    debugPrint(
      "[SubgroupPdf] render:done path=${file.path} bytes=${pdfBytes.length} elapsedMs=${sw.elapsedMilliseconds}",
    );
    return file;
  }

  Future<Uint8List> _buildPdfBytes({
    required List<SubgroupBalanceRow> rows,
    required String title,
    String? periodText,
    String? filterSummary,
    required pw.Font font,
    required pw.Font fontBold,
  }) async {
    final pdf = pw.Document();

    // Colors from sample
    final headerYellow = PdfColor.fromInt(0xFFFFFF00);
    final totalYellow = PdfColor.fromInt(0xFFFFFF00);
    final positiveGreen = PdfColor.fromInt(0xFF66FF66);
    final negativeRed = PdfColor.fromInt(0xFFFF3333);
    final borderGreen = PdfColor.fromInt(0xFF4CAF50);
    final teal = PdfColor.fromInt(0xFF00897B);
    final grid = PdfColor.fromInt(0xFF707070);

    final printed = DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now());

    // Group: subgroup -> name -> currency -> balance
    final Map<String, Map<String, Map<String, double>>> grouped = {};
    for (final r in rows) {
      final currency = r.currency.trim();
      if (currency.isEmpty) continue;

      grouped.putIfAbsent(r.subgroup, () => {});
      grouped[r.subgroup]!.putIfAbsent(r.name, () => {});
      grouped[r.subgroup]![r.name]![currency] =
          (grouped[r.subgroup]![r.name]![currency] ?? 0) + r.balance;
    }

    final allCurrencies =
        grouped.values
            .expand((byName) => byName.values)
            .expand((byCur) => byCur.keys)
            .toSet()
            .toList()
          ..sort((a, b) => a.toUpperCase().compareTo(b.toUpperCase()));

    // Totals
    final subgroupTotals = <String, Map<String, double>>{};
    final grandTotalsAll = <String, double>{
      for (final c in allCurrencies) c: 0.0,
    };
    grouped.forEach((sg, names) {
      final totals = <String, double>{for (final c in allCurrencies) c: 0.0};
      names.forEach((_, byCur) {
        byCur.forEach((c, v) {
          totals[c] = (totals[c] ?? 0) + v;
          grandTotalsAll[c] = (grandTotalsAll[c] ?? 0) + v;
        });
      });
      subgroupTotals[sg] = totals;
    });

    // Keep currency if any subgroup/name row has non-zero value for it.
    final currencies = allCurrencies.where((currency) {
      for (final byName in grouped.values) {
        for (final byCur in byName.values) {
          if ((byCur[currency] ?? 0.0).abs() > 0.000001) {
            return true;
          }
        }
      }
      return false;
    }).toList();

    final visibleCurrencies = currencies.isEmpty ? allCurrencies : currencies;
    final grandTotals = <String, double>{
      for (final c in visibleCurrencies) c: grandTotalsAll[c] ?? 0.0,
    };

    // Horizontal pagination by currency columns (for many currencies).
    final maxCurrencyCols = _maxCurrencyColsForPage(
      pageWidth: PdfPageFormat.a4.landscape.width,
      horizontalMargins: 28,
    );
    final currencyChunks = _chunkCurrencyColumns(
      visibleCurrencies,
      chunkSize: maxCurrencyCols,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(14),
        build: (_) {
          final widgets = <pw.Widget>[
            _titleBar(
              title,
              fontBold,
              periodText: periodText,
              filterSummary: filterSummary,
            ),
            pw.SizedBox(height: 6),
          ];

          for (int i = 0; i < currencyChunks.length; i++) {
            final chunkCurrencies = currencyChunks[i];

            if (i > 0) {
              widgets.add(pw.NewPage());
              widgets.add(
                _titleBar(
                  title,
                  fontBold,
                  periodText: periodText,
                  filterSummary: filterSummary,
                ),
              );
              widgets.add(pw.SizedBox(height: 6));
            }

            if (currencyChunks.length > 1) {
              widgets.add(
                pw.Text(
                  "Currencies ${i + 1}/${currencyChunks.length}",
                  style: pw.TextStyle(font: fontBold, fontSize: 10),
                ),
              );
              widgets.add(pw.SizedBox(height: 4));
            }

            widgets.add(
              _buildMahfoozTopRight(
                currencies: chunkCurrencies,
                fontBold: fontBold,
              ),
            );
            widgets.add(pw.SizedBox(height: 2));

            widgets.add(
              _headerRow(
                printed,
                chunkCurrencies,
                fontBold,
                headerYellow,
                grid,
                teal,
                borderGreen,
              ),
            );

            widgets.addAll(
              _bodyRows(
                grouped,
                subgroupTotals,
                chunkCurrencies,
                fontBold,
                totalYellow,
                positiveGreen,
                negativeRed,
                grid,
                teal,
                borderGreen,
              ),
            );

            widgets.add(
              _grandTotalRow(
                chunkCurrencies,
                grandTotals,
                fontBold,
                totalYellow,
                positiveGreen,
                negativeRed,
                grid,
                borderGreen,
              ),
            );
          }

          return widgets;
        },
      ),
    );

    return pdf.save();
  }

  // ----- Layout builders -----

  pw.Widget _titleBar(
    String title,
    pw.Font fontBold, {
    String? periodText,
    String? filterSummary,
  }) {
    final metaLines = [
      if ((periodText ?? '').trim().isNotEmpty) periodText!.trim(),
      if ((filterSummary ?? '').trim().isNotEmpty) filterSummary!.trim(),
    ];

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6, right: 40, top: 2),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 2),
          right: pw.BorderSide(color: PdfColors.black, width: 2),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 16)),
          if (metaLines.isNotEmpty) pw.SizedBox(height: 4),
          ...metaLines.map(
            (line) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(
                line,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 8.5,
                  color: PdfColor.fromInt(0xFF556679),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _headerRow(
    String printed,
    List<String> currencies,
    pw.Font fontBold,
    PdfColor headerYellow,
    PdfColor grid,
    PdfColor teal,
    PdfColor borderGreen,
  ) {
    final tableWidth =
        _subgroupColWidth +
        _nameColWidth +
        (currencies.length * _currencyColWidth);
    return pw.Container(
      width: tableWidth,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderGreen, width: 1),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            width: _subgroupColWidth + _nameColWidth,
            height: _rowHeight,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(color: borderGreen, width: 1),
                top: pw.BorderSide(color: borderGreen, width: 1),
                bottom: pw.BorderSide(color: grid, width: 0.5),
                right: pw.BorderSide(color: grid, width: 0.5),
              ),
            ),
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8),
              child: pw.Text(
                "Generated Date $printed",
                style: pw.TextStyle(font: fontBold, fontSize: 8),
              ),
            ),
          ),
          ...currencies.map(
            (c) => _headerLabel(
              c,
              fontBold,
              headerYellow,
              grid,
              width: _currencyColWidth,
              height: _rowHeight,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMahfoozTopRight({
    required List<String> currencies,
    required pw.Font fontBold,
  }) {
    final tableWidth =
        _subgroupColWidth +
        _nameColWidth +
        (currencies.length * _currencyColWidth);
    final mahfoozLight = PdfColor.fromInt(0xFFC7CDD7);
    return pw.Container(
      width: tableWidth,
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        "Mahfooz Accounts",
        style: pw.TextStyle(font: fontBold, fontSize: 8, color: mahfoozLight),
      ),
    );
  }

  List<pw.Widget> _bodyRows(
    Map<String, Map<String, Map<String, double>>> grouped,
    Map<String, Map<String, double>> subgroupTotals,
    List<String> currencies,
    pw.Font fontBold,
    PdfColor totalYellow,
    PdfColor positiveGreen,
    PdfColor negativeRed,
    PdfColor grid,
    PdfColor teal,
    PdfColor borderGreen,
  ) {
    final tableWidth =
        _subgroupColWidth +
        _nameColWidth +
        (currencies.length * _currencyColWidth);
    final widgets = <pw.Widget>[];

    grouped.forEach((subgroup, namesMap) {
      final names = namesMap.keys.toList()..sort();
      final visibleNames = names.where((name) {
        final byCur = namesMap[name]!;
        return currencies.any((c) => (byCur[c] ?? 0.0) != 0.0);
      }).toList();

      if (visibleNames.isEmpty) return;

      final rowSpecs = visibleNames.map((name) {
        final byCur = namesMap[name]!;
        final lineCount = _nameLineCount(name);
        return _SubgroupRowSpec(
          name: name,
          byCur: byCur,
          lineCount: lineCount,
          height: _rowHeight * lineCount,
        );
      }).toList();

      final chunks = _chunkRows(rowSpecs, maxChunkHeight: 430);
      final totals = subgroupTotals[subgroup]!;

      for (int chunkIndex = 0; chunkIndex < chunks.length; chunkIndex++) {
        final chunk = chunks[chunkIndex];
        final isLastChunk = chunkIndex == chunks.length - 1;
        final bodyHeight = chunk.fold<double>(
          0.0,
          (sum, row) => sum + row.height,
        );
        final chunkHeight = bodyHeight + (isLastChunk ? _rowHeight : 0.0);

        final nameRows = <pw.Widget>[];
        final currencyRows = <pw.Widget>[];

        for (final row in chunk) {
          nameRows.add(
            _nameCell(
              row.name,
              fontBold,
              grid,
              height: row.height,
              maxLines: row.lineCount,
            ),
          );

          currencyRows.add(
            pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: currencies.map((c) {
                final v = row.byCur[c] ?? 0.0;
                return _valueBox(
                  v,
                  fontBold,
                  grid,
                  positiveGreen,
                  negativeRed,
                  width: _currencyColWidth,
                  height: row.height,
                );
              }).toList(),
            ),
          );
        }

        if (isLastChunk) {
          nameRows.add(
            pw.Container(
              width: _nameColWidth,
              height: _rowHeight,
              alignment: pw.Alignment.centerLeft,
              padding: const pw.EdgeInsets.symmetric(horizontal: 6),
              decoration: pw.BoxDecoration(
                color: totalYellow,
                border: pw.Border.all(color: PdfColors.black, width: 1),
              ),
              child: pw.Text(
                "Total",
                style: pw.TextStyle(font: fontBold, fontSize: 10),
              ),
            ),
          );

          currencyRows.add(
            pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: currencies.map((c) {
                final v = totals[c] ?? 0.0;
                return _totalBox(
                  v,
                  fontBold,
                  grid,
                  totalYellow,
                  width: _currencyColWidth,
                  height: _rowHeight,
                );
              }).toList(),
            ),
          );
        }

        widgets.add(
          pw.Container(
            width: tableWidth,
            decoration: pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(color: borderGreen, width: 1),
                right: pw.BorderSide(color: borderGreen, width: 1),
                top: pw.BorderSide(color: grid, width: 0.5),
              ),
            ),
            child: pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _subgroupSpanCell(
                  subgroup,
                  fontBold,
                  grid,
                  teal,
                  borderGreen,
                  height: chunkHeight,
                ),
                pw.Column(children: nameRows),
                pw.Column(children: currencyRows),
              ],
            ),
          ),
        );
      }
    });

    return widgets;
  }

  pw.Widget _grandTotalRow(
    List<String> currencies,
    Map<String, double> grandTotals,
    pw.Font fontBold,
    PdfColor totalYellow,
    PdfColor positiveGreen,
    PdfColor negativeRed,
    PdfColor grid,
    PdfColor borderGreen,
  ) {
    final tableWidth =
        _subgroupColWidth +
        _nameColWidth +
        (currencies.length * _currencyColWidth);
    return pw.Container(
      width: tableWidth,
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: borderGreen, width: 1),
          right: pw.BorderSide(color: borderGreen, width: 1),
          bottom: pw.BorderSide(color: borderGreen, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            width: _subgroupColWidth + _nameColWidth,
            height: _rowHeight,
            alignment: pw.Alignment.centerLeft,
            padding: pw.EdgeInsets.only(left: _subgroupColWidth + 6),
            decoration: pw.BoxDecoration(
              color: totalYellow,
              border: pw.Border.all(color: PdfColors.black, width: 1),
            ),
            child: pw.Text(
              "FINAL TOTAL",
              style: pw.TextStyle(font: fontBold, fontSize: 10),
            ),
          ),
          ...currencies.map((c) {
            final v = grandTotals[c] ?? 0.0;
            return _grandTotalBox(
              v,
              fontBold,
              grid,
              positiveGreen,
              negativeRed,
              width: _currencyColWidth,
              height: _rowHeight,
            );
          }),
        ],
      ),
    );
  }

  // ----- Cell helpers -----

  List<List<_SubgroupRowSpec>> _chunkRows(
    List<_SubgroupRowSpec> rows, {
    required double maxChunkHeight,
  }) {
    final chunks = <List<_SubgroupRowSpec>>[];
    var current = <_SubgroupRowSpec>[];
    double currentHeight = 0;

    for (final row in rows) {
      final willOverflow =
          current.isNotEmpty && (currentHeight + row.height > maxChunkHeight);
      if (willOverflow) {
        chunks.add(current);
        current = <_SubgroupRowSpec>[];
        currentHeight = 0;
      }
      current.add(row);
      currentHeight += row.height;
    }

    if (current.isNotEmpty) {
      chunks.add(current);
    }

    if (chunks.isNotEmpty) {
      final last = chunks.last;
      final lastHeight = last.fold<double>(0.0, (sum, r) => sum + r.height);
      if (lastHeight + _rowHeight > maxChunkHeight && last.length > 1) {
        final moved = last.removeLast();
        chunks[chunks.length - 1] = last;
        chunks.add([moved]);
      }
    }

    return chunks;
  }

  int _nameLineCount(String name) {
    final len = name.trim().length;
    if (len > 52) return 3;
    if (len > 26) return 2;
    return 1;
  }

  int _maxCurrencyColsForPage({
    required double pageWidth,
    required double horizontalMargins,
  }) {
    final usableWidth = pageWidth - horizontalMargins;
    final fixedWidth = _subgroupColWidth + _nameColWidth;
    final remaining = usableWidth - fixedWidth;
    final count = (remaining / _currencyColWidth).floor();
    return count < 1 ? 1 : count;
  }

  List<List<String>> _chunkCurrencyColumns(
    List<String> currencies, {
    required int chunkSize,
  }) {
    if (currencies.isEmpty) return [const []];

    final chunks = <List<String>>[];
    for (int i = 0; i < currencies.length; i += chunkSize) {
      final end = (i + chunkSize < currencies.length)
          ? i + chunkSize
          : currencies.length;
      chunks.add(currencies.sublist(i, end));
    }
    return chunks;
  }

  pw.Widget _subgroupSpanCell(
    String text,
    pw.Font font,
    PdfColor grid,
    PdfColor teal,
    PdfColor borderGreen, {
    required double height,
  }) {
    return pw.Container(
      width: _subgroupColWidth,
      height: height,
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: borderGreen, width: 1),
          right: pw.BorderSide(color: grid, width: 0.5),
          top: pw.BorderSide(color: grid, width: 0.5),
          bottom: pw.BorderSide(color: grid, width: 0.5),
        ),
      ),
      child: pw.Stack(
        children: [
          pw.Positioned.fill(
            child: pw.Container(
              margin: const pw.EdgeInsets.fromLTRB(10, 6, 8, 6),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  right: pw.BorderSide(color: teal, width: 2),
                  bottom: pw.BorderSide(color: teal, width: 2),
                ),
              ),
            ),
          ),
          pw.Center(
            child: pw.Text(
              text,
              textDirection: _dir(text),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: _pickFont(text, font, font, true),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _nameCell(
    String text,
    pw.Font font,
    PdfColor grid, {
    required double height,
    required int maxLines,
  }) {
    final isRtl = _isRtl(text);

    return pw.Container(
      width: _nameColWidth,
      height: height,
      alignment: isRtl ? pw.Alignment.topRight : pw.Alignment.topLeft,
      padding: isRtl
          ? const pw.EdgeInsets.fromLTRB(4, 4, 8, 4)
          : const pw.EdgeInsets.fromLTRB(8, 4, 4, 4),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: grid, width: 0.5),
          right: pw.BorderSide(color: grid, width: 0.5),
          top: pw.BorderSide(color: grid, width: 0.5),
          bottom: pw.BorderSide(color: grid, width: 0.5),
        ),
      ),
      child: pw.Text(
        text,
        textDirection: _dir(text),
        textAlign: isRtl ? pw.TextAlign.right : pw.TextAlign.left,
        maxLines: maxLines,
        softWrap: true,
        style: pw.TextStyle(
          font: _pickFont(text, font, font, true),
          fontSize: 10,
        ),
      ),
    );
  }

  pw.Widget _headerLabel(
    String text,
    pw.Font font,
    PdfColor bg,
    PdfColor borderColor, {
    required double width,
    required double height,
  }) {
    return pw.Container(
      width: width,
      height: height,
      decoration: pw.BoxDecoration(
        color: bg,
        border: pw.Border.all(color: borderColor, width: 0.5),
      ),
      child: pw.Center(
        child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 9)),
      ),
    );
  }

  pw.Widget _valueBox(
    double value,
    pw.Font font,
    PdfColor grid,
    PdfColor positiveGreen,
    PdfColor negativeRed, {
    required double width,
    required double height,
  }) {
    final bg = value > 0
        ? positiveGreen
        : value < 0
        ? negativeRed
        : PdfColors.white;
    return pw.Container(
      width: width,
      height: height,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: bg,
        border: pw.Border.all(color: grid, width: 0.5),
      ),
      child: pw.Text(
        value == 0 ? "0" : nf.format(value),
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: font, fontSize: 9),
      ),
    );
  }

  pw.Widget _totalBox(
    double value,
    pw.Font font,
    PdfColor grid,
    PdfColor totalYellow, {
    required double width,
    required double height,
  }) {
    final bg = value == 0 ? PdfColors.white : totalYellow;
    return pw.Container(
      width: width,
      height: height,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: bg,
        border: pw.Border.all(color: grid, width: 0.5),
      ),
      child: pw.Text(
        value == 0 ? "0" : nf.format(value),
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: font, fontSize: 9),
      ),
    );
  }

  pw.Widget _grandTotalBox(
    double value,
    pw.Font font,
    PdfColor grid,
    PdfColor positiveGreen,
    PdfColor negativeRed, {
    required double width,
    required double height,
  }) {
    final bg = value > 0
        ? positiveGreen
        : value < 0
        ? negativeRed
        : PdfColors.white;
    return pw.Container(
      width: width,
      height: height,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: bg,
        border: pw.Border.all(color: grid, width: 0.5),
      ),
      child: pw.Text(
        value == 0 ? "0" : nf.format(value),
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: font, fontSize: 9),
      ),
    );
  }
}

class _SubgroupRowSpec {
  final String name;
  final Map<String, double> byCur;
  final int lineCount;
  final double height;

  const _SubgroupRowSpec({
    required this.name,
    required this.byCur,
    required this.lineCount,
    required this.height,
  });
}

Future<Uint8List> _buildSubgroupPdfBytesInIsolate(
  Map<String, dynamic> payload,
) async {
  final title = (payload['title'] as String?) ?? 'Trial Balance';
  final periodText = (payload['periodText'] as String?)?.trim();
  final filterSummary = (payload['filterSummary'] as String?)?.trim();
  final fontBytes = payload['fontBytes'] as Uint8List;
  final rawRows = (payload['rows'] as List?)?.cast<Map>() ?? const <Map>[];

  final rows = rawRows
      .map((m) {
        final row = Map<String, dynamic>.from(m.cast<String, dynamic>());
        return SubgroupBalanceRow(
          subgroup: (row['subgroup'] as String?) ?? '',
          name: (row['name'] as String?) ?? '',
          currency: (row['currency'] as String?) ?? '',
          balance: (row['balance'] is num)
              ? (row['balance'] as num).toDouble()
              : 0.0,
        );
      })
      .toList(growable: false);

  final service = SubgroupPdfService._();
  final fontData = fontBytes.buffer.asByteData(
    fontBytes.offsetInBytes,
    fontBytes.lengthInBytes,
  );
  final unicodeFont = pw.Font.ttf(fontData);

  return service._buildPdfBytes(
    rows: rows,
    title: title,
    periodText: periodText,
    filterSummary: filterSummary,
    font: unicodeFont,
    fontBold: unicodeFont,
  );
}
