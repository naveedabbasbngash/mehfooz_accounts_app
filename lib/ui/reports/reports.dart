import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/pdf/open_file_service.dart';
import '../../viewmodel/reports/reports_view_model.dart';
import '../../repository/transactions_repository.dart';
import '../../data/local/database_manager.dart';


class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReportsViewModel(
        repo: TransactionsRepository(DatabaseManager.instance.db),
      )..loadBalanceMatrix(),
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

    const softBg = Color(0xFFF7F9FC);      // same as Home/Transactions
    const deepBlue = Color(0xFF0B1E3A);    // your brand primary

    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        backgroundColor: softBg,
        elevation: 0,
        title: const Text(
          "Reports",
          style: TextStyle(
            color: deepBlue,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ---------------------- MAIN CARD ----------------------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Generate Reports",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: deepBlue,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      "Select a report to export as PDF",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ---------------------- LOADING ----------------------
                    if (ui.loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 18),
                          child: CircularProgressIndicator(),
                        ),
                      ),

                    // ---------------------- ERROR ----------------------
                    if (ui.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Text(
                          "⚠ Error: ${ui.error}",
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),

                    // ---------------------- BUTTONS ----------------------
                    _reportButton(
                      label: "Balance Report",
                      icon: Icons.assessment_outlined,
                      color: deepBlue,
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

                    _reportButton(
                      label: "Jama / Credit Report",
                      icon: Icons.credit_score_outlined,
                      color: Colors.green.shade700,
                      onTap: () {
                        _toast(context, "Feature not implemented yet");
                      },
                    ),

                    const SizedBox(height: 12),

                    _reportButton(
                      label: "Banam / Debit Report",
                      icon: Icons.trending_down_outlined,
                      color: Colors.red.shade700,
                      onTap: () {
                        _toast(context, "Feature not implemented yet");
                      },
                    ),

                    const SizedBox(height: 12),

                    _reportButton(
                      label: "Pending Report",
                      icon: Icons.schedule_outlined,
                      color: Colors.orange.shade700,
                      onTap: () {
                        _toast(context, "Feature not implemented yet");
                      },
                    ),

                    const SizedBox(height: 12),

                    _reportButton(
                      label: "Ledger Report",
                      icon: Icons.receipt_long_outlined,
                      color: deepBlue,
                      onTap: () {
                        _toast(context, "Navigate to Ledger Filter Screen");
                      },
                    ),

                    const SizedBox(height: 12),

                    _reportButton(
                      label: "Last Credit Summary",
                      icon: Icons.summarize_outlined,
                      color: Colors.teal.shade700,
                      onTap: () {
                        _toast(context, "Feature not implemented yet");
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------
  // BEAUTIFUL UNIFIED REPORT BUTTON (Google Material 3 Inspired)
  // --------------------------------------------------------------------
  Widget _reportButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepPurple,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey,
              size: 22,
            ),
          ],
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