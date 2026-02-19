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
            font,
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
    pw.Font font,
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

      // left block: subgroup label (spans), name column
      final subgroupHeight = _rowHeight * (names.length + 1);
      final leftColumn = pw.Container(
        width: _subgroupColWidth,
        height: subgroupHeight,
        decoration: pw.BoxDecoration(
          border: pw.Border(
            left: pw.BorderSide(color: borderGreen, width: 1),
            top: pw.BorderSide(color: grid, width: 0.5),
            bottom: pw.BorderSide(color: grid, width: 0.5),
            right: pw.BorderSide(color: grid, width: 0.5),
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
                subgroup,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: fontBold, fontSize: 10),
              ),
            ),
          ],
        ),
      );

      final nameRows = <pw.Widget>[];
      for (final name in names) {
        nameRows.add(
          pw.Container(
            width: _nameColWidth,
            height: _rowHeight,
            alignment: pw.Alignment.centerLeft,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(color: grid, width: 0.5),
                right: pw.BorderSide(color: grid, width: 0.5),
                top: pw.BorderSide(color: grid, width: 0.5),
                bottom: pw.BorderSide(color: grid, width: 0.5),
              ),
            ),
            child: pw.Text(
              name,
              style: pw.TextStyle(font: fontBold, fontSize: 10),
            ),
          ),
        );
      }
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

      final currencyRows = <pw.Widget>[];
      for (final name in names) {
        final byCur = namesMap[name]!;
        currencyRows.add(
          pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: currencies.map((c) {
              final v = byCur[c] ?? 0.0;
              return _valueBox(
                v,
                fontBold,
                grid,
                positiveGreen,
                negativeRed,
                width: _currencyColWidth,
                height: _rowHeight,
              );
            }).toList(),
          ),
        );
      }
      final totals = subgroupTotals[subgroup]!;
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
              leftColumn,
              pw.Column(children: nameRows),
              pw.Column(children: currencyRows),
            ],
          ),
        ),
      );
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
        border: pw.Border.all(color: borderColor, width: 0.5),
      ),
      child: pw.Center(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          color: bg,
          child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 9)),
        ),
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
        border: pw.Border.all(color: grid, width: 0.5),
      ),
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 6),
        color: bg,
        child: pw.Text(
          value == 0 ? "0" : nf.format(value),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: font, fontSize: 9),
        ),
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
        border: pw.Border.all(color: grid, width: 0.5),
      ),
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 6),
        decoration: pw.BoxDecoration(
          color: bg,
          border: value == 0
              ? null
              : pw.Border.all(color: PdfColors.black, width: 1),
        ),
        child: pw.Text(
          value == 0 ? "0" : nf.format(value),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: font, fontSize: 9),
        ),
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
        border: pw.Border.all(color: grid, width: 0.5),
      ),
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 6),
        color: bg,
        child: pw.Text(
          value == 0 ? "0" : nf.format(value),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: font, fontSize: 9),
        ),
      ),
    );
  }
}
