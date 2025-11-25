import 'package:flutter/material.dart';
import '../../../model/pending_amount_row.dart';
import '../../pending_amount/pending_amounts_screen.dart';

class PendingAmountsList extends StatelessWidget {
  final List<PendingAmountRow> rows;

  const PendingAmountsList({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 20),
        child: Center(
          child: Text(
            "No pending amounts to show.",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: rows.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final row = rows[index];
        final isPositive = row.balance >= 0;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.deepPurple.shade50,
              child: const Icon(
                Icons.currency_exchange,
                size: 18,
                color: Colors.deepPurple,
              ),
            ),
            title: Text(
              row.currency,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              "CR: ${row.totalCr}  •  DR: ${row.totalDr}",
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              size: 22,
              color: Colors.deepPurple,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PendingAmountsScreen(
                    rows: [row],
                    title: "${row.currency} Pending Amounts",
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}