// lib/ui/home/widgets/pending_amounts_list.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:mehfooz_accounts_app/theme/app_colors.dart';
import '../../../model/pending_amount_row.dart';
import '../../../viewmodel/home/home_view_model.dart';
import '../../../viewmodel/home/not_paid_view_model.dart';
import '../../pending/pending_grouped_screen.dart';
import '../../commons/currency_flag.dart';

class PendingAmountsList extends StatelessWidget {
  final List<PendingAmountRow> rows;
  final String searchQuery;

  final NumberFormat fmt = NumberFormat('#,##0.00');

  PendingAmountsList({super.key, required this.rows, this.searchQuery = ""});

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
        return balanceStr.startsWith(q);
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

        return GestureDetector(
          onTap: () {
            final companyId =
                Provider.of<HomeViewModel>(
                  context,
                  listen: false,
                ).selectedCompanyId ??
                1;

            Navigator.push(
              context,
              PageRouteBuilder(
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
                pageBuilder: (context, animation, secondary) {
                  return ChangeNotifierProvider(
                    create: (_) => NotPaidViewModel(
                      accId: 3,
                      companyId: companyId,
                      currencyFilter: row.currency,
                    ),
                    child: NotPaidGroupedScreen(filterCurrency: row.currency),
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
                  // ------------------------------------------------
                  // LEFT: Currency Flag
                  // ------------------------------------------------
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.transparent,
                    child: CurrencyFlagBadge(currency: row.currency, size: 36),
                  ),
                  const SizedBox(width: 16),

                  // ------------------------------------------------
                  // CENTER: Texts
                  // ------------------------------------------------
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Currency Code
                        Text(
                          row.currency,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.textDark,
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Balance (Professional light-black style)
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: "Balance: ",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              TextSpan(
                                text: fmt.format(row.balance),
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ------------------------------------------------
                  // RIGHT: Circular Chevron
                  // ------------------------------------------------
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.08),
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
