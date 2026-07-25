// lib/ui/transactions/transaction_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../../model/tx_filter.dart';
import '../../model/tx_item_ui.dart';
import '../../model/user_model.dart';
import '../../repository/transactions_repository.dart';
import '../../data/local/database_manager.dart';
import '../../services/global_state.dart';
import '../../services/local_storage.dart';
import '../../theme/app_colors.dart';
import '../../viewmodel/home/home_view_model.dart';
import '../../viewmodel/sync/sync_viewmodel.dart';
import '../../viewmodel/transaction_view_model.dart';
import 'transaction_entry_tabs_screen.dart';

// Widgets
import 'widgets/tx_search_bar.dart';
import 'widgets/tx_filter_chips.dart';
import 'widgets/tx_list.dart';
import 'widgets/tx_details_panel.dart';
import 'widgets/balance_list.dart';

const _kTxBrandBlue = Color(0xFF1862A3);

class TransactionScreen extends StatelessWidget {
  const TransactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeViewModel>(
      builder: (context, homeVM, _) {
        final companyId =
            homeVM.selectedCompanyId ?? GlobalState.instance.companyId;

        return ChangeNotifierProvider(
          key: ValueKey('tx_vm_$companyId'),
          create: (_) => TransactionsViewModel(
            repo: TransactionsRepository(DatabaseManager.instance.db),
            companyId: companyId,
          ),
          child: const _TransactionScreenBody(),
        );
      },
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
  bool _isDeletingTx = false;
  bool _isBulkDeleting = false;
  bool _isOpeningEditor = false;
  bool _canCreateTransactions = true;
  final Set<int> _selectedVoucherNos = <int>{};

  bool get _isSelectionMode => _selectedVoucherNos.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadTransactionCreationAccess();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TransactionsViewModel>();

    final softBg = const Color(0xFFF4F8FC);
    final isBalanceMode = vm.filter == TxFilter.balance;

    return Scaffold(
      backgroundColor: softBg,
      floatingActionButton: _isSelectionMode || !_canCreateTransactions
          ? null
          : FloatingActionButton(
              heroTag: 'tx_fab_add',
              backgroundColor: _kTxBrandBlue,
              onPressed: _onAddTransactionTap,
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF7FBFF), Color(0xFFF2F7FC)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 18),
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
              const SizedBox(height: 10),
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
              const SizedBox(height: 14),
              if (_isSelectionMode)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _kTxBrandBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _kTxBrandBlue.withValues(alpha: 0.18),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 560;

                      final clearBtn = TextButton(
                        onPressed: (_isBulkDeleting || _isOpeningEditor)
                            ? null
                            : () => setState(() => _selectedVoucherNos.clear()),
                        child: const Text('Clear'),
                      );

                      final updateBtn = FilledButton.tonalIcon(
                        onPressed:
                            (_isBulkDeleting ||
                                _isOpeningEditor ||
                                _selectedVoucherNos.length != 1)
                            ? null
                            : _editSelectedTransaction,
                        icon: _isOpeningEditor
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.edit_outlined),
                        label: const Text('Update'),
                      );

