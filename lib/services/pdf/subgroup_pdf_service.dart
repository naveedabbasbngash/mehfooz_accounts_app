import 'dart:io';
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

  Future<File> render({
    required List<SubgroupBalanceRow> rows,
    String title = 'Trial Balance',
  }) async {
    final pdf = pw.Document();
    final (font, fontBold) = await createFonts();

    // Colors from sample
    final headerYellow = PdfColor.fromInt(0xFFFFFF00);
    final totalYellow = PdfColor.fromInt(0xFFFFFF00);
    final positiveGreen = PdfColor.fromInt(0xFF66FF66);
    final negativeRed = PdfColor.fromInt(0xFFFF3333);
    final borderGreen = PdfColor.fromInt(0xFF4CAF50);
    final teal = PdfColor.fromInt(0xFF00897B);
    final grid = PdfColor.fromInt(0xFF707070);

    final date = DateTime.now();
    final printed = "${date.day}/${date.month}/${date.year}";

    // Keep currency order stable to match sample
    final currencies = ['AFG', 'PKR', 'POUND', 'RMB', 'USD'];

    // Group: subgroup -> name -> currency -> balance
    final Map<String, Map<String, Map<String, double>>> grouped = {};
    for (final r in rows) {
      grouped.putIfAbsent(r.subgroup, () => {});
      grouped[r.subgroup]!.putIfAbsent(r.name, () => {});
      grouped[r.subgroup]![r.name]![r.currency] =
          (grouped[r.subgroup]![r.name]![r.currency] ?? 0) + r.balance;
    }

    // Totals
    final subgroupTotals = <String, Map<String, double>>{};
    final grandTotals = <String, double>{for (final c in currencies) c: 0.0};
    grouped.forEach((sg, names) {
      final totals = <String, double>{for (final c in currencies) c: 0.0};
      names.forEach((_, byCur) {
        byCur.forEach((c, v) {
          totals[c] = (totals[c] ?? 0) + v;
          grandTotals[c] = (grandTotals[c] ?? 0) + v;
        });
      });
      subgroupTotals[sg] = totals;
    });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(14),
        build: (_) => [
          _titleBar(title, fontBold),
          pw.SizedBox(height: 6),
          _headerRow(
            printed,
            currencies,
            fontBold,
            headerYellow,
            grid,
            teal,
            borderGreen,
          ),
          ..._bodyRows(
            grouped,
            subgroupTotals,
            currencies,
            fontBold,
            totalYellow,
            positiveGreen,
            negativeRed,
            grid,
            teal,
            borderGreen,
          ),
          _grandTotalRow(
            currencies,
            grandTotals,
            fontBold,
            totalYellow,
            positiveGreen,
            negativeRed,
            grid,
            borderGreen,
          ),
        ],
      ),
    );

    return savePdf(pdf, 'subgroup_report');
  }

  // ----- Layout builders -----

  pw.Widget _titleBar(String title, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 3, right: 40),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 2),
          right: pw.BorderSide(color: PdfColors.black, width: 2),
        ),
      ),
      child: pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 16)),
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
            child: pw.Text(
              printed,
              style: pw.TextStyle(font: fontBold, fontSize: 10),
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
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: font, fontSize: 10),
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
    return pw.Container(
      width: _nameColWidth,
      height: height,
      alignment: pw.Alignment.topLeft,
      padding: const pw.EdgeInsets.fromLTRB(8, 4, 4, 4),
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
        maxLines: maxLines,
        softWrap: true,
        style: pw.TextStyle(font: font, fontSize: 10),
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
