// lib/ui/transactions/transaction_screen.dart

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../../model/tx_filter.dart';
import '../../model/tx_item_ui.dart';
import '../../repository/transactions_repository.dart';
import '../../data/local/database_manager.dart';
import '../../services/global_state.dart';
import '../../theme/app_colors.dart';
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
    final companyId = GlobalState.instance.companyId; // 🔥 FIX

    return ChangeNotifierProvider(
      create: (_) => TransactionsViewModel(
        repo: TransactionsRepository(DatabaseManager.instance.db),
        companyId: companyId, // 🔥 PASS COMPANY
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
    final vm = context.watch<TransactionsViewModel>();

    final softBg = const Color(0xFFF7F9FC);
    final isBalanceMode = vm.filter == TxFilter.balance;

    return Scaffold(
      backgroundColor: softBg,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),

            // ------------------------------------------------------------
            // SEARCH BAR
            // ------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TxSearchBar(
                value: vm.search,
                onChanged: vm.setSearch,
                suggestions: vm.suggestions,
                onFocus: () {
                  setState(() => showDetails = false);
                },
              ),
            ),

            const SizedBox(height: 12),

            // ------------------------------------------------------------
            // FILTER CHIPS
            // ------------------------------------------------------------
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

            // ------------------------------------------------------------
            // MAIN CONTENT
            // ------------------------------------------------------------
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, -1),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: isBalanceMode
                      ?
                  BalanceList(
                    name: vm.search,
                    rows: vm.balanceByCurrency,

                    onExportPdf: () async {
                      debugPrint("📄 PDF export requested");

                      final file = await vm.generateBalancePdfFromUi();

                      if (file == null) {
                        debugPrint("⚠️ PDF not generated (empty data)");
                        return;
                      }

                      debugPrint("✅ PDF generated at: ${file.path}");

                      await OpenFilex.open(file.path);
                    },
                  )                      : TxList(
                    key: const ValueKey("LIST"),
                    items: vm.items,
                    onRowTap: (row) async {
                      FocusScope.of(context).unfocus();
                      await Future.delayed(
                          const Duration(milliseconds: 120));
                      setState(() {
                        selectedRow = row;
                        showDetails = true;
                      });
                    },
                  ),
                ),
              ),
            ),

            // ------------------------------------------------------------
            // DETAILS PANEL
            // ------------------------------------------------------------
            if (showDetails && selectedRow != null)
              SafeArea(
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

  // ------------------------------------------------------------
  // DATE PICKER
  // ------------------------------------------------------------
  Future<void> _openDatePickerSheet(
      BuildContext context, TransactionsViewModel vm) async {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 10, 18, 20 + bottomPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Select Date",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 16),

                ListTile(
                  leading: Icon(Icons.calendar_today_outlined,
                      color: AppColors.primary),
                  title: Text("Pick single day"),
                  onTap: () async {
                    Navigator.pop(context);
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      initialDate: DateTime.now(),
                    );
                    if (picked != null) {
                      final d = picked.toIso8601String().substring(0, 10);
                      vm.setDateRange(d, d);
                      vm.setFilter(TxFilter.dateRange);
                    }
                  },
                ),

                ListTile(
                  leading: Icon(Icons.date_range, color: AppColors.primary),
                  title: Text("Pick date range"),
                  onTap: () async {
                    Navigator.pop(context);
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      initialDateRange: DateTimeRange(
                        start:
                        DateTime.now().subtract(const Duration(days: 3)),
                        end: DateTime.now(),
                      ),
                    );
                    if (picked != null) {
                      final s =
                      picked.start.toIso8601String().substring(0, 10);
                      final e = picked.end.toIso8601String().substring(0, 10);
                      vm.setDateRange(s, e);
                      vm.setFilter(TxFilter.dateRange);
                    }
                  },
                ),

                if (vm.startDate != null || vm.endDate != null)
                  ListTile(
                    leading: Icon(Icons.clear, color: AppColors.error),
                    title: Text("Clear date filter",
                        style: TextStyle(color: AppColors.error)),
                    onTap: () {
                      Navigator.pop(context);
                      vm.clearDateRange();
                      vm.setFilter(TxFilter.all);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}