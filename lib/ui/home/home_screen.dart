// lib/ui/home/home_screen_content.dart

import 'package:flutter/material.dart';
import 'package:mehfooz_accounts_app/theme/app_colors.dart';
import 'package:mehfooz_accounts_app/ui/home/widgets/home_header.dart';
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

// Sync
import '../../viewmodel/sync/sync_viewmodel.dart';

class HomeScreenContent extends StatefulWidget {
  const HomeScreenContent({super.key});

  @override
  State<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent> {
  bool cashExpanded = false;
  bool acc1Expanded = false;
  String pendingSearchText = "";

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeViewModel>(
      builder: (context, vm, _) {
        final pendingAmounts = vm.pendingAmounts;
        final isImporting = vm.isImporting;
        final companyId = vm.selectedCompanyId ?? 1;

        return Scaffold(
          backgroundColor: AppColors.app_bg,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---------------------------------------------------------
                  // HEADER
                  // ---------------------------------------------------------
                  HomeHeader(
                    vm: vm,
                    onChangeCompany: () =>
                        CompanySelectorBottomSheet.show(context, vm),
                  ),

                  const SizedBox(height: 10),

                  // ---------------------------------------------------------
                  // SYNC PROGRESS BAR (VIEWMODEL DRIVEN)
                  // ---------------------------------------------------------
                  Consumer<SyncViewModel>(
                    builder: (context, svm, _) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: svm.isSyncing ? 4 : 0,
                        margin: const EdgeInsets.only(top: 10, bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    },
                  ),

                  // ---------------------------------------------------------
                  // Cash In Hand Card
                  // ---------------------------------------------------------
                  CashInHandCard(
                    vm: vm,
                    isExpanded: cashExpanded,
                    onToggle: () =>
                        setState(() => cashExpanded = !cashExpanded),
                  ),

                  const SizedBox(height: 16),

                  // ---------------------------------------------------------
                  // AccID = 1 Summary Card
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
                  if (isImporting) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  ] else if (pendingAmounts.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Pending amounts by currency",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),

                        // ---------------------------------------------------------
                        // View All Button
                        // ---------------------------------------------------------
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChangeNotifierProvider(
                                  create: (_) => NotPaidViewModel(
                                    repository: TransactionsRepository(
                                      DatabaseManager.instance.db,
                                    ),
                                    accId: 3,
                                    companyId: companyId,
                                  )..loadRows(),
                                  child: const NotPaidGroupedScreen(),
                                ),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.open_in_full,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          label: Text(
                            "View All",
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    PendingAmountsList(
                      rows: pendingAmounts,
                      searchQuery: pendingSearchText,
                    ),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------
  // Relative time formatter
  // ---------------------------------------------------------
  String _timeAgo(DateTime? dt) {
    if (dt == null) return "";

    final diff = DateTime.now().difference(dt);

    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes} min ago";
    if (diff.inHours < 24) return "${diff.inHours} hours ago";

    return "${diff.inDays} days ago";
  }

  // ---------------------------------------------------------
  // Toast Notification
  // ---------------------------------------------------------
  void _showToast(BuildContext context, String message) {
    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor:
      message.startsWith("❌") ? AppColors.error : AppColors.success,
      content: Text(
        message,
        style: const TextStyle(fontSize: 14, color: Colors.white),
      ),
      duration: const Duration(seconds: 2),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}