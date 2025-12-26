// lib/ui/home/home_screen_content.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mehfooz_accounts_app/theme/app_colors.dart';
import 'package:mehfooz_accounts_app/ui/home/widgets/home_header.dart';
import 'package:provider/provider.dart';

import '../../repository/transactions_repository.dart';
import '../../viewmodel/home/home_view_model.dart';
import '../../data/local/database_manager.dart';

// Extracted Widgets
import '../../viewmodel/home/not_paid_view_model.dart';
import '../commons/confirm_action.dart';
import '../commons/confirm_action_dialog.dart';
import '../pending/pending_grouped_screen.dart';
import 'widgets/cash_in_hand_card.dart';
import 'widgets/acc1_summary_card.dart';
import 'widgets/pending_amounts_list.dart';
import 'widgets/company_selector_bottomsheet.dart';

// NEW
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

  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();

    // Background Auto Sync every 5 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      try {
        final svm = context.read<SyncViewModel>();
        if (!svm.isSyncing) {
          showDialog(
            context: context,
            builder: (_) => ConfirmActionDialog(
              action: ConfirmAction(
                type: ConfirmActionType.manualSync,
                title: "Sync Now",
                message:
                "This will sync local data with the server.\n\n"
                    "Make sure your internet connection is stable.",
                confirmText: "Sync",
                onConfirm: () async {
                  await svm.syncNow();
                },
              ),
            ),
          );        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

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
                  // SYNC PROGRESS BAR
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
                            color: AppColors.textDark, // UPDATED
                          ),
                        ),

                        // ---------------------------------------------------------
                        // View All Button — UPDATED
                        // ---------------------------------------------------------
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChangeNotifierProvider(
                                  create: (_) => NotPaidViewModel(
                                    repository:
                                    TransactionsRepository(
                                        DatabaseManager.instance.db),
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
                            color: AppColors.primary, // UPDATED
                            size: 18,
                          ),
                          label: Text(
                            "View All",
                            style: TextStyle(
                              color: AppColors.primary,  // UPDATED
                              fontSize: 14,
                              fontWeight: FontWeight.w700, // BOLD
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
  // Company Name Loader
  // ---------------------------------------------------------
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
  // Sync Menu Bottom Sheet
  // ---------------------------------------------------------
  void _openSyncMenu(BuildContext context, SyncViewModel svm) {
    showModalBottomSheet(
      context: context,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Sync Options",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark)),

              const SizedBox(height: 12),

              ListTile(
                leading: Icon(Icons.sync, color: AppColors.primary),
                title: Text("Sync Now",
                    style: TextStyle(color: AppColors.textDark)),
                onTap: () async {
                  Navigator.pop(context);
                  await svm.syncNow();
                  _showToast(context, svm.lastMessage);
                },
              ),

              ListTile(
                leading:
                Icon(Icons.history, color: AppColors.primary),
                title: Text("Sync History",
                    style: TextStyle(color: AppColors.textDark)),
                onTap: () => Navigator.pop(context),
              ),

              ListTile(
                leading:
                Icon(Icons.settings, color: AppColors.primary),
                title: Text("Sync Settings",
                    style: TextStyle(color: AppColors.textDark)),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
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