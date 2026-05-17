import 'package:flutter/material.dart';

import '../../repository/transactions_repository.dart';
import 'transaction_entry_screen.dart';

const _kEntryBlue = Color(0xFF1862A3);
const _kEntryBlueDark = Color(0xFF0D4C81);

class TransactionEntryTabsScreen extends StatelessWidget {
  final TransactionsRepository repo;
  final int companyId;
  final int? editVoucherNo;
  final bool openProductTab;

  const TransactionEntryTabsScreen({
    super.key,
    required this.repo,
    required this.companyId,
    this.editVoucherNo,
    this.openProductTab = false,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: openProductTab ? 1 : 0,
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8FC),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_kEntryBlue, _kEntryBlueDark],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x221862A3),
                        blurRadius: 22,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.of(context).maybePop(),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  editVoucherNo == null
                                      ? 'New Entry'
                                      : 'Update Entry',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  editVoucherNo == null
                                      ? 'Create a clean debit, credit, or product transaction.'
                                      : 'Refine the transaction and save changes with confidence.',
                                  style: const TextStyle(
                                    color: Color(0xFFDCEBFA),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        height: 46,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const TabBar(
                          dividerColor: Colors.transparent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelColor: _kEntryBlue,
                          unselectedLabelColor: Colors.white,
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          unselectedLabelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          indicator: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.all(Radius.circular(14)),
                          ),
                          tabs: [
                            Tab(text: 'New Transaction'),
                            Tab(text: 'Product Transaction'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: TabBarView(
                    children: [
                      TransactionEntryScreen(
                        repo: repo,
                        companyId: companyId,
                        showAppBar: false,
                        editVoucherNo: editVoucherNo,
                      ),
                      TransactionEntryScreen(
                        repo: repo,
                        companyId: companyId,
                        showAppBar: false,
                        enableQualityFields: true,
                        editVoucherNo: editVoucherNo,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
