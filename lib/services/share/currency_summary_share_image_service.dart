import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

class CurrencySummaryShareRow {
  final String currency;
  final String countryName;
  final double balance;
  final double? rate;
  final double? converted;

  const CurrencySummaryShareRow({
    required this.currency,
    required this.countryName,
    required this.balance,
    required this.rate,
    required this.converted,
  });
}

class CurrencySummaryShareImageService {
  CurrencySummaryShareImageService._();
  static final CurrencySummaryShareImageService instance =
      CurrencySummaryShareImageService._();

  static final NumberFormat _moneyFmt = NumberFormat('#,##0.00');

  String _money(double v) {
    final safe = v.abs() < 0.005 ? 0.0 : v;
    return _moneyFmt.format(safe);
  }

  String _currencyToCountryCode(String currency) {
    switch (currency.toUpperCase().trim()) {
      case 'PKR':
        return 'PK';
      case 'USD':
        return 'US';
      case 'AED':
        return 'AE';
      case 'SAR':
        return 'SA';
      case 'EUR':
        return 'EU';
      case 'GBP':
      case 'POUND':
        return 'GB';
      case 'INR':
      case 'IND':
        return 'IN';
      case 'AFG':
      case 'AFN':
        return 'AF';
      case 'CAD':
        return 'CA';
      case 'JPY':
        return 'JP';
      case 'RMB':
      case 'CNY':
        return 'CN';
      case 'IRR':
        return 'IR';
      case 'BHD':
        return 'BH';
      case 'OMR':
        return 'OM';
      case 'QAR':
        return 'QA';
      case 'DKK':
        return 'DK';
      case 'SEK':
        return 'SE';
      case 'NOK':
        return 'NO';
      case 'MYR':
        return 'MY';
      case 'AUD':
        return 'AU';
      case 'HKD':
        return 'HK';
      case 'SGD':
      case 'SGP':
        return 'SG';
      case 'RUB':
        return 'RU';
      default:
        return 'UN';
    }
  }

  String _countryCodeToEmoji(String countryCode) {
    final cc = countryCode.toUpperCase();
    if (cc.length != 2 || cc.contains(RegExp(r'[^A-Z]'))) {
      return '🏳️';
    }
    final first = 0x1F1E6 + cc.codeUnitAt(0) - 65;
    final second = 0x1F1E6 + cc.codeUnitAt(1) - 65;
    return String.fromCharCode(first) + String.fromCharCode(second);
  }

