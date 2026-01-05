import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../model/tx_item_ui.dart';

class TxListRow extends StatelessWidget {
  final TxItemUi item;
  final VoidCallback onTap;

  const TxListRow({
    super.key,
    required this.item,
    required this.onTap,
  });

  // ------------------------------------------------------------
  // Decimal formatter (REAL money)
  // ------------------------------------------------------------
  static final NumberFormat _fmt = NumberFormat('#,##0.00');

  String _fmtDouble(double v) {
    final safe = v.abs() < 0.005 ? 0.0 : v; // kill -0.00
    return _fmt.format(safe);
  }

  @override
  Widget build(BuildContext context) {
    final bool isCredit = item.cr > 0;
    final double amount = item.amount;

    final name = item.name.isNotEmpty ? item.name : "-";
    final date = item.date.isNotEmpty ? item.date : "-";
    final desc = item.description ?? "";
    final currency = item.currency.isNotEmpty ? item.currency : "-";

    final Color amountColor = isCredit
        ? const Color(0xFF2E7D32) // Google Green
        : const Color(0xFFC62828); // Google Red

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // =========================================================
            // LEFT — Avatar
            // =========================================================
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _avatarColor(name),
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : "?",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            const SizedBox(width: 14),

            // =========================================================
            // MIDDLE — Date / Name / Description
            // =========================================================
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF0B1E3A),
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (desc.isNotEmpty)
                    Text(
                      desc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // =========================================================
            // RIGHT — Amount + Currency
            // =========================================================
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${isCredit ? '+' : '-'}${_fmtDouble(amount)}",
                  style: TextStyle(
                    fontSize: 17,
                    color: amountColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  currency,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Avatar color (stable hash)
  // ------------------------------------------------------------
  Color _avatarColor(String name) {
    if (name.trim().isEmpty) return const Color(0xFF6C5CE7);

    final palette = const [
      Color(0xFF6C5CE7),
      Color(0xFF00B894),
      Color(0xFF0984E3),
      Color(0xFFFF7675),
      Color(0xFFFD79A8),
      Color(0xFF00CEC9),
      Color(0xFF74B9FF),
      Color(0xFFA29BFE),
    ];

    final idx = name.toLowerCase().hashCode.abs() % palette.length;
    return palette[idx];
  }
}