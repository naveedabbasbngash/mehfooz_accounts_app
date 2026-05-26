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

// Brand colors (used in header card + dialogs)
const Color _kProfileBlue = Color(0xFF1862A3);
const Color _kProfileBlueDark = Color(0xFF0F4E88);
const Color _kProfileBg = Color(0xFFF4F8FC);

// iOS Settings design system
const Color _kSettingsBg = Color(0xFFF2F2F7);
const Color _kTextPrimary = Color(0xFF000000);
const Color _kTextSecondary = Color(0xFF8E8E93);
const Color _kDivider = Color(0xFFE5E5EA);
const Color _kChevron = Color(0xFFC7C7CC);

// Icon backgrounds and foregrounds
const Color _kIconBlue = Color(0xFF007AFF);
const Color _kIconBlueBg = Color(0xFFE5F1FF);
const Color _kIconGreen = Color(0xFF34C759);
const Color _kIconGreenBg = Color(0xFFE8F9EC);
const Color _kIconOrange = Color(0xFFFF9500);
const Color _kIconOrangeBg = Color(0xFFFFF3E0);
const Color _kIconRed = Color(0xFFFF3B30);
const Color _kIconRedBg = Color(0xFFFFEBEA);
const Color _kIconYellow = Color(0xFFFFCC00);
const Color _kIconYellowBg = Color(0xFFFFFCE0);
const Color _kIconGray = Color(0xFF8E8E93);
const Color _kIconGrayBg = Color(0xFFEEEEF0);
const Color _kIconPurple = Color(0xFFAF52DE);
const Color _kIconPurpleBg = Color(0xFFF3E8FF);

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
    final enabled = await ReportPreferencesService.getSubgroupFiltersEnabled();
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
          backgroundColor: _kSettingsBg,
          body: Stack(
            children: [
              const _ProfileBackdrop(),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _userHeaderCard(context, user, svm),
                      const SizedBox(height: 28),

                      if (user.planStatus != null ||
                          user.expiry != null ||
                          user.subscription != null) ...[
                        _iosSectionHeader('Subscription'),
                        _iosPlanSection(user),
                        const SizedBox(height: 28),
                      ],

                      if (vm.companies.isNotEmpty) ...[
                        _iosSectionHeader('Company / Business'),
                        _iosCompanySection(
                          context,
                          vm,
                          homeVM,
                          canManageCompanies: canManageCompanies,
                        ),
                        const SizedBox(height: 28),
                      ],

                      _iosSectionHeader('Sync'),
                      _iosSyncSection(context, svm, vm),
                      const SizedBox(height: 28),

                      _iosSectionHeader('Local Data'),
                      _iosLocalDataSection(context, vm),
                      const SizedBox(height: 28),

                      _iosSectionHeader('Settings'),
                      _iosSettingsAndTeamSection(context),
                      const SizedBox(height: 28),

                      _iosDangerSection(context, vm),
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

  // ─────────────── iOS SECTION HELPERS ───────────────

  Widget _iosSectionHeader(String label, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _kTextSecondary,
                letterSpacing: 0.6,
              ),
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _iosCard(List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1)
              const Divider(
                height: 1,
                thickness: 0.5,
                indent: 58,
                endIndent: 0,
                color: _kDivider,
              ),
          ],
        ],
      ),
    );
  }

  Widget _iosRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    bool showChevron = true,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        color: enabled ? _kTextPrimary : _kTextSecondary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: _kTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
              if (showChevron && onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: _kChevron, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────── PLAN SECTION ───────────────

  Widget _iosPlanSection(UserModel user) {
    final items = <Widget>[];

    if (user.planStatus != null) {
      items.add(
        _iosRow(
          icon: Icons.workspace_premium_rounded,
          iconBg: _kIconYellowBg,
          iconColor: _kIconYellow,
          title: 'Plan Status',
          trailing: Text(
            user.planStatus!.statusText,
            style: const TextStyle(color: _kTextSecondary, fontSize: 15),
          ),
          showChevron: false,
        ),
      );
    }

    if (user.expiry != null) {
      items.add(
        _iosRow(
          icon: Icons.timer_outlined,
          iconBg: _kIconOrangeBg,
          iconColor: _kIconOrange,
          title: 'Remaining Days',
          trailing: Text(
            '${user.expiry!.remainingDays} days',
            style: const TextStyle(color: _kTextSecondary, fontSize: 15),
          ),
          showChevron: false,
        ),
      );
    }

    if (user.subscription != null) {
      items.add(
        _iosRow(
          icon: Icons.calendar_month_rounded,
          iconBg: _kIconBlueBg,
          iconColor: _kIconBlue,
          title: 'Subscription',
          trailing: Text(
            user.subscription!.planTitle,
            style: const TextStyle(color: _kTextSecondary, fontSize: 15),
          ),
          showChevron: false,
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();
    return _iosCard(items);
  }

  // ─────────────── COMPANY SECTION ───────────────

  Widget _iosCompanySection(
    BuildContext context,
    ProfileViewModel vm,
    HomeViewModel homeVM, {
    required bool canManageCompanies,
  }) {
    final selectedId = homeVM.selectedCompanyId;
    final selected = selectedId == null
        ? null
        : vm.companies.firstWhere(
            (c) => c.companyId == selectedId,
            orElse: () => vm.companies.first,
          );

    return _iosCard([
      _iosRow(
        icon: Icons.business_center_rounded,
        iconBg: _kIconBlueBg,
        iconColor: _kIconBlue,
        title: selected?.companyName ?? 'Select Company',
        subtitle:
            '${vm.companies.length} ${vm.companies.length == 1 ? 'company' : 'companies'} available',
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _CompanyListScreen(
                vm: vm,
                homeVM: homeVM,
                canManage: canManageCompanies,
              ),
            ),
          );
          if (!mounted) return;
          setState(() {});
        },
      ),
    ]);
  }

  // ─────────────── SYNC SECTION ───────────────

  Widget _iosSyncSection(
    BuildContext context,
    SyncViewModel svm,
    ProfileViewModel vm,
  ) {
    return Column(
      children: [
        _iosCard([
          // Sync row (custom — needs pending chip + sync button)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _kIconBlueBg,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(
                    Icons.sync_rounded,
                    color: _kIconBlue,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sync',
                        style: TextStyle(fontSize: 16, color: _kTextPrimary),
                      ),
                      if (svm.lastSyncedTime != null)
                        Text(
                          'Last synced: ${_timeAgo(svm.lastSyncedTime!)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _kTextSecondary,
                          ),
                        ),
                      if (!svm.canSync)
                        Text(
                          svm.syncBlockReason,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _kIconOrange,
                          ),
                        ),
                    ],
                  ),
                ),
                _pendingCountChip(svm),
                const SizedBox(width: 8),
                _pendingToggleButton(svm),
                const SizedBox(width: 8),
                _syncCapsule(svm),
              ],
            ),
          ),

          // Auto Sync row
          _iosRow(
            icon: Icons.schedule_rounded,
            iconBg: _kIconGreenBg,
            iconColor: _kIconGreen,
            title: 'Auto Sync',
            trailing: Text(
              svm.labelForInterval,
              style: const TextStyle(color: _kTextSecondary, fontSize: 15),
            ),
            onTap: svm.canSync ? () => _showAutoSyncSheet(context, svm) : null,
            enabled: svm.canSync,
          ),
        ]),

        // Syncing progress bar
        if (svm.isSyncing) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: svm.syncProgress,
              minHeight: 5,
              color: _kProfileBlue,
              backgroundColor: const Color(0xFFDCE7F8),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: svm.cancelSync,
              child: const Text('Cancel'),
            ),
          ),
        ],

        // Pending batches panel
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          child: _showPendingBatches
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _pendingBatchesPanel(context, svm),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ─────────────── LOCAL DATA SECTION ───────────────

  Widget _iosLocalDataSection(BuildContext context, ProfileViewModel vm) {
    return _iosCard([
      _iosRow(
        icon: Icons.file_open_outlined,
        iconBg: _kIconOrangeBg,
        iconColor: _kIconOrange,
        title: 'Import Database',
        subtitle: 'Load a local SQLite file',
        enabled: vm.canImport,
        onTap: vm.canImport
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
      _iosRow(
        icon: Icons.ios_share_rounded,
        iconBg: _kIconBlueBg,
        iconColor: _kIconBlue,
        title: vm.isExportingDatabase
            ? 'Preparing…'
            : 'Export & Share Database',
        subtitle: 'Share via WhatsApp or any app',
        trailing: vm.isExportingDatabase
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _kIconBlue,
                ),
              )
            : null,
        showChevron: !vm.isExportingDatabase,
        onTap: vm.isExportingDatabase
            ? null
            : () async {
                final error = await vm.exportAndShareDatabase();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      error ??
                          'Database ready to share via WhatsApp or any app.',
                    ),
                    backgroundColor: error == null
                        ? AppColors.darkgreen
                        : Colors.red,
                  ),
                );
              },
      ),
    ]);
  }

  // ─────────────── SETTINGS + TEAM SECTION ───────────────

  Widget _iosSettingsAndTeamSection(BuildContext context) {
    final count = _teamMembers.length;
    final teamSubtitle = _teamLoading
        ? 'Refreshing team…'
        : _teamError != null
        ? _teamError!
        : count == 0
        ? (_canManageTeam
              ? 'Tap to invite your first member'
              : 'No team members yet')
        : '$count active ${count == 1 ? 'member' : 'members'}';

    final items = <Widget>[
      _iosRow(
        icon: Icons.tune_rounded,
        iconBg: _kIconGrayBg,
        iconColor: _kIconGray,
        title: 'App Settings',
        subtitle: _trailBalanceFiltersEnabled
            ? 'Trail Balance opens filters before export'
            : 'Trail Balance exports directly',
        onTap: () => _showAppSettingsSheet(context),
      ),
    ];

    if (!_teamAccessDenied) {
      items.add(
        _iosRow(
          icon: Icons.groups_rounded,
          iconBg: _kIconBlueBg,
          iconColor: _kIconBlue,
          title: 'Team Members',
          subtitle: teamSubtitle,
          trailing: count > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _kIconBlueBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kIconBlue,
                    ),
                  ),
                )
              : null,
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
        ),
      );
    }

    return _iosCard(items);
  }

  // ─────────────── DANGER SECTION ───────────────

  Widget _iosDangerSection(BuildContext context, ProfileViewModel vm) {
    return _iosCard([
      _iosRow(
        icon: Icons.delete_forever_rounded,
        iconBg: _kIconRedBg,
        iconColor: _kIconRed,
        title: 'Delete Account',
        subtitle: 'Permanently delete your account and data',
        onTap: () => _confirmDeleteAccount(context, vm),
      ),
    ]);
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

  Widget _userHeaderCard(
    BuildContext context,
    UserModel user,
    SyncViewModel svm,
  ) {
    final roleLabel = _profileRoleLabel(user);
    final statusText = user.planStatus?.statusText.trim();
    final initials = _profileName(user)
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E72C8), _kProfileBlue, Color(0xFF0B3E7A)],
          stops: [0.0, 0.52, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Color(0x441862A3),
            blurRadius: 32,
            spreadRadius: -4,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            // Decorative background blobs
            Positioned(
              top: -36,
              right: -28,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -30,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              top: 38,
              right: 82,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Glassmorphism logout pill — top right
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => _smartLogout(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.logout_rounded,
                              size: 11,
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Logout',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Avatar + name/email row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar with white border ring
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.55),
                            width: 2,
                          ),
                        ),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.24),
                                Colors.white.withValues(alpha: 0.10),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: user.imageUrl.isNotEmpty
                                ? Image.network(
                                    user.imageUrl,
                                    fit: BoxFit.cover,
                                  )
                                : Center(
                                    child: Text(
                                      initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Name + email
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
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(
                                  Icons.mail_outline_rounded,
                                  size: 11,
                                  color: Colors.white.withValues(alpha: 0.68),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    user.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.80,
                                      ),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Gradient hairline divider
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.20),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Role + plan pills
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
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

  void _showAutoSyncSheet(BuildContext context, SyncViewModel svm) {
    // Per-interval UI metadata — display only, no logic change
    const meta =
        <
          AutoSyncInterval,
          ({IconData icon, Color bg, Color fg, String label, String sub})
        >{
          AutoSyncInterval.off: (
            icon: Icons.sync_disabled_rounded,
            bg: _kIconRedBg,
            fg: _kIconRed,
            label: 'Off',
            sub: 'Manual sync only',
          ),
          AutoSyncInterval.sec30: (
            icon: Icons.bolt_rounded,
            bg: _kIconOrangeBg,
            fg: _kIconOrange,
            label: 'Every 30 seconds',
            sub: 'High frequency',
          ),
          AutoSyncInterval.min2: (
            icon: Icons.schedule_rounded,
            bg: _kIconGreenBg,
            fg: _kIconGreen,
            label: 'Every 2 minutes',
            sub: 'Recommended',
          ),
          AutoSyncInterval.min5: (
            icon: Icons.av_timer_rounded,
            bg: _kIconBlueBg,
            fg: _kIconBlue,
            label: 'Every 5 minutes',
            sub: 'Balanced',
          ),
          AutoSyncInterval.min20: (
            icon: Icons.battery_saver_rounded,
            bg: _kIconGrayBg,
            fg: _kIconGray,
            label: 'Every 20 minutes',
            sub: 'Battery saver',
          ),
        };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: _kSettingsBg,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _kDivider,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Header row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_kProfileBlue, _kProfileBlueDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.schedule_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auto Sync',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: _kTextPrimary,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Choose how often to sync your data',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _kTextSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Options card
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Column(
                        children: () {
                          final intervals = AutoSyncInterval.values;
                          final rows = <Widget>[];
                          for (int i = 0; i < intervals.length; i++) {
                            final interval = intervals[i];
                            final m = meta[interval]!;
                            final isActive = svm.autoSyncInterval == interval;
                            rows.add(
                              Material(
                                color: isActive
                                    ? const Color(0xFFF0F8FF)
                                    : Colors.white,
                                child: InkWell(
                                  onTap: () {
                                    svm.setAutoSyncInterval(interval);
                                    Navigator.pop(context);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 13,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: m.bg,
                                            borderRadius: BorderRadius.circular(
                                              9,
                                            ),
                                          ),
                                          child: Icon(
                                            m.icon,
                                            color: m.fg,
                                            size: 19,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                m.label,
                                                style: TextStyle(
                                                  fontSize: 15.5,
                                                  fontWeight: isActive
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                  color: isActive
                                                      ? _kProfileBlue
                                                      : _kTextPrimary,
                                                ),
                                              ),
                                              Text(
                                                m.sub,
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  color: _kTextSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isActive)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: _kIconBlue,
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                            if (i < intervals.length - 1) {
                              rows.add(
                                const Divider(
                                  height: 1,
                                  thickness: 0.5,
                                  indent: 66,
                                  endIndent: 0,
                                  color: _kDivider,
                                ),
                              );
                            }
                          }
                          return rows;
                        }(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
    HomeViewModel homeVM, {
    required bool canManageCompanies,
  }) {
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
          content: Text(
            'You already have 2 companies. New companies cannot be added.',
          ),
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
      title: 'Edit Company / Business',
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
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  16,
                  18,
                  MediaQuery.of(sheetContext).padding.bottom + 18,
                ),
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
                                Navigator.pop(sheetContext, (
                                  nameController.text.trim(),
                                  remarksController.text.trim(),
                                ));
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
                          width: count == 1
                              ? 28
                              : count == 2
                              ? 46
                              : 64,
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
                                      ((_teamMembers[index].fullName
                                                      .trim()
                                                      .isNotEmpty
                                                  ? _teamMembers[index].fullName
                                                        .trim()
                                                  : _teamMembers[index].email
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

// ═══════════════════════════════════════════════════════════
//  COMPANY LIST SCREEN
// ═══════════════════════════════════════════════════════════

class _CompanyListScreen extends StatefulWidget {
  final ProfileViewModel vm;
  final HomeViewModel homeVM;
  final bool canManage;

  const _CompanyListScreen({
    required this.vm,
    required this.homeVM,
    required this.canManage,
  });

  @override
  State<_CompanyListScreen> createState() => _CompanyListScreenState();
}

class _CompanyListScreenState extends State<_CompanyListScreen> {
  bool _canManageCompanies() {
    final roles = widget.vm.loggedInUser.roleCodes
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

  Future<void> _addCompany() async {
    if (!_canManageCompanies()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Viewer role has read-only access to companies'),
        ),
      );
      return;
    }
    if (widget.vm.companies.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You already have 2 companies. New companies cannot be added.',
          ),
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

    if (payload == null || !mounted) return;
    final normalizedName = payload.$1.trim().toLowerCase();
    final exists = widget.vm.companies.any(
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
    final error = await widget.vm.addCompany(
      context: context,
      name: payload.$1,
      remarks: payload.$2,
    );
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Company added successfully.'),
        backgroundColor: error == null ? AppColors.darkgreen : Colors.red,
      ),
    );
  }

  Future<void> _editCompany(CompanyTableData company) async {
    if (!_canManageCompanies()) return;
    final payload = await _showCompanyEditorSheet(
      context,
      title: 'Edit Company / Business',
      actionLabel: 'Save Changes',
      initialName: company.companyName ?? '',
      initialRemarks: company.remarks ?? '',
    );
    if (payload == null || !mounted) return;
    final error = await widget.vm.updateCompany(
      context: context,
      companyId: company.companyId,
      name: payload.$1,
      remarks: payload.$2,
    );
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Company updated.'),
        backgroundColor: error == null ? AppColors.darkgreen : Colors.red,
      ),
    );
  }

  Future<void> _deleteCompany(CompanyTableData company) async {
    if (!_canManageCompanies()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Company'),
        content: Text(
          "Delete '${company.companyName ?? 'this company'}' (ID: ${company.companyId})?\n\nAll company transactions and accounts will be removed.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final error = await widget.vm.deleteCompany(
      context: context,
      companyId: company.companyId,
    );
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Company deleted.'),
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
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  16,
                  18,
                  MediaQuery.of(sheetContext).padding.bottom + 18,
                ),
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
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
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Create or update a company space.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.45,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: nameController,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                        decoration: InputDecoration(
                          labelText: 'Company Name',
                          hintText: nameHint ?? 'Enter company name',
                          prefixIcon: const Icon(
                            Icons.apartment_rounded,
                            color: _kProfileBlue,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FBFF),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFFDCE7F8),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFFDCE7F8),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: _kProfileBlue,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: remarksController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Remarks',
                          hintText: 'Optional notes',
                          prefixIcon: const Icon(
                            Icons.edit_note_rounded,
                            color: _kProfileBlue,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FBFF),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFFDCE7F8),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFFDCE7F8),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: _kProfileBlue,
                              width: 1.4,
                            ),
                          ),
                        ),
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
                                Navigator.pop(sheetContext, (
                                  nameController.text.trim(),
                                  remarksController.text.trim(),
                                ));
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

  @override
  Widget build(BuildContext context) {
    final companies = widget.vm.companies;
    final selectedId = widget.homeVM.selectedCompanyId;

    return Scaffold(
      backgroundColor: _kSettingsBg,
      body: Stack(
        children: [
          const _ProfileBackdrop(),
          SafeArea(
            child: Column(
              children: [
                // ── Custom AppBar ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 12, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: _kIconBlue,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'Company / Business',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _kTextPrimary,
                          ),
                        ),
                      ),
                      if (widget.canManage)
                        TextButton.icon(
                          onPressed: _addCompany,
                          icon: const Icon(
                            Icons.add_business_outlined,
                            size: 18,
                            color: _kIconBlue,
                          ),
                          label: const Text(
                            'Add',
                            style: TextStyle(
                              color: _kIconBlue,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Scrollable content ──
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (companies.isEmpty)
                          _buildEmptyState()
                        else ...[
                          // Section label
                          Padding(
                            padding: const EdgeInsets.only(left: 16, bottom: 8),
                            child: Text(
                              '${companies.length} ${companies.length == 1 ? 'WORKSPACE' : 'WORKSPACES'}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _kTextSecondary,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),

                          // Company list card
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: Column(
                              children: [
                                for (int i = 0; i < companies.length; i++) ...[
                                  _CompanyRow(
                                    company: companies[i],
                                    isSelected:
                                        companies[i].companyId == selectedId,
                                    canManage: widget.canManage,
                                    onTap: () async {
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
                                      final name =
                                          companies[i].companyName ?? 'Company';
                                      await widget.homeVM.setCompany(
                                        companies[i].companyId,
                                      );
                                      if (!mounted) return;
                                      setState(() {});
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '$name is now the active workspace.',
                                          ),
                                          backgroundColor: AppColors.darkgreen,
                                        ),
                                      );
                                    },
                                    onEdit: () => _editCompany(companies[i]),
                                    onDelete: () =>
                                        _deleteCompany(companies[i]),
                                  ),
                                  if (i < companies.length - 1)
                                    const Divider(
                                      height: 1,
                                      thickness: 0.5,
                                      indent: 58,
                                      endIndent: 0,
                                      color: _kDivider,
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _kIconBlueBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.business_center_rounded,
              color: _kIconBlue,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No companies yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _kTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap Add to create your first company.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _kTextSecondary),
          ),
        ],
      ),
    );
  }
}

// Single company row used inside _CompanyListScreen
class _CompanyRow extends StatelessWidget {
  final CompanyTableData company;
  final bool isSelected;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CompanyRow({
    required this.company,
    required this.isSelected,
    required this.canManage,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? const Color(0xFFF0F8FF) : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Icon box
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [_kProfileBlue, _kProfileBlueDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : _kIconGrayBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSelected ? Icons.business_rounded : Icons.apartment_rounded,
                  color: isSelected ? Colors.white : _kIconGray,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),

              // Name + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.companyName ?? 'Unnamed',
                      style: TextStyle(
                        fontSize: 16,
                        color: isSelected ? _kProfileBlue : _kTextPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (isSelected) ...[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: _kIconGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          isSelected
                              ? 'Active workspace'
                              : 'Tap to switch workspace',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? _kIconGreen : _kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Active checkmark
              if (isSelected)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: _kIconBlue,
                    size: 20,
                  ),
                ),

              // Manage actions
              if (canManage)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ActionPill(
                      icon: Icons.edit_outlined,
                      color: _kTextSecondary,
                      tooltip: 'Edit',
                      onTap: onEdit,
                    ),
                    const SizedBox(width: 6),
                    _ActionPill(
                      icon: Icons.delete_outline,
                      color: _kIconRed,
                      tooltip: 'Delete',
                      onTap: onDelete,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Small tappable icon button used in _CompanyRow
class _ActionPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionPill({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
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
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _kIconRedBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: _kIconRed,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _error!,
                style: const TextStyle(
                  color: _kIconRed,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final ownerName = widget.loggedInUser.fullName.trim().isEmpty
        ? widget.loggedInUser.email
        : widget.loggedInUser.fullName;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
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
              _OwnerTreeCard(
                title: _displayText(ownerName),
                email: widget.loggedInUser.email.trim(),
              ),
              if (_members.isNotEmpty) const _TreeConnector(height: 22),
              if (_members.isEmpty)
                Container(
                  width: 160,
                  constraints: const BoxConstraints(minHeight: 72),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kSettingsBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kDivider),
                  ),
                  child: const Center(
                    child: Text(
                      'No Team Members',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kTextSecondary,
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

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _kTextSecondary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildDirectory() {
    if (_accessDenied) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _kIconGrayBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: _kIconGray,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Team members are not available for this account.',
                style: TextStyle(
                  color: _kTextSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_loading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Text(
          _error!,
          style: const TextStyle(
            color: _kIconRed,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      );
    }

    if (_members.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _kIconBlueBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                color: _kIconBlue,
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _canManage
                  ? 'No team members yet.\nTap Add to invite your first member.'
                  : 'No team members assigned yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _kTextSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    // iOS-style white card containing all members as a list
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: List.generate(_members.length, (index) {
          final member = _members[index];
          final isLast = index == _members.length - 1;
          return _TeamMemberDirectoryCard(
            member: member,
            initials: _initials(member),
            displayName: _displayName(member),
            statusTint: _statusTint(member.status),
            statusColor: _statusColor(member.status),
            canManage: _canManage,
            isHighlighted: _selectedMemberUserId == member.userId,
            showDivider: !isLast,
            onEdit: () => _openEditMember(member),
            onDelete: () => _deleteMember(member),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSettingsBg,
      body: Stack(
        children: [
          const _ProfileBackdrop(),
          SafeArea(
            child: Column(
              children: [
                // ── Custom header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: _kTextPrimary,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Team Members',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _kTextPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _loading ? null : () => _refresh(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.refresh_rounded,
                            size: 20,
                            color: _loading ? _kChevron : _kTextPrimary,
                          ),
                        ),
                      ),
                      if (_canManage) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _openAddMember,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1E72C8), _kProfileBlue],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_add_rounded,
                                  size: 15,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Add',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Scrollable body ──
                Expanded(
                  child: RefreshIndicator(
                    color: _kProfileBlue,
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        if (!_accessDenied) ...[
                          _sectionLabel('Organization'),
                          const SizedBox(height: 8),
                          _buildOverview(),
                          const SizedBox(height: 24),
                        ],
                        _sectionLabel(
                          _members.isEmpty
                              ? 'Directory'
                              : 'Directory · ${_members.length}',
                        ),
                        const SizedBox(height: 8),
                        _buildDirectory(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
  final String email;

  const _OwnerTreeCard({required this.title, required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E72C8), _kProfileBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x301862A3),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_rounded, color: Colors.white, size: 18),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            'Owner',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
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
  final bool showDivider;
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
    required this.showDivider,
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

    return Column(
      children: [
        Container(
          color: isHighlighted ? const Color(0xFFF0F8FF) : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                // Avatar circle
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E72C8), _kProfileBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name + subtitle row
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _kTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        member.email.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: _kTextSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusTint,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              roleLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _kTextSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions
                if (canManage) ...[
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: _kIconBlue,
                    ),
                    tooltip: 'Edit',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: _kIconRed,
                    ),
                    tooltip: 'Delete',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 68),
            child: Divider(height: 1, thickness: 1, color: _kDivider),
          ),
      ],
    );
  }
}

InputDecoration _sheetInput(
  String label, {
  IconData? icon,
  String? helper,
  Widget? suffix,
}) {
  return InputDecoration(
    labelText: label,
    helperText: helper,
    helperMaxLines: 2,
    prefixIcon: icon != null ? Icon(icon, size: 18, color: _kIconBlue) : null,
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _kDivider),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _kDivider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _kIconBlue, width: 1.5),
    ),
    labelStyle: const TextStyle(color: _kTextSecondary),
  );
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
          color: _kSettingsBg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              18,
              0,
              18,
              MediaQuery.of(context).padding.bottom + 18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _kChevron,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E72C8), _kProfileBlue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Add Team Member',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: _kTextPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Create a new team account',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: _kTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: _kTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: _sheetInput(
                    'Full name',
                    icon: Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: _sheetInput(
                    'Email',
                    icon: Icons.mail_outline_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: _sheetInput(
                    'Phone (optional)',
                    icon: Icons.phone_outlined,
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
                  decoration: _sheetInput(
                    'Role',
                    icon: Icons.badge_outlined,
                    helper:
                        'Loaded from server roles. If unavailable, backend default role will be used.',
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
                  decoration: _sheetInput(
                    'Temporary password',
                    icon: Icons.lock_outline_rounded,
                    suffix: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  decoration: _sheetInput(
                    'Confirm password',
                    icon: Icons.lock_outline_rounded,
                    suffix: IconButton(
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kIconRedBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: _kIconRed,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: _kIconRed,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E72C8), _kProfileBlue],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x441862A3),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isSubmitting ? null : _submit,
                      borderRadius: BorderRadius.circular(16),
                      child: Center(
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_add_alt_1,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Create User',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
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
          color: _kSettingsBg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              18,
              0,
              18,
              MediaQuery.of(context).padding.bottom + 18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _kChevron,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E72C8), _kProfileBlue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.manage_accounts_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Edit Team Member',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: _kTextPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Update member details',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: _kTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: _kTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: _sheetInput(
                    'Full name',
                    icon: Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailCtrl,
                  readOnly: true,
                  decoration: _sheetInput(
                    'Email',
                    icon: Icons.mail_outline_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: _sheetInput('Phone', icon: Icons.phone_outlined),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  items: const [
                    DropdownMenuItem(value: "ACTIVE", child: Text("Active")),
                    DropdownMenuItem(
                      value: "INACTIVE",
                      child: Text("Inactive"),
                    ),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (v) => setState(() => _status = v ?? "ACTIVE"),
                  decoration: _sheetInput(
                    'Status',
                    icon: Icons.toggle_on_outlined,
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
                  decoration: _sheetInput(
                    'Role',
                    icon: Icons.badge_outlined,
                    helper:
                        'Loaded from server roles. Owner role is intentionally blocked.',
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
                  decoration: _sheetInput(
                    'New password (optional)',
                    icon: Icons.lock_outline_rounded,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kIconRedBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: _kIconRed,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: _kIconRed,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E72C8), _kProfileBlue],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x441862A3),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isSubmitting ? null : _save,
                      borderRadius: BorderRadius.circular(16),
                      child: Center(
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.save_outlined,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Save Changes',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
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
