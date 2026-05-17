import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/local/database_manager.dart';
import '../../repository/transactions_repository.dart';
import '../../services/global_state.dart';
import '../../services/pdf/open_file_service.dart';
import '../../viewmodel/reports/last_credit_view_model.dart';
import '../../viewmodel/reports/ledger_filter_view_model.dart';
import '../../viewmodel/reports/reports_view_model.dart';
import 'last_credit_summary_screen.dart';
import 'ledger_filter_screen.dart';
import 'subgroup_filter_screen.dart';

const Color _kReportsBlue = Color(0xFF1862A3);
const Color _kReportsBlueDark = Color(0xFF0F4E88);
const Color _kReportsBg = Color(0xFFF4F8FC);

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReportsViewModel(
        repo: TransactionsRepository(DatabaseManager.instance.db),
      ),
      child: const _ReportsScreenBody(),
    );
  }
}

class _ReportsScreenBody extends StatelessWidget {
  const _ReportsScreenBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportsViewModel>();
    final ui = vm.ui;

    return Scaffold(
      backgroundColor: _kReportsBg,
      body: Stack(
        children: [
          const _ReportsBackdrop(),
          SafeArea(
            child: SingleChildScrollView(
              physics: ui.loading
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (ui.error != null) ...[
                    _buildErrorBanner(ui.error.toString()),
                    const SizedBox(height: 16),
                  ],
                  _buildSectionLabel(),
                  const SizedBox(height: 12),
                  _buildReportTile(
                    context: context,
                    vm: vm,
                    ui: ui,
                    reportKey: 'subgroup',
                    label: 'Trail Balance',
                    subtitle:
                        'Export company balances in a polished PDF snapshot.',
                    icon: Icons.account_tree_outlined,
                    onTap: () async {
                      if (ui.subgroupFiltersEnabled) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MultiProvider(
                              providers: [
                                ChangeNotifierProvider.value(value: vm),
                                ChangeNotifierProvider(
                                  create: (_) => LedgerFilterViewModel(),
                                ),
                              ],
                              child: const TrailBalanceFilterScreen(),
                            ),
                          ),
                        );
                        return;
                      }
                      final file = await vm.generateSubgroupReport();
                      if (!context.mounted) return;
                      if (file == null) {
                        _toast(context, 'No data available');
                        return;
                      }
                      OpenFileService.openPdf(context, file);
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildReportTile(
                    context: context,
                    vm: vm,
                    ui: ui,
                    reportKey: 'ledger',
                    label: 'Ledger Report',
                    subtitle:
                        'Filter account activity and build a client-ready ledger.',
                    icon: Icons.receipt_long_outlined,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider(
                            create: (_) => LedgerFilterViewModel(),
                            child: const LedgerFilterScreen(),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildReportTile(
                    context: context,
                    vm: vm,
                    ui: ui,
                    reportKey: 'product_ledger',
                    label: 'Item Transaction Report',
                    subtitle:
                        'Review product movement with focused item-level reporting.',
                    icon: Icons.inventory_2_outlined,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider(
                            create: (_) => LedgerFilterViewModel(),
                            child: const LedgerFilterScreen(
                              screenTitle: 'Item Transaction Filter',
                              reportTitle: 'Item Transaction Report',
                              actionButtonLabel: 'Show Ledger',
                              generatingTitle:
                                  'Generating Item Transaction PDF',
                              outputPdfFileName: 'C.pdf',
                              includeProductColumns: true,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildReportTile(
                    context: context,
                    vm: vm,
                    ui: ui,
                    reportKey: 'last_credit',
                    label: 'Receivable Timeline Report',
                    subtitle:
                        'Track credit aging and recovery timing with more clarity.',
                    icon: Icons.timeline_outlined,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider(
                            create: (_) => LastCreditViewModel(
                              repo: TransactionsRepository(
                                DatabaseManager.instance.db,
                              ),
                              companyId: GlobalState.instance.companyId,
                            ),
                            child: const LastCreditSummaryScreen(),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel() {
    return const Padding(
      padding: EdgeInsets.only(left: 2),
      child: Text(
        'Available Reports',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: Color(0xFF12304F),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF4B8B0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFC9473D), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFA13630),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTile({
    required BuildContext context,
    required ReportsViewModel vm,
    required dynamic ui,
    required String reportKey,
    required String label,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isActive = ui.activeReportKey == reportKey;
    final isDisabled = ui.loading && !isActive;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isActive
                  ? _kReportsBlue.withValues(alpha: 0.42)
                  : const Color(0xFFD9E4F1),
            ),
            boxShadow: [
              BoxShadow(
                color: isActive
                    ? const Color(0x241862A3)
                    : const Color(0x0F10243E),
                blurRadius: isActive ? 24 : 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEAF5FF), Color(0xFFDDEEFE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: _kReportsBlue, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: isDisabled
                                  ? const Color(0xFF95A7BA)
                              : const Color(0xFF102C49),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.8,
                        height: 1.45,
                        color: isDisabled
                            ? const Color(0xFF9CAABA)
                            : const Color(0xFF60738A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _buildTrailingState(isActive: isActive),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrailingState({
    required bool isActive,
  }) {
    if (isActive) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF5FF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Padding(
          padding: EdgeInsets.all(11),
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(_kReportsBlue),
          ),
        ),
      );
    }

    return const SizedBox(
      width: 28,
      child: Center(
        child: Icon(
          Icons.arrow_forward_rounded,
          color: _kReportsBlue,
          size: 20,
        ),
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _kReportsBlueDark,
        content: Text(msg),
      ),
    );
  }
}

class _ReportsBackdrop extends StatelessWidget {
  const _ReportsBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: _kReportsBg),
        Positioned(
          top: -90,
          right: -70,
          child: Container(
            width: 220,
            height: 220,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x331862A3), Color(0x001862A3)],
              ),
            ),
          ),
        ),
        Positioned(
          top: 110,
          left: -90,
          child: Container(
            width: 190,
            height: 190,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x221862A3), Color(0x001862A3)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
