import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../model/tx_filter.dart';
import '../../model/tx_item_ui.dart';
import '../../repository/transactions_repository.dart';
import '../../data/local/database_manager.dart';

import '../../viewmodel/transaction_view_model.dart';

// Widgets
import 'widgets/tx_search_bar.dart';
import 'widgets/tx_filter_chips.dart';
import 'widgets/tx_list.dart';
import 'widgets/tx_details_panel.dart';
import 'widgets/balance_list.dart';

class TransactionScreen extends StatelessWidget {
  const TransactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TransactionsViewModel(
        repo: TransactionsRepository(DatabaseManager.instance.db),
      ),
      child: const _TransactionScreenBody(),
    );
  }
}

class _TransactionScreenBody extends StatefulWidget {
  const _TransactionScreenBody();

  @override
  State<_TransactionScreenBody> createState() => _TransactionScreenBodyState();
}

class _TransactionScreenBodyState extends State<_TransactionScreenBody> {
  bool showDetails = false;
  TxItemUi? selectedRow;

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<TransactionsViewModel>(context);

    const softBg = Color(0xFFF7F9FC);
    final isBalanceMode = vm.filter == TxFilter.balance;

    return Scaffold(
      backgroundColor: softBg,

      // 🔥 FIX #1 — safe area only on top (bottom=false)
      body: SafeArea(
        top: true,
        bottom: false,

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),

            // --------------------------------------------------
            // SEARCH BAR
            // --------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TxSearchBar(
                value: vm.search,
                onChanged: vm.setSearch,
                suggestions: vm.suggestions,
              ),
            ),

            const SizedBox(height: 12),

            // --------------------------------------------------
            // FILTER CHIPS BAR
            // --------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TxFilterChips(
                search: vm.search,
                filter: vm.filter,
                dateLabel: vm.dateLabel,

                onShowAll: () => vm.setFilter(TxFilter.all),
                onShowDebits: () => vm.setFilter(TxFilter.debit),
                onShowCredits: () => vm.setFilter(TxFilter.credit),
                onShowDates: () => _openDatePickerSheet(context, vm),
                onToggleBalance: () => vm.setFilter(TxFilter.balance),

                selectedCurrency: vm.selectedCurrency,
                currencies: vm.currencies,
                onCurrencySelect: vm.setSelectedCurrency,
              ),
            ),

            const SizedBox(height: 10),

            // --------------------------------------------------
            // MAIN CONTENT AREA (Animated)
            // --------------------------------------------------
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
                  boxShadow: [
                  BoxShadow(
                  blurRadius: 12,
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -1),
                  ) ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,

                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.03),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },

                  child: isBalanceMode
                      ? BalanceList(
                    key: const ValueKey("BALANCE"),
                    name: vm.search,
                    rows: vm.balanceByCurrency,
                  )
                      : TxList(
                    key: const ValueKey("LIST"),
                    items: vm.items,
                    onRowTap: (row) {
                      setState(() {
                        selectedRow = row;
                        showDetails = true;
                      });
                    },
                  ),
                ),
              ),
            ),

            // --------------------------------------------------
            // DETAILS PANEL
            // --------------------------------------------------
            if (showDetails && selectedRow != null)
              SafeArea(        // 🔥 FIX #2 — applies ONLY bottom safe area
                top: false,
                bottom: true,
                child: TxDetailsPanel(
                  row: selectedRow!,
                  onClose: () => setState(() => showDetails = false),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // DATE PICKER BOTTOM SHEET
  // ==========================================================================
  Future<void> _openDatePickerSheet(
      BuildContext context,
      TransactionsViewModel vm,
      ) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Select Date",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0B1E3A),
                ),
              ),

              const SizedBox(height: 16),

              // ---------------- Single Day --------------------
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text("Pick single day"),
                onTap: () async {
                  Navigator.pop(context);

                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    initialDate: DateTime.now(),
                  );

                  if (picked != null) {
                    final iso = picked.toIso8601String().substring(0, 10);
                    vm.setDateRange(iso, iso);
                    vm.setFilter(TxFilter.dateRange);
                  }
                },
              ),

              // ---------------- Range --------------------
              ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text("Pick date range"),
                onTap: () async {
                  Navigator.pop(context);

                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    initialDateRange: DateTimeRange(
                      start: DateTime.now().subtract(const Duration(days: 3)),
                      end: DateTime.now(),
                    ),
                  );

                  if (picked != null) {
                    final startIso =
                    picked.start.toIso8601String().substring(0, 10);
                    final endIso =
                    picked.end.toIso8601String().substring(0, 10);

                    vm.setDateRange(startIso, endIso);
                    vm.setFilter(TxFilter.dateRange);
                  }
                },
              ),

              // ---------------- Clear --------------------
              if (vm.startDate != null || vm.endDate != null)
                ListTile(
                  leading: const Icon(Icons.clear),
                  title: const Text("Clear date filter"),
                  onTap: () {
                    Navigator.pop(context);
                    vm.clearDateRange();
                    vm.setFilter(TxFilter.all);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}