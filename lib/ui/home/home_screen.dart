import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodel/home/home_view_model.dart';
import '../../data/local/database_manager.dart';
import '../pending_amount/pending_amounts_screen.dart';

// Extracted Widgets
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

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [

                        // ################################################
                        //               HEADER (Welcome)
                        // ################################################
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

                                // Change company chip
                                TextButton.icon(
                                  onPressed: () => CompanySelectorBottomSheet.show(context, vm),
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
                                            fontWeight: FontWeight.w500),
                                      ),
                                      SizedBox(width: 2),
                                      Icon(Icons.keyboard_arrow_down,
                                          size: 18, color: Colors.deepPurple),
                                    ],
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 24),

                        // ################################################
                        //           CASH IN HAND CARD
                        // ################################################
                        CashInHandCard(
                          vm: vm,
                          isExpanded: cashExpanded,
                          onToggle: () {
                            setState(() => cashExpanded = !cashExpanded);
                          },
                        ),

                        const SizedBox(height: 16),

                        // ################################################
                        //      ACCID = 1 SUMMARY CARD
                        // ################################################
                        Acc1SummaryCard(
                          vm: vm,
                          isExpanded: acc1Expanded,
                          onToggle: () {
                            setState(() => acc1Expanded = !acc1Expanded);
                          },
                        ),

                        const SizedBox(height: 24),

                        // ################################################
                        //           PENDING AMOUNTS SECTION
                        // ################################################
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

                              // "View All" moved here
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PendingAmountsScreen(
                                        rows: pendingAmounts,
                                        title: "All Pending Amounts",
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

                          // Inline list
                          PendingAmountsList(rows: pendingAmounts),
                        ],

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ----------------------------------------------------
  // Fetch company name
  // ----------------------------------------------------
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