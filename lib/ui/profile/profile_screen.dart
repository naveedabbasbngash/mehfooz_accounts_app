import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _showPendingBatches = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SyncViewModel>().refreshPendingBatches(silent: true);
    });
  }

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
                  Align(
                    alignment: Alignment.topRight,
                    child: _referenceIdBadge(
                      context,
                      svm,
                      vm.loggedInUser.email,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _userHeaderCard(context, user),
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

                  _accountActions(context, vm),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────── USER HEADER ─────────────────────────

  Widget _userHeaderCard(BuildContext context, UserModel user) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundImage: user.imageUrl.isNotEmpty
                  ? NetworkImage(user.imageUrl)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    user.email,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _referenceIdBadge(
    BuildContext context,
    SyncViewModel svm,
    String email,
  ) {
    final hasReferenceId = svm.hasReferenceId;
    final referenceId = svm.referenceId ?? "";

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            hasReferenceId ? "Reference ID: $referenceId" : "Reference ID not added",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: hasReferenceId ? Colors.grey.shade700 : Colors.orange.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        if (hasReferenceId)
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            tooltip: 'Copy reference ID',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.only(left: 6),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: referenceId));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Reference ID copied"),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          )
        else
          IconButton(
            icon: Icon(
              Icons.add_circle_rounded,
              size: 22,
              color: AppColors.primary,
            ),
            tooltip: 'Add Reference ID',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.only(left: 6),
            onPressed: () => _openAddReferenceIdScreen(context, svm, email),
          ),
      ],
    );
  }

  Future<void> _openAddReferenceIdScreen(
    BuildContext context,
    SyncViewModel svm,
    String email,
  ) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AddReferenceIdScreen(
          svm: svm,
          email: email,
        ),
      ),
    );

    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(this.context).showSnackBar(
      const SnackBar(content: Text("Reference ID verified and saved")),
    );
  }

  // ───────────────────────── SYNC CARD ─────────────────────────

  Widget _syncCard(
    BuildContext context,
    SyncViewModel svm,
    ProfileViewModel vm,
  ) {
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                _pendingCountChip(svm),
                const SizedBox(width: 8),
                _pendingToggleButton(svm),
                const SizedBox(width: 8),
                _syncCapsule(svm),
              ],
            ),

            const SizedBox(height: 10),

            _syncStatusText(svm),
            const SizedBox(height: 8),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOut,
              child: _showPendingBatches
                  ? _pendingBatchesPanel(context, svm)
                  : const SizedBox.shrink(),
            ),

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

  Widget _pendingCountChip(SyncViewModel svm) {
    final count = svm.pendingBatchCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: count > 0 ? Colors.orange.shade100 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "Pending: $count",
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: count > 0 ? Colors.orange.shade900 : Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _pendingToggleButton(SyncViewModel svm) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        setState(() => _showPendingBatches = !_showPendingBatches);
        if (_showPendingBatches) {
          await svm.refreshPendingBatches();
        }
      },
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedRotation(
          turns: _showPendingBatches ? 0.5 : 0,
          duration: const Duration(milliseconds: 220),
          child: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
        ),
      ),
    );
  }

  Widget _pendingBatchesPanel(BuildContext context, SyncViewModel svm) {
    if (svm.isPendingBatchesLoading) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Row(
          children: const [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text("Loading pending batches..."),
          ],
        ),
      );
    }

    if (svm.pendingBatchesError != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                svm.pendingBatchesError!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: () => svm.refreshPendingBatches(),
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    if (svm.pendingBatches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          "No pending batches for this device.",
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: svm.pendingBatches.map((batch) {
          final timestamp = _formatPendingTimestamp(
            batch.createdAt ?? batch.updatedAt ?? "",
          );
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${batch.entryCount} entries",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      batch.batchId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blueGrey.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 92,
                  child: Text(
                    timestamp,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
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
              const Text(
                "Auto sync",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                svm.labelForInterval,
                style: TextStyle(
                  color: svm.canSync
                      ? Colors.grey.shade600
                      : Colors.grey.shade400,
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
            const Text(
              "Local Data",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.file_open),
              label: const Text("Import Local Database"),
              onPressed: vm.canImport
                  ? () async {
                      final path = await FilePickerService.pickSqliteFile();
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

  String _formatPendingTimestamp(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return "-";

    final parsed = DateTime.tryParse(value.replaceFirst(' ', 'T'));
    if (parsed != null) {
      final dd = parsed.day.toString().padLeft(2, '0');
      final mm = parsed.month.toString().padLeft(2, '0');
      final hh = parsed.hour.toString().padLeft(2, '0');
      final min = parsed.minute.toString().padLeft(2, '0');
      return "$dd/$mm $hh:$min";
    }

    return value.length > 16 ? value.substring(0, 16) : value;
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
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

  // ───────────────────────── ACCOUNT ACTIONS ─────────────────────────

  Widget _accountActions(BuildContext context, ProfileViewModel vm) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              "Delete Account",
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text("Permanently delete your account and data"),
            onTap: () => _confirmDeleteAccount(context, vm),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, ProfileViewModel vm) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
          "This action will permanently delete your account and all associated data. This cannot be undone.",
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
            onPressed: () async {
              Navigator.pop(context);
              await vm.deleteAccount(context);
            },
          ),
        ],
      ),
    );
  }
}

class _AddReferenceIdScreen extends StatefulWidget {
  final SyncViewModel svm;
  final String email;

  const _AddReferenceIdScreen({
    required this.svm,
    required this.email,
  });

  @override
  State<_AddReferenceIdScreen> createState() => _AddReferenceIdScreenState();
}

class _AddReferenceIdScreenState extends State<_AddReferenceIdScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ref = _controller.text.trim();
    if (ref.isEmpty) {
      setState(() => _error = "Please enter Reference ID");
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final ok = await widget.svm.verifyAndSaveReferenceId(ref);
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSubmitting = false;
      _error = widget.svm.referenceIdError ?? "Verification failed";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.app_bg,
      appBar: AppBar(
        title: const Text("Add Reference ID"),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.12),
                  Colors.white,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Verify Reference ID",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Enter your assigned Reference ID to activate sync on this device.",
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Logged-in email",
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.email,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.done,
                    autofocus: true,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: "Reference ID",
                      hintText: "Enter Referecne Id",
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Text("Submit"),
            ),
          ),
        ],
      ),
    );
  }
}
