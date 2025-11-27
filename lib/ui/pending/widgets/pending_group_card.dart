import 'package:flutter/material.dart';
import '../../../model/pending_group_row.dart';

class PendingGroupCard extends StatefulWidget {
  final PendingGroupRow row;

  const PendingGroupCard({super.key, required this.row});

  @override
  State<PendingGroupCard> createState() => _PendingGroupCardState();
}

class _PendingGroupCardState extends State<PendingGroupCard> {
  bool expanded = true;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final isNegative = row.balance < 0;

    return GestureDetector(
      onTap: () => setState(() => expanded = !expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.fastOutSlowIn,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: expanded
            ? _expandedView(row, isNegative)
            : _collapsedView(row, isNegative),
      ),
    );
  }

  // ============================================================
  // COLLAPSED VIEW (currency dominant on right)
  // ============================================================
  Widget _collapsedView(PendingGroupRow row, bool isNegative) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row: date + PD + currency + balance
        Row(
          children: [
            // DATE + PD grouped left
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.beginDate,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),

                if (row.pd != null && row.pd!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.deepPurple.shade100),
                    ),
                    child: Text(
                      "PD: ${row.pd}",
                      style: const TextStyle(
                        color: Colors.deepPurple,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),

            const Spacer(),

            // CURRENCY TAG (dominant)
            if (row.accTypeName != null)
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.deepPurple.shade200),
                ),
                child: Text(
                  row.accTypeName!,
                  style: const TextStyle(
                    color: Colors.deepPurple,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

            const SizedBox(width: 12),

            // BALANCE
            Text(
              row.balance.toString(),
              style: TextStyle(
                color: isNegative ? Colors.red : Colors.green.shade700,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Sender + Receiver horizontally
        Row(
          children: [
            const Text(
              "S: ",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            Expanded(
              child: Text(
                row.sender ?? "—",
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black87),
              ),
            ),
            const SizedBox(width: 16),
            const Text(
              "R: ",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            Expanded(
              child: Text(
                row.receiver ?? "—",
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // EXPANDED VIEW (full details - premium UI)
  // ============================================================
  Widget _expandedView(PendingGroupRow row, bool isNegative) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // HEADER ROW
        Row(
          children: [
            // Left: DATE + PD grouped
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.beginDate,
                  style: const TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),

                if (row.pd != null && row.pd!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.deepPurple.shade200),
                    ),
                    child: Text(
                      "PD: ${row.pd}",
                      style: const TextStyle(
                        color: Colors.deepPurple,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),

            const Spacer(),

            // CURRENCY TAG
            if (row.accTypeName != null)
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.deepPurple.shade200),
                ),
                child: Text(
                  row.accTypeName!,
                  style: const TextStyle(
                    color: Colors.deepPurple,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

            const SizedBox(width: 10),

            // BALANCE
            Text(
              row.balance.toString(),
              style: TextStyle(
                color: isNegative ? Colors.red : Colors.green.shade700,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ],
        ),

        if (row.msgNo?.isNotEmpty ?? false) ...[
          const SizedBox(height: 6),
          Text(
            "Msg: ${row.msgNo}",
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],

        const SizedBox(height: 16),

        // Sender row
        _line("Sender", row.sender ?? "—"),

        const SizedBox(height: 8),

        // Receiver row
        _line("Receiver", row.receiver ?? "—"),

        const SizedBox(height: 18),

        // Amount summary row
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _amountPill("P.Amount", row.notPaidAmount.toString()),
              _amountPill("Paid", row.paidAmount.toString()),
              _amountPill("Balance", row.balance.toString(), bold: true),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Helper: Sender/Receiver rows
  // ============================================================
  Widget _line(String label, String value) {
    return Row(
      children: [
        Text(
          "$label: ",
          style: const TextStyle(
            color: Colors.deepPurple,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Helper: Amount pill
  // ============================================================
  Widget _amountPill(String label, String value, {bool bold = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.deepPurple,
              fontSize: bold ? 18 : 16,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}