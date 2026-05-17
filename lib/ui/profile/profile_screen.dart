import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/local/app_database.dart';
import '../../model/user_model.dart';
import '../../theme/app_colors.dart';
import '../../viewmodel/profile/profile_view_model.dart';
import '../../viewmodel/sync/sync_viewmodel.dart';
import '../../viewmodel/home/home_view_model.dart';
import '../../services/file_picker_service.dart';
import '../../services/auth_service.dart';
import '../../services/local_storage.dart';
import '../../services/report_preferences_service.dart';
import '../auth/auth_screen.dart';
import '../home/widgets/google_sync_icon.dart';

const Color _kProfileBlue = Color(0xFF1862A3);
const Color _kProfileBlueDark = Color(0xFF0F4E88);
const Color _kProfileBg = Color(0xFFF4F8FC);

class _TeamMembersSnapshot {
  final bool accessDenied;
  final bool canManage;
  final String? error;
  final List<ManagedUserItem> members;

  const _TeamMembersSnapshot({
    required this.accessDenied,
    required this.canManage,
    required this.error,
    required this.members,
  });
}

Future<_TeamMembersSnapshot> _fetchTeamMembersSnapshot(UserModel user) async {
  final currentEmail = user.email.trim().toLowerCase();
  final currentUserId = int.tryParse(user.id) ?? -1;
  final tenantId = await AuthService.resolveTenantIdForCurrentSession();

  try {
    final rows = await AuthService.fetchManagedUsers();
    final tenantScoped = (tenantId != null && tenantId > 0)
        ? rows.where((r) => r.tenantId == tenantId).toList()
        : List<ManagedUserItem>.from(rows);

    ManagedUserItem? selfRow;
    for (final row in tenantScoped) {
      if ((currentUserId > 0 && row.userId == currentUserId) ||
          row.email.trim().toLowerCase() == currentEmail) {
        selfRow = row;
        break;
      }
    }

    final roleCodes = user.roleCodes
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final permCodes = user.permissions
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final selfRoleCode = (selfRow?.roleCode ?? '').trim().toUpperCase();
    final canManage =
        roleCodes.contains('OWNER') ||
        roleCodes.contains('ADMIN') ||
        permCodes.contains('users.write') ||
        selfRoleCode == 'OWNER' ||
        selfRoleCode == 'ADMIN';
    final visibleMembers = tenantScoped.where((row) {
      final isSelfById = currentUserId > 0 && row.userId == currentUserId;
      final isSelfByEmail = row.email.trim().toLowerCase() == currentEmail;
      return !isSelfById && !isSelfByEmail;
    }).toList();

    return _TeamMembersSnapshot(
      accessDenied: false,
      canManage: canManage,
      error: null,
      members: visibleMembers,
    );
  } catch (e) {
    final msg = e.toString().replaceFirst('Exception: ', '');
    final lower = msg.toLowerCase();
    if (lower.contains('user.read') || lower.contains('forbidden')) {
      return const _TeamMembersSnapshot(
        accessDenied: true,
        canManage: false,
        error: null,
        members: <ManagedUserItem>[],
      );
    }

    return _TeamMembersSnapshot(
      accessDenied: false,
      canManage: false,
      error: msg,
      members: const <ManagedUserItem>[],
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool expandCompanies = false;
  bool _showPendingBatches = false;
  bool _trailBalanceFiltersEnabled = false;
  bool _teamLoading = false;
  bool _teamAccessDenied = false;
  bool _canManageTeam = false;
  String? _teamError;
  List<ManagedUserItem> _teamMembers = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SyncViewModel>().refreshPendingBatches(silent: true);
      _loadTeamMembers(silent: true);
      _loadAppSettings();
    });
  }

  Future<void> _loadAppSettings() async {
    final enabled =
        await ReportPreferencesService.getSubgroupFiltersEnabled();
    if (!mounted) return;
    setState(() => _trailBalanceFiltersEnabled = enabled);
  }

  Future<void> _setTrailBalanceFiltersEnabled(bool enabled) async {
    await ReportPreferencesService.setSubgroupFiltersEnabled(enabled);
    if (!mounted) return;
    setState(() => _trailBalanceFiltersEnabled = enabled);
  }

  bool _canManageCompanies(UserModel user) {
    final roles = user.roleCodes
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (roles.contains('VIEW') ||
        roles.contains('VIEWER') ||
        roles.contains('READONLY') ||
        roles.contains('READ_ONLY')) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ProfileViewModel, SyncViewModel, HomeViewModel>(
      builder: (context, vm, svm, homeVM, child) {
        if (vm.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = vm.loggedInUser;
        final canManageCompanies = _canManageCompanies(user);

        return Scaffold(
          backgroundColor: _kProfileBg,
          body: Stack(
            children: [
              const _ProfileBackdrop(),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _userHeaderCard(context, user, svm),
                      const SizedBox(height: 18),

                      if (vm.companies.isNotEmpty) ...[
                        _companySelectorAnimated(
                          context,
                          vm,
                          homeVM,
                          canManageCompanies: canManageCompanies,
                        ),
                        const SizedBox(height: 18),
                      ],

                      _syncCard(context, svm, vm),
                      const SizedBox(height: 18),

                      _localDataCard(context, vm),
                      const SizedBox(height: 18),

                      _planCards(user),
                      const SizedBox(height: 18),

                      _appSettingsCard(context),
                      const SizedBox(height: 18),

                      if (!_teamAccessDenied) ...[
                        _teamMembersCard(context),
                        const SizedBox(height: 18),
                      ],

                      _accountActions(context, vm),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _profileRoleLabel(UserModel user) {
    final roles = user.roleCodes.map((e) => e.trim().toUpperCase()).toSet();
    if (roles.contains('OWNER')) return 'Owner';
    if (roles.contains('ADMIN')) return 'Administrator';
    if (roles.contains('ACCOUNTANT')) return 'Accountant';
    return 'Member';
  }

  String _profileName(UserModel user) {
    final name = user.fullName.trim();
    if (name.isNotEmpty) return name;
    return user.email.trim();
  }

  Widget _infoPill({
    required IconData icon,
    required String text,
    Color? color,
    Color? textColor,
  }) {
    final bg = color ?? Colors.white.withValues(alpha: 0.14);
    final fg = textColor ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration({bool highlighted = false}) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: highlighted
            ? const [Color(0xFFF9FCFF), Color(0xFFF2F8FF)]
            : const [Colors.white, Color(0xFFFAFCFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: highlighted ? const Color(0xFFCFE1F7) : const Color(0xFFDCE7F8),
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x140F172A),
          blurRadius: 22,
          offset: Offset(0, 10),
        ),
      ],
    );
  }

  Future<void> _smartLogout(BuildContext context) async {
    await LocalStorageService.clearLoginStateOnly();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  // ───────────────────────── USER HEADER ─────────────────────────

  Widget _userHeaderCard(BuildContext context, UserModel user, SyncViewModel svm) {
    final roleLabel = _profileRoleLabel(user);
    final statusText = user.planStatus?.statusText.trim();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kProfileBlue, _kProfileBlueDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x301862A3),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => _smartLogout(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: Colors.white.withValues(alpha: 0.16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: user.imageUrl.isNotEmpty
                        ? Image.network(user.imageUrl, fit: BoxFit.cover)
                        : Center(
                            child: Text(
                              _profileName(user)
                                  .trim()
                                  .split(RegExp(r'\s+'))
                                  .where((e) => e.isNotEmpty)
                                  .take(2)
                                  .map((e) => e[0].toUpperCase())
                                  .join(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profileName(user),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _infoPill(
                            icon: Icons.verified_user_outlined,
                            text: roleLabel,
                          ),
                          if (statusText != null && statusText.isNotEmpty)
                            _infoPill(
                              icon: Icons.workspace_premium_outlined,
                              text: statusText,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── SYNC CARD ─────────────────────────

  Widget _syncCard(
    BuildContext context,
    SyncViewModel svm,
    ProfileViewModel vm,
  ) {
    return Container(
      decoration: _panelDecoration(highlighted: true),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F3FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.sync_rounded,
                    color: _kProfileBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Sync",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: svm.syncProgress,
                  minHeight: 6,
                  color: _kProfileBlue,
                  backgroundColor: const Color(0xFFDCE7F8),
                ),
              ),
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
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: 8),
            _autoSyncSelector(context, svm),
          ],
        ),
      ),
    );
  }

  Widget _pendingCountChip(SyncViewModel svm) {
    final count = svm.pendingBatchCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: count > 0 ? const Color(0xFFFFF1E8) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        "Pending: $count",
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: count > 0 ? const Color(0xFFB45309) : const Color(0xFF64748B),
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
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedRotation(
          turns: _showPendingBatches ? 0.5 : 0,
          duration: const Duration(milliseconds: 220),
          child: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: Color(0xFF475569),
          ),
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
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE7F8)),
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
                    color: const Color(0xFFE9F3FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${batch.entryCount} entries",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kProfileBlue,
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
                        color: const Color(0xFF475569),
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
                      color: const Color(0xFF64748B),
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
        style: const TextStyle(
          color: Color(0xFFB45309),
          fontWeight: FontWeight.w600,
        ),
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
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDCE7F8)),
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

  // ignore: unused_element
  Widget _autoSyncSelector(BuildContext context, SyncViewModel svm) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE7F8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Auto sync",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  svm.labelForInterval,
                  style: TextStyle(
                    color: svm.canSync
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: svm.canSync
                ? () => _showAutoSyncSheet(context, svm)
                : null,
            child: const Text(
              "Edit",
              style: TextStyle(
                color: _kProfileBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
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
    return Container(
      decoration: _panelDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Local Data",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.file_open),
                  label: const Text("Import Local Database"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kProfileBlue,
                    side: const BorderSide(color: Color(0xFFCFE1F7)),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: vm.canImport
                      ? () async {
                          final homeVM = context.read<HomeViewModel>();
                          final user = vm.loggedInUser;
                          final path = await FilePickerService.pickSqliteFile();
                          if (path == null || !context.mounted) return;

                          await homeVM.confirmAndImportDatabase(
                            context: context,
                            inputPath: path,
                            user: user,
                          );
                        }
                      : null,
                ),
                FilledButton.icon(
                  icon: vm.isExportingDatabase
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share_rounded),
                  label: Text(
                    vm.isExportingDatabase
                        ? "Preparing..."
                        : "Export & Share Database",
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kProfileBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: vm.isExportingDatabase
                      ? null
                      : () async {
                          final error = await vm.exportAndShareDatabase();
                          if (!context.mounted) return;
                          if (error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(error),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Database ready to share via WhatsApp or any app.",
                                ),
                                backgroundColor: AppColors.darkgreen,
                              ),
                            );
                          }
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── PLAN CARD ─────────────────────────

  Widget _planCards(UserModel user) {
    return Container(
      decoration: _panelDecoration(),
      child: Column(
        children: [
          if (user.planStatus != null)
            ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: _kProfileBlue,
                ),
              ),
              title: const Text("Plan Status"),
              subtitle: Text(user.planStatus!.statusText),
            ),
          if (user.expiry != null)
            ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.timer_outlined, color: _kProfileBlue),
              ),
              title: const Text("Remaining Days"),
              subtitle: Text("${user.expiry!.remainingDays} days"),
            ),
          if (user.subscription != null)
            ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: _kProfileBlue,
                ),
              ),
              title: const Text("Subscription"),
              subtitle: Text(user.subscription!.planTitle),
            ),
        ],
      ),
    );
  }

  Widget _appSettingsCard(BuildContext context) {
    return Container(
      decoration: _panelDecoration(),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _showAppSettingsSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.settings_outlined,
                  color: _kProfileBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "App Settings",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _trailBalanceFiltersEnabled
                          ? "Trail Balance opens filter selections before export."
                          : "Trail Balance exports directly. Add future app permissions here.",
                      style: const TextStyle(
                        fontSize: 12.6,
                        height: 1.45,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: _kProfileBlue,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAppSettingsSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> updateToggle(bool enabled) async {
              await _setTrailBalanceFiltersEnabled(enabled);
              if (!sheetContext.mounted) return;
              setSheetState(() {});
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 24,
                bottom: MediaQuery.of(sheetContext).padding.bottom + 16,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x241862A3),
                      blurRadius: 32,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFBFD7F3),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_kProfileBlue, _kProfileBlueDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'App Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Manage report behavior and future app permissions from one place.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FBFE),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFDCE7F8)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF5FF),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.account_tree_outlined,
                                color: _kProfileBlue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Trail Balance Filters',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _trailBalanceFiltersEnabled
                                        ? 'Open account, currency, and date selections before generating the PDF.'
                                        : 'Keep one-tap export for the full company PDF.',
                                    style: const TextStyle(
                                      fontSize: 12.3,
                                      height: 1.45,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch.adaptive(
                              value: _trailBalanceFiltersEnabled,
                              activeTrackColor: const Color(0x661862A3),
                              activeThumbColor: _kProfileBlue,
                              onChanged: updateToggle,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
    {required bool canManageCompanies}
  ) {
    final selectedId = homeVM.selectedCompanyId;
    final selected = selectedId == null
        ? null
        : vm.companies.firstWhere(
            (c) => c.companyId == selectedId,
            orElse: () => vm.companies.first,
          );

    return Card(
      color: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: _panelDecoration(),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  "Companies",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                if (canManageCompanies)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _kProfileBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _showAddCompanyDialog(context, vm),
                    icon: const Icon(Icons.add_business_outlined, size: 18),
                    label: const Text("Add"),
                  ),
              ],
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
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFCFE1F7)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF5FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.business_center_rounded,
                        color: _kProfileBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        selected?.companyName ?? "Select Company",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: expandCompanies ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xFF475569),
                      ),
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
                        final isSelected = c.companyId == selectedId;
                        return Container(
                          margin: const EdgeInsets.only(top: 10),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFFEFF6FF),
                                      Color(0xFFE6F0FF),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFFFCFEFF),
                                      Color(0xFFF7FBFF),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF93C5FD)
                                  : const Color(0xFFDCE7F8),
                            ),
                            boxShadow: isSelected
                                ? const [
                                    BoxShadow(
                                      color: Color(0x183B82F6),
                                      blurRadius: 14,
                                      offset: Offset(0, 6),
                                    ),
                                  ]
                                : const [
                                    BoxShadow(
                                      color: Color(0x0D0F172A),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () async {
                                await homeVM.setCompany(c.companyId);
                                setState(() => expandCompanies = false);
                              },
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  12,
                                  8,
                                  12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFFDCEBFF)
                                            : const Color(0xFFEAF5FF),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        isSelected
                                            ? Icons.business_rounded
                                            : Icons.apartment_rounded,
                                        color: _kProfileBlue,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.companyName ?? "Unnamed",
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            isSelected
                                                ? 'Active workspace'
                                                : 'Tap to switch workspace',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected
                                                  ? _kProfileBlue
                                                  : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (canManageCompanies)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: "Edit Company",
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              size: 18,
                                              color: Color(0xFF334155),
                                            ),
                                            onPressed: () =>
                                                _showEditCompanyDialog(
                                                  context,
                                                  vm,
                                                  c,
                                                ),
                                          ),
                                          IconButton(
                                            tooltip: "Delete Company",
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 18,
                                              color: Colors.red,
                                            ),
                                            onPressed: () =>
                                                _confirmDeleteCompany(
                                                  context,
                                                  vm,
                                                  c,
                                                ),
                                          ),
                                        ],
                                      )
                                    else
                                      const Padding(
                                        padding: EdgeInsets.only(right: 8),
                                        child: Icon(
                                          Icons.chevron_right_rounded,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
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

  Future<void> _showAddCompanyDialog(
    BuildContext context,
    ProfileViewModel vm,
  ) async {
    if (!_canManageCompanies(vm.loggedInUser)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Viewer role has read-only access to companies'),
        ),
      );
      return;
    }
    if (vm.companies.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already have 2 companies. New companies cannot be added.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final payload = await _showCompanyEditorSheet(
      context,
      title: 'Add Company',
      actionLabel: 'Add Company',
      nameHint: 'e.g. Mahfooz Accounts',
    );

    if (payload == null || !context.mounted) return;
    final normalizedName = payload.$1.trim().toLowerCase();
    final exists = vm.companies.any(
      (c) => (c.companyName ?? '').trim().toLowerCase() == normalizedName,
    );
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Company name already exists.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final error = await vm.addCompany(
      context: context,
      name: payload.$1,
      remarks: payload.$2,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? "Company added and seeded successfully."),
        backgroundColor: error == null ? AppColors.darkgreen : Colors.red,
      ),
    );
  }

  Future<void> _showEditCompanyDialog(
    BuildContext context,
    ProfileViewModel vm,
    CompanyTableData company,
  ) async {
    if (!_canManageCompanies(vm.loggedInUser)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Viewer role has read-only access to companies'),
        ),
      );
      return;
    }

    final nameController = TextEditingController(
      text: company.companyName ?? "",
    );
    final remarksController = TextEditingController(
      text: company.remarks ?? "",
    );

    final payload = await _showCompanyEditorSheet(
      context,
      title: 'Edit Company',
      actionLabel: 'Save Changes',
      initialName: nameController.text,
      initialRemarks: remarksController.text,
    );

    if (payload == null || !context.mounted) return;
    final error = await vm.updateCompany(
      context: context,
      companyId: company.companyId,
      name: payload.$1,
      remarks: payload.$2,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? "Company updated."),
        backgroundColor: error == null ? AppColors.darkgreen : Colors.red,
      ),
    );
  }

  Future<(String, String)?> _showCompanyEditorSheet(
    BuildContext context, {
    required String title,
    required String actionLabel,
    String initialName = '',
    String initialRemarks = '',
    String? nameHint,
  }) async {
    final nameController = TextEditingController(text: initialName);
    final remarksController = TextEditingController(text: initialRemarks);
    final formKey = GlobalKey<FormState>();

    return showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom +
                MediaQuery.of(sheetContext).padding.bottom +
                16,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x241862A3),
                  blurRadius: 32,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFBFD7F3),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_kProfileBlue, _kProfileBlueDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.business_center_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Create or update a company space with a cleaner setup flow.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildCompanyField(
                        controller: nameController,
                        label: 'Company Name',
                        hint: nameHint ?? 'Enter company name',
                        icon: Icons.apartment_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Company name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildCompanyField(
                        controller: remarksController,
                        label: 'Remarks',
                        hint: 'Optional notes',
                        icon: Icons.edit_note_rounded,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF475569),
                                side: const BorderSide(
                                  color: Color(0xFFDCE7F8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () => Navigator.pop(sheetContext),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: _kProfileBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () {
                                if (!formKey.currentState!.validate()) return;
                                Navigator.pop(
                                  sheetContext,
                                  (
                                    nameController.text.trim(),
                                    remarksController.text.trim(),
                                  ),
                                );
                              },
                              child: Text(
                                actionLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompanyField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _kProfileBlue, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FBFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFDCE7F8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFDCE7F8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _kProfileBlue, width: 1.4),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteCompany(
    BuildContext context,
    ProfileViewModel vm,
    CompanyTableData company,
  ) async {
    if (!_canManageCompanies(vm.loggedInUser)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Viewer role has read-only access to companies'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Company"),
        content: Text(
          "Delete '${company.companyName ?? 'this company'}' (ID: ${company.companyId})?\n\nAll company transactions and accounts for this company will be removed.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final error = await vm.deleteCompany(
      context: context,
      companyId: company.companyId,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? "Company deleted."),
        backgroundColor: error == null ? AppColors.darkgreen : Colors.red,
      ),
    );
  }

  // ───────────────────────── ACCOUNT ACTIONS ─────────────────────────
  Future<void> _loadTeamMembers({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _teamLoading = true;
        _teamError = null;
      });
    } else {
      setState(() {
        _teamError = null;
      });
    }

    try {
      final vm = context.read<ProfileViewModel>();
      final snapshot = await _fetchTeamMembersSnapshot(vm.loggedInUser);

      if (!mounted) return;
      setState(() {
        _teamAccessDenied = snapshot.accessDenied;
        _canManageTeam = snapshot.canManage;
        _teamMembers = snapshot.members;
        _teamError = snapshot.error;
      });
    } finally {
      if (mounted) {
        setState(() => _teamLoading = false);
      }
    }
  }

  Widget _teamMembersCard(BuildContext context) {
    final count = _teamMembers.length;
    final subtitle = _teamLoading
        ? 'Refreshing team access...'
        : _teamError != null
        ? _teamError!
        : count == 0
        ? (_canManageTeam
              ? 'No team members yet. Tap to invite your first member.'
              : 'No team members assigned yet.')
        : '$count active ${count == 1 ? 'member' : 'members'} linked to this workspace';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFF8FBFF), Color(0xFFF1F7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFDCE7F8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () async {
            final vm = context.read<ProfileViewModel>();
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    _TeamMembersHubScreen(loggedInUser: vm.loggedInUser),
              ),
            );
            if (!mounted) return;
            await _loadTeamMembers(silent: true);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDBEAFE), Color(0xFFBFDBFE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        color: Color(0xFF2563EB),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Team Members',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: _teamError != null
                                  ? Colors.red.shade600
                                  : const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDCE7F8)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$count',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const Text(
                            'Members',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 28,
                      color: Color(0xFF64748B),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFDCE7F8)),
                  ),
                  child: Row(
                    children: [
                      if (count > 0)
                        SizedBox(
                          width: count == 1 ? 28 : count == 2 ? 46 : 64,
                          height: 28,
                          child: Stack(
                            children: List.generate(
                              count > 3 ? 3 : count,
                              (index) => Positioned(
                                left: index * 18,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFE9F3FF),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                    child: Center(
                                      child: Text(
                                        ((_teamMembers[index].fullName.trim().isNotEmpty
                                                    ? _teamMembers[index]
                                                        .fullName
                                                        .trim()
                                                    : _teamMembers[index]
                                                        .email
                                                        .trim())
                                                .substring(0, 1))
                                            .toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: _kProfileBlue,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF5FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1_rounded,
                            color: _kProfileBlue,
                            size: 18,
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          count == 0
                              ? 'Tap to manage members'
                              : count == 1
                              ? '1 member connected'
                              : '$count members connected',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: _kProfileBlue,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── ACCOUNT ACTIONS ─────────────────────────

  Widget _accountActions(BuildContext context, ProfileViewModel vm) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFB),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF7D4D4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F7F1D1D),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFFE9E9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_forever_rounded, color: Colors.red),
        ),
        title: const Text(
          "Delete Account",
          style: TextStyle(
            color: Color(0xFFB91C1C),
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: const Text("Permanently delete your account and data"),
        onTap: () => _confirmDeleteAccount(context, vm),
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

class _ProfileBackdrop extends StatelessWidget {
  const _ProfileBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: _kProfileBg),
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
          top: 160,
          left: -90,
          child: Container(
            width: 190,
            height: 190,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x1F1862A3), Color(0x001862A3)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TeamMembersHubScreen extends StatefulWidget {
  final UserModel loggedInUser;

  const _TeamMembersHubScreen({required this.loggedInUser});

  @override
  State<_TeamMembersHubScreen> createState() => _TeamMembersHubScreenState();
}

class _TeamMembersHubScreenState extends State<_TeamMembersHubScreen> {
  bool _loading = true;
  bool _accessDenied = false;
  bool _canManage = false;
  String? _error;
  List<ManagedUserItem> _members = const [];
  int? _selectedMemberUserId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!mounted) return;
    setState(() {
      if (!silent) _loading = true;
      _error = null;
    });

    final snapshot = await _fetchTeamMembersSnapshot(widget.loggedInUser);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _accessDenied = snapshot.accessDenied;
      _canManage = snapshot.canManage;
      _error = snapshot.error;
      _members = snapshot.members;
      if (_selectedMemberUserId != null &&
          !_members.any((member) => member.userId == _selectedMemberUserId)) {
        _selectedMemberUserId = null;
      }
    });
  }

  Future<void> _openAddMember() async {
    if (!_canManage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Only owner/admin can add team members."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddTeamUserSheet(),
    );

    if (!mounted || added != true) return;
    await _refresh(silent: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Team member added successfully."),
        backgroundColor: _kProfileBlue,
      ),
    );
  }

  Future<void> _openEditMember(ManagedUserItem member) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditTeamMemberSheet(member: member),
    );

    if (!mounted || done != true) return;
    await _refresh(silent: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Member updated."),
        backgroundColor: _kProfileBlue,
      ),
    );
  }

  Future<void> _deleteMember(ManagedUserItem member) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Team Member"),
        content: Text(
          "Delete ${member.fullName.isEmpty ? member.email : member.fullName}?\n\nThis user will lose access.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (!mounted || ok != true) return;
    final result = await AuthService.deleteManagedUser(userId: member.userId);
    if (!mounted) return;

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.red),
      );
      return;
    }

    await _refresh(silent: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message.isNotEmpty ? result.message : "Member deleted.",
        ),
        backgroundColor: _kProfileBlue,
      ),
    );
  }

  String _displayText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return value;
    if (trimmed.contains('@')) {
      return trimmed[0].toUpperCase() + trimmed.substring(1);
    }
    final normalized = trimmed.replaceAll('_', ' ').toLowerCase();
    return normalized
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String _displayName(ManagedUserItem member) {
    final fullName = member.fullName.trim();
    if (fullName.isNotEmpty) return _displayText(fullName);
    return _displayText(member.email.trim());
  }

  String _initials(ManagedUserItem member) {
    final source = _displayName(member);
    final parts = source
        .split(RegExp(r'\s+'))
        .where((e) => e.trim().isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final item = parts.first;
      return item.substring(0, item.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String _normalizedMemberStatus(String status) {
    final normalized = status.trim().toUpperCase();
    if (normalized == 'ACTIVE') return 'ACTIVE';
    if (normalized == 'BLOCKED' ||
        normalized == 'INACTIVE' ||
        normalized == 'DISABLED') {
      return 'INACTIVE';
    }
    return normalized.isEmpty ? 'INACTIVE' : normalized;
  }

  Color _statusTint(String status) {
    final normalized = _normalizedMemberStatus(status);
    if (normalized == 'ACTIVE') return const Color(0xFFDCFCE7);
    if (normalized == 'INACTIVE') return const Color(0xFFFEE2E2);
    return const Color(0xFFE2E8F0);
  }

  Color _statusColor(String status) {
    final normalized = _normalizedMemberStatus(status);
    if (normalized == 'ACTIVE') return const Color(0xFF166534);
    if (normalized == 'INACTIVE') return const Color(0xFFB91C1C);
    return const Color(0xFF475569);
  }

  Widget _buildOverview() {
    if (_loading) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Text(
          _error!,
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final ownerName = widget.loggedInUser.fullName.trim().isEmpty
        ? widget.loggedInUser.email
        : widget.loggedInUser.fullName;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFDCE7F8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const bubbleSize = 46.0;
          const bubbleSpacing = 18.0;
          const railSidePadding = 20.0;
          final treeWidth = _members.isEmpty
              ? constraints.maxWidth
              : (_members.length * bubbleSize) +
                    ((_members.length - 1) * bubbleSpacing) +
                    (railSidePadding * 2);
          final contentWidth = treeWidth > constraints.maxWidth
              ? treeWidth
              : constraints.maxWidth;

          return Column(
            children: [
              _OwnerTreeCard(title: _displayText(ownerName)),
              if (_members.isNotEmpty) const _TreeConnector(height: 22),
              if (_members.isEmpty)
                Container(
                  width: 160,
                  constraints: const BoxConstraints(minHeight: 72),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFDCE7F8)),
                  ),
                  child: const Center(
                    child: Text(
                      'No Team Members',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 84,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: railSidePadding,
                        right: railSidePadding,
                        child: Container(
                          height: 2,
                          color: const Color(0xFFBFDBFE),
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: SizedBox(
                          width: contentWidth,
                          child: Align(
                            alignment: contentWidth == constraints.maxWidth
                                ? Alignment.topCenter
                                : Alignment.topLeft,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: railSidePadding,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: List.generate(_members.length, (
                                  index,
                                ) {
                                  final member = _members[index];
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      right: index == _members.length - 1
                                          ? 0
                                          : bubbleSpacing,
                                    ),
                                    child: _TeamMemberBubble(
                                      initials: _initials(member),
                                      selected:
                                          _selectedMemberUserId ==
                                          member.userId,
                                      active:
                                          _normalizedMemberStatus(
                                            member.status,
                                          ) ==
                                          'ACTIVE',
                                      onTap: () {
                                        setState(() {
                                          _selectedMemberUserId = member.userId;
                                        });
                                      },
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Team Members',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : () => _refresh(),
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
          ),
          if (_canManage)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0A6B1D),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  tooltip: 'Add team member',
                  onPressed: _openAddMember,
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.darkgreen,
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _buildOverview(),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFDCE7F8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Directory',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '${_members.length} total',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_accessDenied)
                      const Text(
                        'Team members are not available for this account.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else if (_members.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          _canManage
                              ? 'No team members yet. Use the + button to add your first member.'
                              : 'No team members assigned yet.',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      ..._members.map((member) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TeamMemberDirectoryCard(
                            member: member,
                            initials: _initials(member),
                            displayName: _displayName(member),
                            statusTint: _statusTint(member.status),
                            statusColor: _statusColor(member.status),
                            canManage: _canManage,
                            isHighlighted:
                                _selectedMemberUserId == member.userId,
                            onEdit: () => _openEditMember(member),
                            onDelete: () => _deleteMember(member),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamMemberBubble extends StatelessWidget {
  final String initials;
  final bool selected;
  final bool active;
  final VoidCallback onTap;

  const _TeamMemberBubble({
    required this.initials,
    required this.selected,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(
          height: 18,
          child: Center(
            child: SizedBox(
              width: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFFBFDBFE)),
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? const Color(0xFFBFDBFE)
                        : const Color(0xFFDBEAFE),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF2563EB)
                          : active
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFFDCE7F8),
                      width: selected ? 3 : 2,
                    ),
                    boxShadow: selected
                        ? const [
                            BoxShadow(
                              color: Color(0x223B82F6),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ),
                if (active)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 9,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TreeConnector extends StatelessWidget {
  final double height;

  const _TreeConnector({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(width: 2, height: height, color: const Color(0xFFBFDBFE));
  }
}

class _OwnerTreeCard extends StatelessWidget {
  final String title;

  const _OwnerTreeCard({required this.title});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 52,
      child: Container(
        width: 132,
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF8FBFF), Color(0xFFEEF6FF)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDCE7F8)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamMemberDirectoryCard extends StatelessWidget {
  final ManagedUserItem member;
  final String initials;
  final String displayName;
  final Color statusTint;
  final Color statusColor;
  final bool canManage;
  final bool isHighlighted;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TeamMemberDirectoryCard({
    required this.member,
    required this.initials,
    required this.displayName,
    required this.statusTint,
    required this.statusColor,
    required this.canManage,
    required this.isHighlighted,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final roleRaw = (member.roleName ?? member.roleCode ?? 'Member')
        .trim()
        .replaceAll('_', ' ');
    final roleLabel = roleRaw.isEmpty
        ? 'Member'
        : roleRaw
              .toLowerCase()
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .map((part) => part[0].toUpperCase() + part.substring(1))
              .join(' ');
    final statusRaw = member.status.trim().replaceAll('_', ' ');
    final statusLabel = statusRaw.isEmpty
        ? 'Unknown'
        : statusRaw
              .toLowerCase()
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .map((part) => part[0].toUpperCase() + part.substring(1))
              .join(' ');
    final emailLabel = member.email.trim().isEmpty
        ? member.email
        : member.email.trim()[0].toUpperCase() +
              member.email.trim().substring(1);

    return Container(
      decoration: BoxDecoration(
        color: isHighlighted
            ? const Color(0xFFEFF6FF)
            : const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlighted
              ? const Color(0xFF60A5FA)
              : const Color(0xFFDCE7F8),
          width: isHighlighted ? 1.5 : 1,
        ),
        boxShadow: isHighlighted
            ? const [
                BoxShadow(
                  color: Color(0x143B82F6),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFFDBEAFE),
          child: Text(
            initials,
            style: const TextStyle(
              color: Color(0xFF2563EB),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                emailLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusTint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      roleLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: canManage
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              )
            : null,
      ),
    );
  }
}

class _AddTeamUserSheet extends StatefulWidget {
  const _AddTeamUserSheet();

  @override
  State<_AddTeamUserSheet> createState() => _AddTeamUserSheetState();
}

class _AddTeamUserSheetState extends State<_AddTeamUserSheet> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _rolesLoading = true;
  List<ManagedRoleItem> _roles = const [];
  int? _roleId;
  String? _rolesError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await AuthService.fetchManageableRoles();
      if (!mounted) return;
      ManagedRoleItem? preferred;
      for (final role in roles) {
        if (role.roleCode == 'ACCOUNTANT') {
          preferred = role;
          break;
        }
      }
      preferred ??= roles.isNotEmpty ? roles.first : null;
      setState(() {
        _roles = roles;
        _roleId = preferred?.roleId;
        _rolesLoading = false;
        _rolesError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _roles = const [];
        _roleId = null;
        _rolesLoading = false;
        _rolesError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _error = "Full name is required");
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = "Valid email is required");
      return;
    }
    if (password.length < 6) {
      setState(() => _error = "Password must be at least 6 characters");
      return;
    }
    if (password != confirm) {
      setState(() => _error = "Passwords do not match");
      return;
    }

    setState(() {
      _error = null;
      _isSubmitting = true;
    });

    final result = await AuthService.createManagedUser(
      fullName: name,
      email: email,
      phone: phone,
      password: password,
      roleId: _roleId,
    );

    if (!mounted) return;

    if (result.success) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSubmitting = false;
      _error = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Add Team Member",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: "Full name",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: "Phone (optional)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _roleId,
                  items: _roles
                      .map(
                        (r) => DropdownMenuItem<int>(
                          value: r.roleId,
                          child: Text(r.roleName),
                        ),
                      )
                      .toList(),
                  onChanged: _isSubmitting || _rolesLoading || _roles.isEmpty
                      ? null
                      : (v) => setState(() => _roleId = v),
                  decoration: const InputDecoration(
                    labelText: "Role",
                    helperText:
                        "Loaded from server roles. If unavailable, backend default role will be used.",
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_rolesLoading) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                if (_rolesError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _rolesError!,
                    style: const TextStyle(color: Colors.orange),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: "Temporary password",
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: "Confirm password",
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_alt_1),
                    label: Text(_isSubmitting ? "Adding..." : "Create User"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditTeamMemberSheet extends StatefulWidget {
  final ManagedUserItem member;

  const _EditTeamMemberSheet({required this.member});

  @override
  State<_EditTeamMemberSheet> createState() => _EditTeamMemberSheetState();
}

class _EditTeamMemberSheetState extends State<_EditTeamMemberSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  final TextEditingController _newPasswordCtrl = TextEditingController();

  bool _isSubmitting = false;
  String? _status;
  int? _roleId;
  bool _sendRole = false;
  bool _rolesLoading = true;
  List<ManagedRoleItem> _roles = const [];
  String? _rolesError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.member.fullName);
    _emailCtrl = TextEditingController(text: widget.member.email);
    _phoneCtrl = TextEditingController(text: widget.member.phone ?? '');
    _status = _uiStatusValue(widget.member.status);
    _roleId = widget.member.roleId;
    _sendRole = widget.member.roleId != null;
    _loadRoles();
  }

  String _uiStatusValue(String rawStatus) {
    final normalized = rawStatus.trim().toUpperCase();
    if (normalized == 'ACTIVE') return 'ACTIVE';
    if (normalized == 'BLOCKED' ||
        normalized == 'INACTIVE' ||
        normalized == 'DISABLED') {
      return 'INACTIVE';
    }
    return 'ACTIVE';
  }

  String _backendStatusValue(String? uiStatus) {
    final normalized = (uiStatus ?? 'ACTIVE').trim().toUpperCase();
    return normalized == 'ACTIVE' ? 'ACTIVE' : 'BLOCKED';
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await AuthService.fetchManageableRoles();
      if (!mounted) return;

      final merged = List<ManagedRoleItem>.from(roles);
      if (_roleId != null &&
          _roleId! > 0 &&
          !merged.any((r) => r.roleId == _roleId)) {
        merged.add(
          ManagedRoleItem(
            roleId: _roleId!,
            roleCode:
                (widget.member.roleCode ?? widget.member.roleName ?? 'CUSTOM')
                    .toUpperCase(),
            roleName: widget.member.roleName ?? 'Current Role',
          ),
        );
      }

      if (_roleId == null && merged.isNotEmpty) {
        ManagedRoleItem? preferred;
        for (final role in merged) {
          if (role.roleCode == 'ACCOUNTANT') {
            preferred = role;
            break;
          }
        }
        preferred ??= merged.first;
        _roleId = preferred.roleId;
      }

      setState(() {
        _roles = merged;
        _rolesLoading = false;
        _rolesError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _roles = const [];
        _rolesLoading = false;
        _rolesError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _newPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final newPassword = _newPasswordCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _error = "Name is required");
      return;
    }
    if (newPassword.isNotEmpty && newPassword.length < 6) {
      setState(() => _error = "New password must be at least 6 characters");
      return;
    }
    if (_sendRole && (_roleId == null || _roleId! <= 0)) {
      setState(() => _error = "Please select a valid role");
      return;
    }

    setState(() {
      _error = null;
      _isSubmitting = true;
    });

    final result = await AuthService.updateManagedUser(
      userId: widget.member.userId,
      fullName: name,
      phone: phone,
      status: _backendStatusValue(_status),
      roleId: _sendRole ? _roleId : null,
      password: newPassword.isEmpty ? null : newPassword,
    );

    if (!mounted) return;
    if (result.success) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSubmitting = false;
      _error = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Edit Team Member",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: "Full name",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: "Phone",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  items: const [
                    DropdownMenuItem(value: "ACTIVE", child: Text("ACTIVE")),
                    DropdownMenuItem(
                      value: "INACTIVE",
                      child: Text("INACTIVE"),
                    ),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (v) => setState(() => _status = v ?? "ACTIVE"),
                  decoration: const InputDecoration(
                    labelText: "Status",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _roleId,
                  items: _roles
                      .map(
                        (r) => DropdownMenuItem<int>(
                          value: r.roleId,
                          child: Text(r.roleName),
                        ),
                      )
                      .toList(),
                  onChanged: _isSubmitting || _rolesLoading || _roles.isEmpty
                      ? null
                      : (v) => setState(() {
                          _roleId = v;
                          _sendRole = true;
                        }),
                  decoration: const InputDecoration(
                    labelText: "Role",
                    helperText:
                        "Loaded from server roles. Owner role is intentionally blocked.",
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_rolesLoading) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                if (_rolesError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _rolesError!,
                    style: const TextStyle(color: Colors.orange),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _newPasswordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "New password (optional)",
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _save,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_isSubmitting ? "Saving..." : "Save Changes"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
