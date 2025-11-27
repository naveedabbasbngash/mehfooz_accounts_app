import 'package:flutter/material.dart';
import '../../../model/tx_item_ui.dart' show TxItemUi;

class TxListRow extends StatelessWidget {
  final TxItemUi item;
  final VoidCallback onTap;

  const TxListRow({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCredit = (item.crCents ?? 0) > 0;
    final int amount = isCredit ? (item.crCents ?? 0) : (item.drCents ?? 0);

    final name = item.name ?? "-";
    final date = item.date ?? "-";
    final desc = item.description ?? "";
    final currency = item.currency ?? "-";

    final Color amountColor = isCredit
        ? const Color(0xFF2E7D32)          // Google Green
        : const Color(0xFFC62828);         // Google Red

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // =========================================================
            //   LEFT — Avatar bubble (Google Contact Letter Style)
            // =========================================================
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _avatarColor(name),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
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
            //   MIDDLE — Date / Name / Description
            // =========================================================
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // DATE
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 3),

                  // NAME
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

                  // DESCRIPTION — slightly faded, subtle
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
            //   RIGHT — Amount + Currency
            // =========================================================
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${isCredit ? '+' : '-'}${_format(amount)}",
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

  // =========================================================
  // Avatar Color — Using same hash technique as Kotlin
  // =========================================================
  Color _avatarColor(String name) {
    if (name.trim().isEmpty) return const Color(0xFF6C5CE7);

    final palette = [
      0xFF6C5CE7, // Purple
      0xFF00B894, // Green
      0xFF0984E3, // Blue
      0xFFFF7675, // Red
      0xFFFD79A8, // Pink
      0xFF00CEC9, // Cyan
      0xFF74B9FF, // Light Blue
      0xFFA29BFE, // Lavender
    ].map((e) => Color(e)).toList();

    final idx = name.toLowerCase().hashCode.abs() % palette.length;
    return palette[idx];
  }

  // Simple abs() extension
  extensionAbs(int v) => v < 0 ? -v : v;

  // =========================================================
  // Format digits (1,234,567)
  // =========================================================
  String _format(int n) {
    final s = n.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < s.length; i++) {
      buffer.write(s[s.length - 1 - i]);
      if ((i + 1) % 3 == 0 && i + 1 != s.length) {
        buffer.write(',');
      }
    }

    return buffer.toString().split('').reversed.join();
  }
}

extension on int {
  int abs() => this < 0 ? -this : this;
}