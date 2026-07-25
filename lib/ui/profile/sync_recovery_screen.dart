import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:mehfooz_accounts_app/theme/app_colors.dart';
import 'package:mehfooz_accounts_app/viewmodel/sync/sync_viewmodel.dart';

class SyncRecoveryScreen extends StatefulWidget {
  final SyncViewModel syncVM;

  const SyncRecoveryScreen({super.key, required this.syncVM});

  @override
  State<SyncRecoveryScreen> createState() => _SyncRecoveryScreenState();
}

class _SyncRecoveryScreenState extends State<SyncRecoveryScreen> {
  bool _loading = true;
  bool _runningAction = false;
  String? _error;
  Map<String, int> _counts = const {};

  SyncViewModel get _svm => widget.syncVM;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    final repo = _svm.syncRepo;
    if (repo == null) {
      setState(() {
        _loading = false;
        _error = 'Sync repository is not attached yet.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _svm.refreshPendingBatches(silent: true);
      final db = repo.db;

      Future<int> q(
        String sql, {
        List<Variable<Object>> vars = const [],
      }) async {
        final row = await db.customSelect(sql, variables: vars).getSingle();
        final value = row.data.values.first;
        if (value is int) return value;
        if (value is num) return value.toInt();
        return int.tryParse(value?.toString() ?? '') ?? 0;
      }

      final unsyncedTransactions = await q(
        'SELECT COUNT(*) AS c FROM Transactions_P WHERE COALESCE(IsSynced,0)=0;',
      );
      final unsyncedAccounts = await q(
        'SELECT COUNT(*) AS c FROM Acc_Personal WHERE COALESCE(IsSynced,0)=0;',
      );
      final unsyncedAssignments = await q(
        'SELECT COUNT(*) AS c FROM Account_PCurrencyAssignment WHERE COALESCE(IsSynced,0)=0;',
      );
      final unsyncedAccTypes = await q(
        'SELECT COUNT(*) AS c FROM AccType WHERE COALESCE(IsSynced,0)=0;',
      );
      final orphanAssignments = await q('''
        SELECT COUNT(*) AS c
        FROM Account_PCurrencyAssignment apca
        LEFT JOIN Acc_Personal ap ON ap.AccID = apca.AccID
        WHERE ap.AccID IS NULL
        ''');
      final duplicateCompanyGroups = await q('''
        SELECT COUNT(*) AS c
        FROM (
          SELECT LOWER(TRIM(COALESCE(CompanyName,''))) AS n, COUNT(*) AS k
          FROM Company
          GROUP BY LOWER(TRIM(COALESCE(CompanyName,'')))
          HAVING n <> '' AND k > 1
        ) t
        ''');

      final summary = <String, int>{
        'unsyncedTransactions': unsyncedTransactions,
        'unsyncedAccounts': unsyncedAccounts,
        'unsyncedAssignments': unsyncedAssignments,
        'unsyncedAccTypes': unsyncedAccTypes,
        'orphanAssignments': orphanAssignments,
        'duplicateCompanyGroups': duplicateCompanyGroups,
      };

      if (!mounted) return;
      setState(() {
        _counts = summary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _runAction(
    Future<void> Function() action,
    String successText,
  ) async {
    if (_runningAction) return;
    setState(() => _runningAction = true);
    try {
      await action();
      await _loadDiagnostics();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successText),
          backgroundColor: AppColors.darkgreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Action failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _runningAction = false);
    }
  }

  int _count(String key) => _counts[key] ?? 0;

  @override
  Widget build(BuildContext context) {
    final totalUnsynced =
        _count('unsyncedTransactions') +
        _count('unsyncedAccounts') +
        _count('unsyncedAssignments') +
        _count('unsyncedAccTypes');
    final hasRisk =
        _count('orphanAssignments') > 0 || _count('duplicateCompanyGroups') > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('Sync Recovery Center'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadDiagnostics,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (_svm.isPushPermissionMissing) ...[
              _permissionSafeguardCard(),
              const SizedBox(height: 12),
            ],
            _statusCard(totalUnsynced: totalUnsynced, hasRisk: hasRisk),
            const SizedBox(height: 12),
            _actionsCard(),
            const SizedBox(height: 12),
            _diagnosticsCard(),
            const SizedBox(height: 12),
            _pendingBatchesCard(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _errorCard(_error!),
            ],
            if (_loading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _permissionSafeguardCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Push is disabled for this user (missing sync.write). '
              'Sync is running in pull-only mode, so local unsynced rows will stay pending.',
              style: TextStyle(
                color: Color(0xFF9A3412),
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard({required int totalUnsynced, required bool hasRisk}) {
    final canSync = _svm.canSync;
    final statusText = _svm.isSyncing
        ? 'Sync in progress'
        : !canSync
        ? _svm.syncBlockReason
        : totalUnsynced == 0
        ? 'Healthy'
        : 'Needs attention';
    final statusColor = _svm.isSyncing
        ? const Color(0xFF2563EB)
        : !canSync
        ? const Color(0xFFB45309)
        : hasRisk
        ? const Color(0xFFB91C1C)
        : totalUnsynced > 0
        ? const Color(0xFF7C3AED)
        : const Color(0xFF15803D);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Pending local rows: $totalUnsynced',
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _svm.lastSyncedTime == null
                ? 'Last synced: never'
                : 'Last synced: ${_svm.lastSyncedTime}',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
          if (_svm.lastMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _svm.lastMessage,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recovery Actions',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _runningAction || !_svm.canSync
                      ? null
                      : () => _runAction(
                          () => _svm.syncNowSingleFlight(silent: false),
                          'Sync retry started.',
                        ),
                  child: const Text('Retry Now'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _runningAction || !_svm.canSync
                      ? null
                      : () => _runAction(
                          () => _svm.syncNowIfNeededSingleFlight(
                            force: true,
                            silent: false,
                          ),
                          'Forced sync snapshot started.',
                        ),
                  child: const Text('Force Sync'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _runningAction ? null : _loadDiagnostics,
              child: const Text('Refresh Diagnostics'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _diagnosticsCard() {
    Widget row(String label, int value, {bool alert = false}) {
      final color = alert && value > 0
          ? const Color(0xFFB91C1C)
          : const Color(0xFF0F172A);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Local Queue Diagnostics',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          row('Unsynced transactions', _count('unsyncedTransactions')),
          row('Unsynced accounts', _count('unsyncedAccounts')),
          row('Unsynced assignments', _count('unsyncedAssignments')),
          row('Unsynced account types', _count('unsyncedAccTypes')),
          const Divider(height: 18),
          row(
            'Orphan assignment rows',
            _count('orphanAssignments'),
            alert: true,
          ),
          row(
            'Duplicate company-name groups',
            _count('duplicateCompanyGroups'),
            alert: true,
          ),
        ],
      ),
    );
  }

  Widget _pendingBatchesCard() {
    final items = _svm.pendingBatches;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Server Pending Batches',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text(
              'No pending batches for this device.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            )
          else
            ...items
                .take(10)
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.batchId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${e.entryCount} rows',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          e.status,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _errorCard(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFB91C1C),
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
    );
  }
}
