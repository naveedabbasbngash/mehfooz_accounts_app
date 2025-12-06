// lib/ui/home/widgets/pending_amounts_list.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:mehfooz_accounts_app/theme/app_colors.dart';
import '../../../model/pending_amount_row.dart';
import '../../../repository/transactions_repository.dart';
import '../../../viewmodel/home/home_view_model.dart';
import '../../../viewmodel/home/not_paid_view_model.dart';
import '../../../data/local/database_manager.dart';
import '../../pending/pending_grouped_screen.dart';

class PendingAmountsList extends StatelessWidget {
  final List<PendingAmountRow> rows;
  final String searchQuery;

  final NumberFormat fmt = NumberFormat('#,##0.00');

  PendingAmountsList({
    super.key,
    required this.rows,
    this.searchQuery = "",
  });

  // --------------------------------------------------------
  // HYBRID SMART FILTER
  // --------------------------------------------------------
  List<PendingAmountRow> _applyFilter() {
    if (searchQuery.trim().isEmpty) return rows;

    final q = searchQuery.trim().toLowerCase();
    final isNumeric = double.tryParse(q) != null;

    return rows.where((r) {
      final currency = r.currency.toLowerCase();
      final balanceStr = r.balance.toStringAsFixed(2);

      if (isNumeric) {
        return balanceStr == q || balanceStr.startsWith(q);
      }

      return currency.startsWith(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _applyFilter();

    if (filtered.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      itemCount: filtered.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final row = filtered[index];

        return AnimatedOpacity(
          opacity: 1,
          duration: const Duration(milliseconds: 250),
          child: GestureDetector(
            onTap: () {
              final companyId = Provider.of<HomeViewModel>(
                context,
                listen: false,
              ).selectedCompanyId ?? 1;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) {
                    return ChangeNotifierProvider(
                      create: (_) => NotPaidViewModel(
                        repository: TransactionsRepository(
                          DatabaseManager.instance.db,
                        ),
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
                    // LEFT ICON
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary.withOpacity(0.10),
                      child: Icon(
                        Icons.currency_exchange,
                        color: AppColors.primary,
                      ),
                    ),

                    const SizedBox(width: 16),

                    // MAIN TEXTS
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Currency Title
                          Text(
                            row.currency,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.textDark,
                            ),
                          ),

                          const SizedBox(height: 6),

                          // Balance ONLY (CR/DR removed)
                          Text(
                            "Balance: ${fmt.format(row.balance)}",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,   // BOLD
                              color: AppColors.primary,      // PRIMARY COLOR
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // CHEVRON ARROW UPDATED
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.primary,  // PRIMARY COLOR
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}