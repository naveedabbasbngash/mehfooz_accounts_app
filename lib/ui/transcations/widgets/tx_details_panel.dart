// lib/ui/transactions/widgets/tx_details_panel.dart
import 'package:flutter/material.dart';
import '../../../model/tx_item_ui.dart';

class TxDetailsPanel extends StatelessWidget {
  final TxItemUi row;
  final VoidCallback onClose;

  const TxDetailsPanel({
    super.key,
    required this.row,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCredit = (row.crCents ?? 0) > 0;
    final int amount = isCredit ? (row.crCents ?? 0) : (row.drCents ?? 0);

    final Color amountColor =
    isCredit ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.fastOutSlowIn,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            blurRadius: 25,
            spreadRadius: 4,
            color: Colors.black.withOpacity(0.18),
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------------------------------------------------------------
            // HEADER ROW (Voucher + Close button)
            // ------------------------------------------------------------
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Voucher #${row.voucherNo}",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0B1E3A),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade200,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Divider(color: Colors.grey.shade300),

            const SizedBox(height: 16),

            // ------------------------------------------------------------
            // INFO GRID (beautiful spacing)
            // ------------------------------------------------------------
            _info("Name", row.name ?? "-"),
            _info("Date", row.date ?? "-"),
            _info("Currency", row.currency ?? "-"),

            if ((row.description ?? "").isNotEmpty)
              _info("Description", row.description ?? "-"),

            const SizedBox(height: 22),

            // ------------------------------------------------------------
            // AMOUNT — Bold, centered, Google style
            // ------------------------------------------------------------
            Center(
              child: Text(
                "${isCredit ? '+' : '-'}${_format(amount)}",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: amountColor,
                  letterSpacing: 0.3,
                ),
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Elegant info row
  // ------------------------------------------------------------
  Widget _info(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF0B1E3A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Thousands formatting (same as Kotlin grouping)
  // ------------------------------------------------------------
  String _format(int n) {
    final s = n.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < s.length; i++) {
      buffer.write(s[s.length - 1 - i]);
      if ((i + 1) % 3 == 0 && i + 1 != s.length) {
        buffer.write(',');
      }
    }

    return buffer.toString().split('').reversed.join('');
  }
}