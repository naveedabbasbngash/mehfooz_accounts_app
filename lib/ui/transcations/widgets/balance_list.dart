import 'package:flutter/material.dart';
import '../../../model/balance_currency_ui.dart';

class BalanceList extends StatelessWidget {
  final String name; // text from search – for header
  final List<BalanceCurrencyUi> rows;

  const BalanceList({
    super.key,
    required this.name,
    required this.rows,
  });

  String _fmtInt(int n) {
    final s = n.toString();
    if (s.isEmpty) return '0';
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      buf.write(s[s.length - 1 - i]);
      if ((i + 1) % 3 == 0 && i + 1 != s.length) {
        buf.write(',');
      }
    }
    return buf.toString().split('').reversed.join();
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            name.trim().isEmpty
                ? "Type a name to view balance"
                : "No balance data for this person",
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (name.trim().isNotEmpty)
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              "Balance • $name",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0B1E3A),
              ),
            ),
          ),

        const Divider(height: 1, color: Color(0x14000000)),

        Expanded(
          child: ListView.separated(
            padding:
            const EdgeInsets.only(left: 12, right: 12, bottom: 16, top: 8),
            itemCount: rows.length,
            separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Color(0x14000000)),
            itemBuilder: (_, i) {
              final row = rows[i];
              final bal = row.balanceCents;
              final isPositive = bal >= 0;
              final balColor =
              isPositive ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

              return Padding(
                padding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Currency label circle
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7FE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        row.currency.isEmpty
                            ? "?"
                            : row.currency.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4338CA),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Middle: currency name + credit/debit
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.currency.isEmpty
                                ? "Unknown currency"
                                : row.currency,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0B1E3A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Text(
                                "Cr ",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              Text(
                                _fmtInt(row.creditCents),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF2E7D32),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "Dr ",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              Text(
                                _fmtInt(row.debitCents),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFC62828),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Right: Balance
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          "Balance",
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _fmtInt(bal),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: balColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}