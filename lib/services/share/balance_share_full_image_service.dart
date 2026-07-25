import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

import '../../model/balance_currency_ui.dart';

class BalanceShareFullImageService {
  BalanceShareFullImageService._();
  static final BalanceShareFullImageService instance =
      BalanceShareFullImageService._();

  static final NumberFormat _fmt = NumberFormat('#,##0.00');

  String _money(double v) {
    final safe = v.abs() < 0.005 ? 0.0 : v;
    return _fmt.format(safe);
  }

  bool _isZero(double v) => v.abs() < 0.005;

  bool _isRtl(String text) {
    if (text.trim().isEmpty) return false;
    return RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
    ).hasMatch(text);
  }

  Future<File> render({
    required String name,
    required List<BalanceCurrencyUi> rows,
  }) async {
    final visibleRows = rows.where((r) {
      return !_isZero(r.credit) || !_isZero(r.debit) || !_isZero(r.balance);
    }).toList();

    if (visibleRows.isEmpty) {
      throw Exception('No rows to share');
    }

    const double width = 1080;
    const double pagePad = 36;
    const double headerHeight = 92;
    const double rowHeight = 110;
    const double balanceBlockWidth = 250;

    final double contentHeight =
        pagePad + headerHeight + (visibleRows.length * rowHeight) + pagePad;
    final int height = contentHeight.ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height.toDouble()));

    // Solid white background to avoid black background in share targets.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height.toDouble()),
      Paint()..color = Colors.white,
    );

    final title = name.trim().isEmpty ? 'Balance Summary' : 'Balance • ${name.trim()}';
    final subtitle =
        'Generated ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';

    _drawText(
      canvas: canvas,
      text: title,
      x: pagePad,
      y: pagePad,
      maxWidth: width - (pagePad * 2) - balanceBlockWidth,
      style: const TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0B1E3A),
      ),
      align: TextAlign.left,
      rtl: _isRtl(title),
    );

    _drawText(
      canvas: canvas,
      text: subtitle,
      x: pagePad,
      y: pagePad + 48,
      maxWidth: width - (pagePad * 2) - balanceBlockWidth,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: Color(0xFF6B7280),
      ),
      align: TextAlign.left,
      rtl: false,
    );

    final rightX = width - pagePad - 16;
    final balanceBlockX = rightX - balanceBlockWidth;
    final dividerY = pagePad + headerHeight;

    _drawText(
      canvas: canvas,
      text: 'Mahfooz Accounts',
      x: balanceBlockX,
      y: dividerY - 34,
      maxWidth: balanceBlockWidth,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w400,
        color: Color(0xFFD1D5DB),
      ),
      align: TextAlign.center,
      rtl: false,
    );

    canvas.drawLine(
      Offset(pagePad, dividerY),
      Offset(width - pagePad, dividerY),
      Paint()
        ..color = const Color(0x22000000)
        ..strokeWidth = 1.5,
    );

    double rowTop = dividerY + 10;
    for (int i = 0; i < visibleRows.length; i++) {
      final row = visibleRows[i];

      if (i.isOdd) {
        canvas.drawRect(
          Rect.fromLTWH(pagePad, rowTop, width - (pagePad * 2), rowHeight),
          Paint()..color = const Color(0xFFF8FAFD),
        );
      }

      final avatarX = pagePad + 24;
      final avatarY = rowTop + 18;
      final avatarCenter = Offset(avatarX + 22, avatarY + 22);
      canvas.drawCircle(
        avatarCenter,
        22,
        Paint()..color = const Color(0xFFE5E7FE),
      );

      final first = row.currency.trim().isEmpty
          ? '?'
          : row.currency.trim().substring(0, 1).toUpperCase();

      _drawText(
        canvas: canvas,
        text: first,
        x: avatarCenter.dx - 8,
        y: avatarCenter.dy - 12,
        maxWidth: 16,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4338CA),
        ),
        align: TextAlign.center,
        rtl: false,
      );

      final leftX = pagePad + 74;

      final currencyText =
          row.currency.trim().isEmpty ? 'Unknown currency' : row.currency.trim();

      _drawText(
        canvas: canvas,
        text: currencyText,
        x: leftX,
        y: rowTop + 12,
        maxWidth: 420,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0B1E3A),
        ),
        align: TextAlign.left,
        rtl: _isRtl(currencyText),
      );

      double inlineX = leftX;
      final metricY = rowTop + 58;

      if (!_isZero(row.credit)) {
        _drawText(
          canvas: canvas,
          text: 'Cr',
          x: inlineX,
          y: metricY,
          maxWidth: 30,
          style: const TextStyle(
            fontSize: 21,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
          align: TextAlign.left,
          rtl: false,
        );
        _drawText(
          canvas: canvas,
          text: _money(row.credit),
          x: inlineX + 34,
          y: metricY,
          maxWidth: 180,
          style: const TextStyle(
            fontSize: 21,
            color: Color(0xFF2E7D32),
            fontWeight: FontWeight.w700,
          ),
          align: TextAlign.left,
          rtl: false,
        );
        inlineX += 240;
      }

      if (!_isZero(row.debit)) {
        _drawText(
          canvas: canvas,
          text: 'Dr',
          x: inlineX,
          y: metricY,
          maxWidth: 30,
          style: const TextStyle(
            fontSize: 21,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
          align: TextAlign.left,
          rtl: false,
        );
        _drawText(
          canvas: canvas,
          text: _money(row.debit),
          x: inlineX + 34,
          y: metricY,
          maxWidth: 180,
          style: const TextStyle(
            fontSize: 21,
            color: Color(0xFFC62828),
            fontWeight: FontWeight.w700,
          ),
          align: TextAlign.left,
          rtl: false,
        );
      }

      _drawText(
        canvas: canvas,
        text: 'Balance',
        x: balanceBlockX,
        y: rowTop + 14,
        maxWidth: balanceBlockWidth,
        style: const TextStyle(
          fontSize: 20,
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.w500,
        ),
        align: TextAlign.center,
        rtl: false,
      );

      final balColor =
          row.balance >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

      _drawText(
        canvas: canvas,
        text: _money(row.balance),
        x: balanceBlockX,
        y: rowTop + 50,
        maxWidth: balanceBlockWidth,
        style: TextStyle(
          fontSize: 28,
          color: balColor,
          fontWeight: FontWeight.w700,
        ),
        align: TextAlign.center,
        rtl: false,
      );

      canvas.drawLine(
        Offset(pagePad, rowTop + rowHeight),
        Offset(width - pagePad, rowTop + rowHeight),
        Paint()
          ..color = const Color(0x12000000)
          ..strokeWidth = 1,
      );

      rowTop += rowHeight;
    }

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
      '${Directory.systemTemp.path}/balance_full_share_${DateTime.now().millisecondsSinceEpoch}.$ext',
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
    required bool rtl,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: rtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, Offset(x, y));
  }
}
