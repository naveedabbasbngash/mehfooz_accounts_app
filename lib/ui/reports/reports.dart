import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/global_state.dart';
import '../../services/pdf/open_file_service.dart';
import '../../theme/app_colors.dart';
import '../../viewmodel/reports/last_credit_view_model.dart';
import '../../viewmodel/reports/ledger_filter_view_model.dart';
import '../../viewmodel/reports/reports_view_model.dart';
import '../../repository/transactions_repository.dart';
import '../../repository/pending_repository.dart';
import '../../data/local/database_manager.dart';
import 'last_credit_summary_screen.dart';
import 'ledger_filter_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // ✅ NO eager loading here
      create: (_) => ReportsViewModel(
        repo: TransactionsRepository(DatabaseManager.instance.db),
        pendingRepo: PendingRepository(DatabaseManager.instance.db),
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
      backgroundColor: AppColors.app_bg,
      body: Stack(
        children: [
          // ================= MAIN CONTENT =================
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: SingleChildScrollView(
              physics: ui.loading
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildMainCard(context, vm, ui),
                ],
              ),
            ),
          ),

          // ================= LOADING OVERLAY =================
          if (ui.loading)
            Container(
              color: Colors.black.withOpacity(0.12), // softer, professional
              child: const Center(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // =====================================================
  // MAIN CARD
  // =====================================================
  Widget _buildMainCard(
      BuildContext context,
      ReportsViewModel vm,
      dynamic ui,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Generate Reports",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Select any option to export report PDF",
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 18),

          if (ui.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                "⚠ ${ui.error}",
                style: TextStyle(color: AppColors.error),
              ),
            ),

          // ---------------- BALANCE ----------------
          _reportButton(
            label: "Balance Report",
            icon: Icons.assessment_outlined,
            color: AppColors.primary,
            disabled: ui.loading,
            onTap: () async {
              final file = await vm.generateBalanceReport();
              if (file == null) {
                _toast(context, "No data available");
                return;
              }
              OpenFileService.openPdf(context, file);
            },
          ),

          const SizedBox(height: 12),

          // ---------------- CREDIT ----------------
          _reportButton(
            label: "Jama / Credit Report",
            icon: Icons.credit_score_outlined,
            color: AppColors.success,
            disabled: ui.loading,
            onTap: () async {
              final file = await vm.generateCreditReport();
              if (file == null) {
                _toast(context, "No credit data found");
                return;
              }
              OpenFileService.openPdf(context, file);
            },
          ),

          const SizedBox(height: 12),

          // ---------------- DEBIT ----------------
          _reportButton(
            label: "Banam / Debit Report",
            icon: Icons.trending_down_outlined,
            color: AppColors.error,
            disabled: ui.loading,
            onTap: () async {
              final file = await vm.generateDebitReport();
              if (file == null) {
                _toast(context, "No debit data found");
                return;
              }
              OpenFileService.openPdf(context, file);
            },
          ),

          const SizedBox(height: 12),

          // ---------------- PENDING ----------------
          _reportButton(
            label: "Pending Report",
            icon: Icons.schedule_outlined,
            color: Colors.orange,
            disabled: ui.loading,
            onTap: () async {
              final companyId = GlobalState.instance.companyId;
              final officeName = GlobalState.instance.companyName;

              if (companyId == null) {
                _toast(context, "Please select a company first");
                return;
              }

              final file = await vm.generatePendingReport(
                officeName: officeName ?? "Mehfooz Accounts",
                accId: 3,
                companyId: companyId,
              );

              if (file == null) {
                _toast(context, "No pending rows found");
                return;
              }

              OpenFileService.openPdf(context, file);
            },
          ),

          const SizedBox(height: 12),

          // ---------------- LEDGER FILTER ----------------
          _reportButton(
            label: "Ledger Report",
            icon: Icons.receipt_long_outlined,
            color: AppColors.primary,
            disabled: ui.loading,
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

          const SizedBox(height: 12),

          // ---------------- LAST CREDIT ----------------
          _reportButton(
            label: "Last Credit Summary",
            icon: Icons.summarize_outlined,
            color: AppColors.primary,
            disabled: ui.loading,
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
    );
  }

  // =====================================================
  // BUTTON
  // =====================================================
  Widget _reportButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}