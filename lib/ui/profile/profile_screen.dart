import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../model/user_model.dart';
import '../../theme/app_colors.dart';
import '../../viewmodel/profile/profile_view_model.dart';
import '../../viewmodel/sync/sync_viewmodel.dart';
import '../../viewmodel/home/home_view_model.dart';
import '../../services/file_picker_service.dart';
import '../home/widgets/google_sync_icon.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool expandCompanies = false;

  @override
  Widget build(BuildContext context) {
    return Consumer3<ProfileViewModel, SyncViewModel, HomeViewModel>(
      builder: (_, vm, svm, homeVM, __) {
        if (vm.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = vm.loggedInUser;

        return Scaffold(
          backgroundColor: AppColors.app_bg,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _userHeaderCard(user),
                  const SizedBox(height: 18),

                  if (!vm.isRestricted && vm.companies.isNotEmpty) ...[
                    _companySelectorAnimated(context, vm, homeVM),
                    const SizedBox(height: 20),
                  ],

                  _syncCard(context, svm, vm),
                  const SizedBox(height: 20),

                  _localDataCard(context, vm),
                  const SizedBox(height: 20),

                  _planCards(user),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────── USER HEADER ─────────────────────────

  Widget _userHeaderCard(UserModel user) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundImage:
              user.imageUrl.isNotEmpty ? NetworkImage(user.imageUrl) : null,
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(user.email,
                    style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── SYNC CARD ─────────────────────────

  Widget _syncCard(BuildContext context, SyncViewModel svm, ProfileViewModel vm) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Sync",
                    style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                _syncCapsule(svm),
              ],
            ),

            const SizedBox(height: 10),

            _syncStatusText(svm),

            if (svm.isSyncing) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: svm.syncProgress),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: svm.cancelSync,
                  child: const Text("Cancel"),
                ),
              ),
            ],

            if (svm.lastSyncedTime != null) ...[
              const SizedBox(height: 6),
              Text(
                "Last synced: ${_timeAgo(svm.lastSyncedTime!)}",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],



            // const SizedBox(height: 8),
            // _autoSyncSelector(context, svm),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── STATUS TEXT ─────────────────────────

  Widget _syncStatusText(SyncViewModel svm) {
    if (svm.canSync) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        svm.syncBlockReason,
        style: const TextStyle(color: Colors.orange),
      ),
    );
  }

  // ───────────────────────── SYNC BUTTON ─────────────────────────

  Widget _syncCapsule(SyncViewModel svm) {
    final disabled = !svm.canSync || svm.isSyncing;

    return AbsorbPointer(
      absorbing: disabled, // 🔒 HARD BLOCK TOUCH
      child: Opacity(
        opacity: disabled ? 0.4 : 1,
        child: GestureDetector(
          onTap: svm.syncNow, // safe now
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: GoogleStyleSyncIcon(
              syncing: svm.isSyncing,
              success: !svm.isSyncing && svm.lastMessage.isEmpty,
              error: svm.lastMessage.startsWith("❌"),
            ),
          ),
        ),
      ),
    );
  }
  // ───────────────────────── LOCAL SYNC TOGGLE ─────────────────────────


  // ───────────────────────── AUTO SYNC ─────────────────────────

  Widget _autoSyncSelector(BuildContext context, SyncViewModel svm) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Auto sync",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Text(
                svm.labelForInterval,
                style: TextStyle(
                  color:
                  svm.canSync ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: svm.canSync
              ? () => _showAutoSyncSheet(context, svm)
              : null,
          child: const Text("Edit"),
        ),
      ],
    );
  }

  void _showAutoSyncSheet(BuildContext context, SyncViewModel svm) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: AutoSyncInterval.values.map((interval) {
            return ListTile(
              title: Text(interval.name),
              onTap: () {
                svm.setAutoSyncInterval(interval);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // ───────────────────────── LOCAL DATA ─────────────────────────

  Widget _localDataCard(BuildContext context, ProfileViewModel vm) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Local Data",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.file_open),
              label: const Text("Import Local Database"),
              onPressed: vm.canImport
                  ? () async {
                final path =
                await FilePickerService.pickSqliteFile();
                if (path == null) return;

                await context
                    .read<HomeViewModel>()
                    .confirmAndImportDatabase(
                  context: context,
                  inputPath: path,
                  user: vm.loggedInUser,
                );

              }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── PLAN CARD ─────────────────────────

  Widget _planCards(UserModel user) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          if (user.planStatus != null)
            ListTile(
              leading: const Icon(Icons.workspace_premium),
              title: const Text("Plan Status"),
              subtitle: Text(user.planStatus!.statusText),
            ),
          if (user.expiry != null)
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text("Remaining Days"),
              subtitle: Text("${user.expiry!.remainingDays} days"),
            ),
          if (user.subscription != null)
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text("Subscription"),
              subtitle: Text(user.subscription!.planTitle),
            ),
        ],
      ),
    );
  }

  // ───────────────────────── HELPERS ─────────────────────────

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return "just now";
    if (d.inMinutes < 60) return "${d.inMinutes} min ago";
    if (d.inHours < 24) return "${d.inHours} hr ago";
    return "${d.inDays} days ago";
  }

  Widget _companySelectorAnimated(
      BuildContext context,
      ProfileViewModel vm,
      HomeViewModel homeVM,
      ) {
    final selectedId = homeVM.selectedCompanyId;
    final selected = selectedId == null
        ? null
        : vm.companies.firstWhere(
          (c) => c.companyId == selectedId,
      orElse: () => vm.companies.first,
    );

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Companies",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => setState(() => expandCompanies = !expandCompanies),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.darkgreen),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        selected?.companyName ?? "Select Company",
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    AnimatedRotation(
                      turns: expandCompanies ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.keyboard_arrow_down),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: expandCompanies
                  ? Column(
                children: vm.companies.map((c) {
                  return ListTile(
                    dense: true,
                    title: Text(c.companyName ?? "Unnamed"),
                    onTap: () async {
                      await homeVM.setCompany(c.companyId!);
                      setState(() => expandCompanies = false);
                    },
                  );
                }).toList(),
              )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}