  Future<File> render({
    required String accountName,
    required String baseCurrency,
    required List<CurrencySummaryShareRow> rows,
    required double total,
  }) async {
    if (rows.isEmpty) {
      throw Exception('No rows to share');
    }

    const double width = 1080;
    const double pagePad = 36;
    const double headerHeight = 142;
    const double rowHeight = 112;
    const double rightBlockWidth = 360;
    const double footerHeight = 88;

    final double contentHeight = pagePad +
        headerHeight +
        (rows.length * rowHeight) +
        footerHeight +
        pagePad;
    final int height = contentHeight.ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width, height.toDouble()),
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height.toDouble()),
      Paint()..color = Colors.white,
    );

    final title = 'Currency Summary';
    final accountLine = accountName.trim().isEmpty
        ? 'Account: Unknown'
        : 'Account: ${accountName.trim()}';
    final generatedAt = DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now());
    final subtitle = 'Base: $baseCurrency   Generated: $generatedAt';

    _drawText(
      canvas: canvas,
      text: title,
      x: pagePad,
      y: pagePad,
      maxWidth: width - (pagePad * 2),
      style: const TextStyle(
        fontSize: 38,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0B1E3A),
      ),
      align: TextAlign.left,
    );

    _drawText(
      canvas: canvas,
      text: accountLine,
      x: pagePad,
      y: pagePad + 58,
      maxWidth: width - (pagePad * 2),
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w500,
        color: Color(0xFF4B5563),
      ),
      align: TextAlign.left,
    );

    final dividerY = pagePad + headerHeight;
    final metaY = dividerY - 34;
    _drawText(
      canvas: canvas,
      text: subtitle,
      x: pagePad,
      y: metaY,
      maxWidth: width - (pagePad * 2) - 320,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: Color(0xFF6B7280),
      ),
      align: TextAlign.left,
    );
    _drawText(
      canvas: canvas,
      text: 'Mahfooz Accounts',
      x: width - pagePad - 300,
      y: metaY,
      maxWidth: 300,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: Color(0xFFD1D5DB),
      ),
      align: TextAlign.right,
    );

    canvas.drawLine(
      Offset(pagePad, dividerY),
      Offset(width - pagePad, dividerY),
      Paint()
        ..color = const Color(0x22000000)
        ..strokeWidth = 1.5,
    );

    double rowTop = dividerY + 1;
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (i.isOdd) {
        canvas.drawRect(
          Rect.fromLTWH(pagePad, rowTop, width - (pagePad * 2), rowHeight),
          Paint()..color = const Color(0xFFF8FAFD),
        );
      }

      final emoji = _countryCodeToEmoji(_currencyToCountryCode(row.currency));
      _drawText(
        canvas: canvas,
        text: emoji,
        x: pagePad + 6,
        y: rowTop + 22,
        maxWidth: 50,
        style: const TextStyle(fontSize: 34),
        align: TextAlign.left,
      );

      final leftX = pagePad + 64;
      _drawText(
        canvas: canvas,
        text: row.currency.trim().isEmpty ? 'Unknown currency' : row.currency,
        x: leftX,
        y: rowTop + 16,
        maxWidth: 420,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0B1E3A),
        ),
        align: TextAlign.left,
      );

      _drawText(
        canvas: canvas,
        text: row.countryName.trim().isEmpty ? 'Unknown' : row.countryName,
        x: leftX,
        y: rowTop + 56,
        maxWidth: 420,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: Color(0xFF9CA3AF),
        ),
        align: TextAlign.left,
      );

      final rightX = width - pagePad - rightBlockWidth;
      final balColor =
          row.balance >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
      _drawText(
        canvas: canvas,
        text: _money(row.balance),
        x: rightX,
        y: rowTop + 12,
        maxWidth: rightBlockWidth,
        style: TextStyle(
          fontSize: 29,
          fontWeight: FontWeight.w700,
          color: balColor,
        ),
        align: TextAlign.right,
      );

      _drawText(
        canvas: canvas,
        text: row.rate == null ? 'Rate --' : 'Rate ${row.rate!.toStringAsFixed(4)}',
        x: rightX,
        y: rowTop + 50,
        maxWidth: rightBlockWidth,
        style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4B5563),
        ),
        align: TextAlign.right,
      );

      _drawText(
        canvas: canvas,
        text: row.converted == null
            ? 'Converted -- $baseCurrency'
            : '${_money(row.converted!)} $baseCurrency',
        x: rightX,
        y: rowTop + 78,
        maxWidth: rightBlockWidth,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1D4ED8),
        ),
        align: TextAlign.right,
      );

      rowTop += rowHeight;
    }

    final footerTop = rowTop + 10;
    canvas.drawLine(
      Offset(pagePad, footerTop),
      Offset(width - pagePad, footerTop),
      Paint()
        ..color = const Color(0x22000000)
        ..strokeWidth = 1.5,
    );

    final totalColor =
        total >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

    _drawText(
      canvas: canvas,
      text: 'Total "$baseCurrency" Balance',
      x: pagePad,
      y: footerTop + 24,
      maxWidth: width - (pagePad * 2) - 280,
      style: const TextStyle(
        fontSize: 27,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0B1E3A),
      ),
      align: TextAlign.left,
    );

    final rightX = width - pagePad - rightBlockWidth;
    _drawText(
      canvas: canvas,
      text: _money(total),
      x: rightX,
      y: footerTop + 24,
      maxWidth: rightBlockWidth,
      style: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: totalColor,
      ),
      align: TextAlign.right,
    );

    final image = await recorder.endRecording().toImage(width.toInt(), height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw Exception('Failed to generate image bytes');
    }

    final pngBytes = data.buffer.asUint8List();
    final decoded = img.decodePng(pngBytes);
    final outputBytes =
        decoded != null ? img.encodeJpg(decoded, quality: 94) : pngBytes;
    final ext = decoded != null ? 'jpg' : 'png';

    final file = File(
      '${Directory.systemTemp.path}/currency_summary_share_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    await file.writeAsBytes(outputBytes, flush: true);
    return file;
  }

  void _drawText({
    required Canvas canvas,
    required String text,
    required double x,
    required double y,
    required double maxWidth,
    required TextStyle style,
    required TextAlign align,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, Offset(x, y));
  }
}
