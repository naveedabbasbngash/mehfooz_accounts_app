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

                  if (vm.databaseFound && vm.canUseDatabase) ...[
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

  // ───────────────────────────────── USER HEADER ─────────────────────────────────

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

  // ───────────────────────────────── COMPANY SELECTOR ─────────────────────────────────

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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Companies",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => setState(() => expandCompanies = !expandCompanies),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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

  // ───────────────────────────────── SYNC CARD ─────────────────────────────────

  Widget _syncCard(BuildContext context, SyncViewModel svm, ProfileViewModel vm) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text("Sync",
                      style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                _syncCapsule(svm, vm),
              ],
            ),

            const SizedBox(height: 12),

            if (svm.isSyncing) ...[
              LinearProgressIndicator(value: svm.syncProgress),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: svm.cancelSync,
                  child: const Text("Cancel"),
                ),
              ),
            ],

            _autoSyncSelector(context, svm),
          ],
        ),
      ),
    );
  }

  Widget _autoSyncSelector(BuildContext context, SyncViewModel svm) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Auto sync",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Text(svm.autoSyncLabel,
                  style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
        TextButton(
          child: const Text("Edit"),
          onPressed: () => _showAutoSyncSheet(context, svm),
        ),
      ],
    );
  }

  void _showAutoSyncSheet(BuildContext context, SyncViewModel svm) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AutoSyncInterval.values.map((interval) {
              final bool selected = svm.autoSyncInterval == interval;

              return ListTile(
                title: Text(_labelForInterval(interval)),
                trailing: selected ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  svm.setAutoSyncInterval(interval);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  /// LOCAL helper (UI only — DO NOT put in ViewModel)
  String _labelForInterval(AutoSyncInterval v) {
    switch (v) {
      case AutoSyncInterval.off:
        return "Off";
      case AutoSyncInterval.sec30:
        return "Every 30 seconds";
      case AutoSyncInterval.min2:
        return "Every 2 minutes";
      case AutoSyncInterval.min5:
        return "Every 5 minutes";
      case AutoSyncInterval.min20:
        return "Every 20 minutes";
    }
  }
  // ───────────────────────────────── SYNC CAPSULE (NO OVERFLOW) ─────────────────────────────────

  Widget _profileSyncCapsule(
      BuildContext context,
      SyncViewModel svm,
      ProfileViewModel vm,
      ) {
    final syncing = svm.isSyncing;
    final isError = svm.lastMessage.startsWith("❌");
    final expanded = syncing || isError;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = context.findRenderObject();
      if (box is RenderBox) {
        final right =
            box.localToGlobal(Offset.zero).dx + box.size.width;
        final screen = MediaQuery.of(context).size.width;
        if (right > screen) {
          debugPrint(
              "⚠️ SyncCapsule overflow → right=$right screen=$screen");
        }
      }
    });

    return SizedBox(
      width: 150, // 🔐 layout-safe width
      child: GestureDetector(
        onTap: vm.canSync && !syncing ? () => svm.syncNow() : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: expanded ? 140 : 42,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: expanded
                ? Row(
              key: const ValueKey("expanded"),
              mainAxisSize: MainAxisSize.min,
              children: [
                GoogleStyleSyncIcon(
                  syncing: syncing,
                  success: !syncing && !isError,
                  error: isError,
                ),
                const SizedBox(width: 8),
                Text(
                  syncing
                      ? "Syncing…"
                      : isError
                      ? "Error"
                      : "Synced",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: syncing
                        ? Colors.blue
                        : isError
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
              ],
            )
                : Center(
              key: const ValueKey("compact"),
              child: GoogleStyleSyncIcon(
                syncing: syncing,
                success: !syncing && !isError,
                error: isError,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────── AUTO SYNC SELECTOR ─────────────────────────────────

  Widget _buildAutoSyncSelector(BuildContext context) {
    return Consumer<SyncViewModel>(
      builder: (_, svm, __) {
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Auto sync",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    svm.autoSyncLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.edit, size: 16),
              label: const Text("Edit"),
              onPressed: () => _showAutoSyncSheet(context, svm),
            ),
          ],
        );
      },
    );
  }

  String _labelFor(AutoSyncInterval v) {
    switch (v) {
      case AutoSyncInterval.off:
        return "Off";
      case AutoSyncInterval.sec30:
        return "Every 30 seconds";
      case AutoSyncInterval.min2:
        return "Every 2 minutes";
      case AutoSyncInterval.min5:
        return "Every 5 minutes";
      case AutoSyncInterval.min20:
        return "Every 20 minutes";
    }
  }
  Widget _autoSyncOption(
      String title, bool selected, VoidCallback onTap) {
    return ListTile(
      title: Text(title),
      trailing:
      selected ? const Icon(Icons.check, color: AppColors.primary) : null,
      onTap: onTap,
    );
  }

  // ───────────────────────────────── STATUS TEXT ─────────────────────────────────

  Widget _buildSyncStatusRow(SyncViewModel svm) {
    String text;
    Color color;

    if (svm.isSyncing || svm.lastMessage.isNotEmpty) {
      text = svm.lastMessage;
      color = svm.lastMessage.startsWith("❌")
          ? Colors.red
          : Colors.blue;
    } else if (svm.lastSyncedTime != null) {
      final d = DateTime.now().difference(svm.lastSyncedTime!);
      text = "Last synced • ${_friendly(d)}";
      color = Colors.grey.shade600;
    } else {
      text = "Not synced yet";
      color = Colors.grey.shade500;
    }

    return Text(
      text,
      style: TextStyle(fontSize: 12.5, color: color),
    );
  }

  String _friendly(Duration d) {
    if (d.inSeconds < 60) return "just now";
    if (d.inMinutes < 60) return "${d.inMinutes} min ago";
    if (d.inHours < 24) return "${d.inHours} hrs ago";
    return "${d.inDays} days ago";
  }

  // ───────────────────────────────── LOCAL DATA ─────────────────────────────────

  Widget _localDataCard(BuildContext context, ProfileViewModel vm) {
    return Card(
      elevation: 2,
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
                    .importDatabase(path, vm.loggedInUser);
                await vm.refresh();
              }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────── PLAN CARD ─────────────────────────────────

  Widget _planCards(UserModel user) {
    if (user.planStatus == null &&
        user.expiry == null &&
        user.subscription == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
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

  Widget _syncCapsule(SyncViewModel svm, ProfileViewModel vm) {
    final bool isError = svm.lastMessage.startsWith("❌");
    final bool syncing = svm.isSyncing;
    final bool expanded = syncing || isError;

    return GestureDetector(
      onTap: vm.canSync && !syncing ? svm.syncNow : null,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 160), // 🛡 hard cap
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GoogleStyleSyncIcon(
                syncing: syncing,
                success: !syncing && !isError,
                error: isError,
              ),

              if (expanded) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 90),
                  child: Text(
                    syncing ? "Syncing…" : (isError ? "Error" : "Synced"),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: syncing
                          ? Colors.blue
                          : isError
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }}