import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../model/pending_group_row.dart';
import 'base_pdf_service.dart';

class PendingPdfService extends BasePdfService {
  PendingPdfService._();

  static final PendingPdfService instance = PendingPdfService._();

  Future<File> exportOne(PendingGroupRow row) async {
    return exportMany([row]);
  }

  Future<File> exportMany(List<PendingGroupRow> rows) async {
    final pdf = pw.Document();

    final (font, fontBold) = createFonts();
    final deepBlue = PdfColor.fromInt(0xFF0B1E3A);
    final white = PdfColors.white;
    final black = PdfColors.black;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(
          BasePdfService.marginLeft,
          BasePdfService.marginTop,
          BasePdfService.marginRight,
          BasePdfService.marginBottom,
        ),
        build: (context) => [
          buildHeader(
            title: 'Pending Amount Summary',
            font: font,
            fontBold: fontBold,
            titleColor: deepBlue,
          ),
          pw.SizedBox(height: 6),
          _buildTable(
            rows: rows,
            font: font,
            fontBold: fontBold,
            headerColor: deepBlue,
            headerTextColor: white,
            textColor: black,
          ),
        ],
      ),
    );

    return savePdf(pdf, 'pending_summary');
  }

  pw.Widget _buildTable({
    required List<PendingGroupRow> rows,
    required pw.Font font,
    required pw.Font fontBold,
    required PdfColor headerColor,
    required PdfColor headerTextColor,
    required PdfColor textColor,
  }) {
    final List<pw.TableRow> tableRows = [];

    pw.Widget headerCell(String text) {
      return pw.Container(
        color: headerColor,
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 9,
            color: headerTextColor,
          ),
        ),
      );
    }

    tableRows.add(
      pw.TableRow(
        children: const [
          'Date',
          'Currency',
          'Sender',
          'Receiver',
          'PD',
          'Msg No',
          'Paid',
          'Pending',
          'Balance',
        ].map((h) => headerCell(h)).toList(),
      ),
    );

    pw.Widget cell(
        String text, {
          pw.TextAlign align = pw.TextAlign.left,
          bool bold = false,
        }) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        child: pw.Align(
          alignment: align == pw.TextAlign.right
              ? pw.Alignment.centerRight
              : align == pw.TextAlign.center
              ? pw.Alignment.center
              : pw.Alignment.centerLeft,
          child: pw.Text(
            text,
            textAlign: align,
            style: pw.TextStyle(
              font: bold ? fontBold : font,
              fontSize: 9,
              color: textColor,
            ),
          ),
        ),
      );
    }

    for (final r in rows) {
      tableRows.add(
        pw.TableRow(
          children: [
            cell(r.beginDate),
            cell(r.accTypeName ?? ''),
            cell(r.sender ?? ''),
            cell(r.receiver ?? ''),
            cell(r.pd ?? ''),
            cell(r.msgNo ?? ''),
            cell(nf.format(r.paidAmount), align: pw.TextAlign.right),
            cell(nf.format(r.notPaidAmount), align: pw.TextAlign.right),
            cell(nf.format(r.balance),
                align: pw.TextAlign.right, bold: true),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey300,
        width: 0.3,
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.0),
        1: pw.FlexColumnWidth(0.9),
        2: pw.FlexColumnWidth(1.4),
        3: pw.FlexColumnWidth(1.4),
        4: pw.FlexColumnWidth(0.7),
        5: pw.FlexColumnWidth(0.8),
        6: pw.FlexColumnWidth(0.9),
        7: pw.FlexColumnWidth(0.9),
        8: pw.FlexColumnWidth(1.0),
      },
      children: tableRows,
    );
  }
}