                      final deleteBtn = FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: (_isBulkDeleting || _isOpeningEditor)
                            ? null
                            : _deleteSelectedTransactions,
                        icon: _isBulkDeleting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_outline),
                        label: const Text('Delete Selected'),
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${_selectedVoucherNos.length} selected',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: _kTxBrandBlue,
                                  ),
                                ),
                                const Spacer(),
                                clearBtn,
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(child: updateBtn),
                                const SizedBox(width: 8),
                                Expanded(child: deleteBtn),
                              ],
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Text(
                            '${_selectedVoucherNos.length} selected',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _kTxBrandBlue,
                            ),
                          ),
                          const Spacer(),
                          clearBtn,
                          const SizedBox(width: 4),
                          updateBtn,
                          const SizedBox(width: 6),
                          deleteBtn,
                        ],
                      );
                    },
                  ),
                ),

              // ------------------------------------------------------------
              // MAIN CONTENT
              // ------------------------------------------------------------
              Expanded(
                child: RefreshIndicator(
                  color: _kTxBrandBlue,
                  onRefresh: () async {
                    await context.read<SyncViewModel>().syncNowSingleFlight();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x121862A3),
                          blurRadius: 18,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      child: isBalanceMode
                          ? BalanceList(
                              name: vm.search,
                              rows: vm.balanceByCurrency,

                              onExportPdf: () async {
                                debugPrint("📄 PDF export requested");

                                final file = await vm
                                    .generateBalancePdfFromUi();

                                if (file == null) {
                                  debugPrint(
                                    "⚠️ PDF not generated (empty data)",
                                  );
                                  return;
                                }

                                debugPrint("✅ PDF generated at: ${file.path}");

                                await OpenFilex.open(file.path);
                              },
                            )
                          : TxList(
                              key: const ValueKey("LIST"),
                              items: vm.items,
                              selectedVoucherNos: _selectedVoucherNos,
                              onRowTap: (row) async {
                                if (_isSelectionMode) {
                                  _toggleVoucherSelection(row.voucherNo);
                                  return;
                                }
                                FocusScope.of(context).unfocus();
                                await Future.delayed(
                                  const Duration(milliseconds: 120),
                                );
                                setState(() {
                                  selectedRow = row;
                                  showDetails = true;
                                });
                              },
                              onRowLongPress: (row) {
                                _toggleVoucherSelection(row.voucherNo);
                              },
                            ),
                    ),
                  ),
                ),
              ),

              // ------------------------------------------------------------
              // DETAILS PANEL
              // ------------------------------------------------------------
              if (!_isSelectionMode && showDetails && selectedRow != null)
                SafeArea(
                  top: false,
                  bottom: true,
                  child: TxDetailsPanel(
                    row: selectedRow!,
                    onClose: () => setState(() => showDetails = false),
                    onDelete: _isDeletingTx ? null : _deleteSelectedTransaction,
                    isDeleting: _isDeletingTx,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadTransactionCreationAccess() async {
    final user = await LocalStorageService.loadLastUsedUser();
    if (!mounted) return;
    setState(() {
      _canCreateTransactions = _canCreateTransactionsFor(user);
    });
  }

  bool _canCreateTransactionsFor(UserModel? user) {
    final roles =
        user?.roleCodes
            .map((e) => e.trim().toUpperCase())
            .where((e) => e.isNotEmpty)
            .toSet() ??
        const <String>{};

    if (roles.contains('OWNER') ||
        roles.contains('ADMIN') ||
        roles.contains('ACCOUNTANT') ||
        roles.contains('MANAGER')) {
      return true;
    }

    if (roles.contains('VIEW') ||
        roles.contains('VIEWER') ||
        roles.contains('READONLY') ||
        roles.contains('READ_ONLY')) {
      return false;
    }

    return true;
  }

  Future<void> _onAddTransactionTap() async {
    if (!_canCreateTransactions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Viewer role has read-only access to transactions'),
        ),
      );
      return;
    }

    final vm = context.read<TransactionsViewModel>();

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            TransactionEntryTabsScreen(repo: vm.repo, companyId: vm.companyId),
      ),
    );

    if (saved == true && mounted) {
      await context.read<HomeViewModel>().setCompany(vm.companyId);
      _kickoffBackgroundSync();
    }
  }

  void _toggleVoucherSelection(int voucherNo) {
    setState(() {
      if (_selectedVoucherNos.contains(voucherNo)) {
        _selectedVoucherNos.remove(voucherNo);
      } else {
        _selectedVoucherNos.add(voucherNo);
      }
      if (_selectedVoucherNos.isNotEmpty) {
        showDetails = false;
        selectedRow = null;
      }
    });
  }

  Future<void> _deleteSelectedTransactions() async {
    if (_selectedVoucherNos.isEmpty || _isBulkDeleting) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected transactions?'),
        content: Text(
          'Move ${_selectedVoucherNos.length} selected transaction(s) to Trash?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Selected'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isBulkDeleting = true);
    try {
      final vm = context.read<TransactionsViewModel>();
      final voucherNos = _selectedVoucherNos.toList(growable: false);
      var processed = 0;
      for (final voucherNo in voucherNos) {
        await vm.repo.deleteTransactionWithLinkedEntries(
          companyId: vm.companyId,
          voucherNo: voucherNo,
        );
        processed++;
      }
      final complianceNotice = vm.repo.consumeLastComplianceNotice();

      if (!mounted) return;
      setState(() {
        _selectedVoucherNos.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            complianceNotice ?? '$processed transaction(s) moved to Trash',
          ),
        ),
      );
      await context.read<HomeViewModel>().setCompany(vm.companyId);
      _kickoffBackgroundSync();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete selected transactions: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isBulkDeleting = false);
      }
    }
  }

  Future<void> _editSelectedTransaction() async {
    if (_selectedVoucherNos.length != 1 || _isOpeningEditor) return;

    setState(() => _isOpeningEditor = true);
    try {
      final vm = context.read<TransactionsViewModel>();
      final voucherNo = _selectedVoucherNos.first;

      TxItemUi? selected;
      for (final item in vm.items) {
        if (item.voucherNo == voucherNo) {
          selected = item;
          break;
        }
      }

      final updated = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => TransactionEntryTabsScreen(
            repo: vm.repo,
            companyId: vm.companyId,
            editVoucherNo: voucherNo,
            openProductTab: selected?.hasQualitySpecs ?? false,
          ),
        ),
      );

      if (!mounted) return;
      if (updated == true) {
        setState(() => _selectedVoucherNos.clear());
        await context.read<HomeViewModel>().setCompany(vm.companyId);
        _kickoffBackgroundSync();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to open update form: $e')));
    } finally {
      if (mounted) setState(() => _isOpeningEditor = false);
    }
  }

  Future<void> _deleteSelectedTransaction() async {
    final row = selectedRow;
    if (row == null || _isDeletingTx) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text(
          'This will move the selected transaction and any linked cash entry to Trash.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isDeletingTx = true);
    try {
      final vm = context.read<TransactionsViewModel>();
      final deleted = await vm.repo.deleteTransactionWithLinkedEntries(
        companyId: vm.companyId,
        voucherNo: row.voucherNo,
      );
      final complianceNotice = vm.repo.consumeLastComplianceNotice();
      if (!mounted) return;
      setState(() {
        showDetails = false;
        selectedRow = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            complianceNotice ??
                (deleted > 1
                    ? 'Transaction and linked cash entry moved to Trash'
                    : 'Transaction moved to Trash'),
          ),
        ),
      );
      await context.read<HomeViewModel>().setCompany(vm.companyId);
      _kickoffBackgroundSync();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete transaction: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeletingTx = false);
      }
    }
  }

  // ------------------------------------------------------------
  // DATE PICKER
  // ------------------------------------------------------------
  Future<void> _openDatePickerSheet(
    BuildContext context,
    TransactionsViewModel vm,
  ) async {
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
                  leading: Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.primary,
                  ),
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
                        start: DateTime.now().subtract(const Duration(days: 3)),
                        end: DateTime.now(),
                      ),
                    );
                    if (picked != null) {
                      final s = picked.start.toIso8601String().substring(0, 10);
                      final e = picked.end.toIso8601String().substring(0, 10);
                      vm.setDateRange(s, e);
                      vm.setFilter(TxFilter.dateRange);
                    }
                  },
                ),

                if (vm.startDate != null || vm.endDate != null)
                  ListTile(
                    leading: Icon(Icons.clear, color: AppColors.error),
                    title: Text(
                      "Clear date filter",
                      style: TextStyle(color: AppColors.error),
                    ),
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

  void _kickoffBackgroundSync() {
    try {
      unawaited(
        context.read<SyncViewModel>().triggerSmartSync(immediate: true),
      );
    } catch (_) {
      // Sync VM may be absent in isolated previews/tests.
    }
  }
}
