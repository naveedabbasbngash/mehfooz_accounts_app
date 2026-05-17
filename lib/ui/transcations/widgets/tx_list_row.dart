import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../model/tx_item_ui.dart';

const _kTxBrandBlue = Color(0xFF1862A3);

class TxListRow extends StatelessWidget {
  final TxItemUi item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  const TxListRow({
    super.key,
    required this.item,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
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
    final hasDescription = desc.isNotEmpty;
    final currency = item.currency.isNotEmpty ? item.currency : "-";

    final Color amountColor = isCredit
        ? _kTxBrandBlue
        : const Color(0xFFC62828);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            if (isSelected) ...[
              const Icon(
                Icons.check_circle,
                color: _kTxBrandBlue,
                size: 20,
              ),
              const SizedBox(width: 10),
            ],
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
                    color: Color(0x141862A3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : "?",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
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
                      fontSize: 10.8,
                      color: const Color(0xFF7A8DA3),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
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
                        fontSize: 12,
                        color: const Color(0xFF6F8094),
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
                SizedBox(height: hasDescription ? 4 : 9),
                Text(
                  "${isCredit ? '+' : '-'}${_fmtDouble(amount)}",
                  style: TextStyle(
                    fontSize: 15,
                    color: amountColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  currency,
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF73869D),
                    fontWeight: FontWeight.w600,
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
    if (name.trim().isEmpty) return _kTxBrandBlue;

    final palette = const [
      Color(0xFF1862A3),
      Color(0xFF1E4F8C),
      Color(0xFF2973B2),
      Color(0xFF3B82C4),
      Color(0xFF0D4C81),
      Color(0xFF27667B),
      Color(0xFF2C7DA0),
      Color(0xFF457B9D),
    ];

    final idx = name.toLowerCase().hashCode.abs() % palette.length;
    return palette[idx];
  }
}
