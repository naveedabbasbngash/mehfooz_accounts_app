import 'package:flutter/material.dart';
import '../../../model/pending_amount_row.dart';

class PendingAmountsScreen extends StatelessWidget {
  final List<PendingAmountRow> rows;
  final String title;

  const PendingAmountsScreen({
    super.key,
    required this.rows,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text(title),
      ),

      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final row = rows[index];

          final isPositive = row.balance >= 0;

          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.deepPurple.shade100,
                child: const Icon(Icons.currency_bitcoin, color: Colors.deepPurple),
              ),
              title: Text(
                row.currency,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                "CR: ${row.totalCr}  •  DR: ${row.totalDr}",
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Text(
                row.balance.toStringAsFixed(2),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}