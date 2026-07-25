// lib/ui/home/home_screen_content.dart

import 'package:flutter/material.dart';
import 'package:mehfooz_accounts_app/ui/home/widgets/home_header.dart';
import 'package:provider/provider.dart';

import '../../viewmodel/home/home_view_model.dart';

// Extracted Widgets
import 'widgets/cash_in_hand_card.dart';
import 'widgets/acc1_summary_card.dart';
import 'widgets/pending_amounts_list.dart';
import 'widgets/company_selector_bottomsheet.dart';

// Sync
import '../../viewmodel/sync/sync_viewmodel.dart';

const _kHomeBrandBlue = Color(0xFF1862A3);

class HomeScreenContent extends StatefulWidget {
  const HomeScreenContent({super.key});

  @override
  State<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent> {
  bool cashExpanded = false;
  bool acc1Expanded = false;
  String pendingSearchText = "";
  String? _lastSyncToastMessage;

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeViewModel>(
      builder: (context, vm, _) {
        final pendingAmounts = vm.pendingAmounts;
        final isImporting = vm.isImporting;
        final syncVm = context.watch<SyncViewModel>();

        _maybeShowSyncToast(syncVm);

        return Scaffold(
          backgroundColor: const Color(0xFFF3F8FC),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF8FBFF), Color(0xFFF1F6FB)],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -120,
                  left: -50,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kHomeBrandBlue.withValues(alpha: 0.09),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: -80,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kHomeBrandBlue.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                SafeArea(
                  child: RefreshIndicator(
                    color: _kHomeBrandBlue,
                    onRefresh: () async {
                      await context.read<SyncViewModel>().syncNowSingleFlight();
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          HomeHeader(
                            vm: vm,
                            onChangeCompany: () =>
                                CompanySelectorBottomSheet.show(context, vm),
                          ),
                          const SizedBox(height: 8),
                          _HomeSectionShell(
                            title: 'Running balances',
                            subtitle:
                                'A polished snapshot of your running cash and account positions.',
                            child: Column(
                              children: [
                                CashInHandCard(
                                  vm: vm,
                                  isExpanded: cashExpanded,
                                  onToggle: () => setState(
                                    () => cashExpanded = !cashExpanded,
                                  ),
                                ),
                                Acc1SummaryCard(
                                  vm: vm,
                                  isExpanded: acc1Expanded,
                                  onToggle: () => setState(
                                    () => acc1Expanded = !acc1Expanded,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (isImporting) ...[
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.only(top: 40),
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          ] else if (pendingAmounts.isNotEmpty) ...[
                            PendingAmountsList(
                              rows: pendingAmounts,
                              searchQuery: pendingSearchText,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _maybeShowSyncToast(SyncViewModel svm) {
    final msg = svm.lastMessage.trim();
    final shouldShow =
        !svm.isSyncing &&
        msg.isNotEmpty &&
        (msg.startsWith("✔") ||
            msg.startsWith("⚠") ||
            msg.startsWith("❌") ||
            msg == "Nothing to update");

    if (!shouldShow || _lastSyncToastMessage == msg) return;

    _lastSyncToastMessage = msg;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final background = msg.startsWith("❌")
          ? const Color(0xFFB42318)
          : msg.startsWith("⚠")
          ? const Color(0xFFB54708)
          : _kHomeBrandBlue;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: background,
            content: Text(
              msg.replaceFirst(RegExp(r'^[✔⚠❌]\s*'), ''),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
    });
  }
}

class _HomeSectionShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _HomeSectionShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF7FBFF)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFD8E6F3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF102132),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF617486),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
