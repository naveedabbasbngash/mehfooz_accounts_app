import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../model/pending_amount_row.dart';
import '../../../repository/transactions_repository.dart';
import '../../../viewmodel/home/home_view_model.dart';
import '../../../viewmodel/home/not_paid_view_model.dart';
import '../../../data/local/database_manager.dart';
import '../../pending/pending_grouped_screen.dart';

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

        return GestureDetector(
          onTap: () {
            print("DEBUG: Tapped currency = ${row.currency}");

            final companyId = Provider.of<HomeViewModel>(context, listen: false)
                .selectedCompanyId ?? 1;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) {
                  return ChangeNotifierProvider(
                    create: (_) => NotPaidViewModel(
                      repository: TransactionsRepository(
                          DatabaseManager.instance.db),
                      accId: 3,
                      companyId: companyId,
                    )..loadRows(),
                    child: NotPaidGroupedScreen(
                      filterCurrency: row.currency,
                    ),
                  );
                },
              ),
            );
          },
          child: Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.deepPurple.shade50,
                    child: const Icon(
                      Icons.currency_exchange,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.currency,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "CR: ${row.totalCr} • DR: ${row.totalDr}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Balance: ${row.balance.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isPositive ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.chevron_right, color: Colors.deepPurple),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}