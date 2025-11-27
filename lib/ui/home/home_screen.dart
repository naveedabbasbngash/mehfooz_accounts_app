import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../repository/transactions_repository.dart';
import '../../viewmodel/home/home_view_model.dart';
import '../../data/local/database_manager.dart';

// Extracted Widgets
import '../../viewmodel/home/not_paid_view_model.dart';
import '../pending/pending_grouped_screen.dart';
import 'widgets/cash_in_hand_card.dart';
import 'widgets/acc1_summary_card.dart';
import 'widgets/pending_amounts_list.dart';
import 'widgets/company_selector_bottomsheet.dart';

class HomeScreenContent extends StatefulWidget {
  const HomeScreenContent({super.key});

  @override
  State<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent> {
  bool cashExpanded = false;
  bool acc1Expanded = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeViewModel>(
      builder: (context, vm, _) {
        final pendingAmounts = vm.pendingAmounts;
        final isImporting = vm.isImporting;
        final companyId = vm.selectedCompanyId ?? 1;

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---------------------------------------------------------
                  // Header
                  // ---------------------------------------------------------
                  FutureBuilder<String?>(
                    future: _getCompanyName(vm),
                    builder: (context, snapshot) {
                      final name = snapshot.data ?? "Mahfooz Accounts";

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Welcome",
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () =>
                                CompanySelectorBottomSheet.show(context, vm),
                            icon: const Icon(Icons.swap_horiz,
                                size: 18, color: Colors.deepPurple),
                            label: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Change company",
                                  style: TextStyle(
                                    color: Colors.deepPurple,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(Icons.keyboard_arrow_down,
                                    size: 18, color: Colors.deepPurple),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // ---------------------------------------------------------
                  // Cash In Hand
                  // ---------------------------------------------------------
                  CashInHandCard(
                    vm: vm,
                    isExpanded: cashExpanded,
                    onToggle: () =>
                        setState(() => cashExpanded = !cashExpanded),
                  ),

                  const SizedBox(height: 16),

                  // ---------------------------------------------------------
                  // ACC ID = 1 Summary Card
                  // ---------------------------------------------------------
                  Acc1SummaryCard(
                    vm: vm,
                    isExpanded: acc1Expanded,
                    onToggle: () =>
                        setState(() => acc1Expanded = !acc1Expanded),
                  ),

                  const SizedBox(height: 24),

                  // ---------------------------------------------------------
                  // Pending Amounts Section
                  // ---------------------------------------------------------
                  if (isImporting)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Pending amounts by currency",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        // -------------------------------------------------
                        // View All → NotPaidGroupedScreen
                        // -------------------------------------------------
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChangeNotifierProvider(
                                  create: (_) => NotPaidViewModel(
                                    repository: TransactionsRepository(
                                        DatabaseManager.instance.db),
                                    accId: 3,
                                    companyId: companyId,
                                  )..loadRows(),
                                  child: const NotPaidGroupedScreen(),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.open_in_full,
                              color: Colors.deepPurple),
                          label: const Text(
                            "View All",
                            style: TextStyle(
                              color: Colors.deepPurple,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    PendingAmountsList(rows: pendingAmounts),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _getCompanyName(HomeViewModel vm) async {
    final selectedId = vm.selectedCompanyId;
    if (selectedId == null) return null;

    final db = DatabaseManager.instance.db;
    final result = await (db.select(db.companyTable)
      ..where((tbl) => tbl.companyId.equals(selectedId)))
        .get();

    return result.isNotEmpty
        ? result.first.companyName ?? "Your Company"
        : "Your Company";
  }
}