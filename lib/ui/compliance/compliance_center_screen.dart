import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/local/database_manager.dart';
import '../../model/audit_trail_row.dart';
import '../../model/period_lock_row.dart';
import '../../repository/transactions_repository.dart';
import '../../theme/app_colors.dart';
import '../../viewmodel/home/home_view_model.dart';

class ComplianceCenterScreen extends StatefulWidget {
  const ComplianceCenterScreen({super.key});

  @override
  State<ComplianceCenterScreen> createState() => _ComplianceCenterScreenState();
}

class _ComplianceCenterScreenState extends State<ComplianceCenterScreen>
    with SingleTickerProviderStateMixin {
  late final TransactionsRepository _repo = TransactionsRepository(
    DatabaseManager.instance.db,
  );
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );

  bool _loading = false;
  int? _companyId;
  List<PeriodLockRow> _locks = const [];
  List<AuditTrailRow> _audits = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentCompanyId = context.read<HomeViewModel>().selectedCompanyId;
    if (_companyId != currentCompanyId) {
      _companyId = currentCompanyId;
      _reload();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final companyId = _companyId;
    if (companyId == null || companyId <= 0) {
      if (!mounted) return;
      setState(() {
        _locks = const [];
        _audits = const [];
      });
      return;
    }

    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.getPeriodLocks(companyId: companyId),
        _repo.getAuditTrailRows(companyId: companyId, limit: 300),
      ]);
      if (!mounted) return;
      setState(() {
        _locks = results[0] as List<PeriodLockRow>;
        _audits = results[1] as List<AuditTrailRow>;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addLock() async {
    final companyId = _companyId;
    if (companyId == null || companyId <= 0) {
      _showSnack('Please select a company first.');
      return;
    }

    DateTime start = DateTime(DateTime.now().year, DateTime.now().month, 1);
    DateTime end = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
    String lockMode = 'HARD';
    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Add Period Lock'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start Date'),
                subtitle: Text(_fmtDate(start)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: start,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setStateDialog(() => start = picked);
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End Date'),
                subtitle: Text(_fmtDate(end)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: end,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setStateDialog(() => end = picked);
                  }
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: lockMode,
                decoration: const InputDecoration(
                  labelText: 'Lock Mode',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'HARD',
                    child: Text('HARD - fully locked'),
                  ),
                  DropdownMenuItem(
                    value: 'SOFT',
                    child: Text('SOFT - admin can override'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setStateDialog(() => lockMode = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save Lock'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    try {
      await _repo.createPeriodLock(
        companyId: companyId,
        startDate: start,
        endDate: end,
        lockMode: lockMode,
        reason: reasonCtrl.text.trim(),
      );
      _showSnack('Period lock added.');
      await _reload();
    } catch (e) {
      _showSnack(e.toString(), error: true);
    }
  }

  Future<void> _unlock(PeriodLockRow row) async {
    final companyId = _companyId;
    if (companyId == null || companyId <= 0) return;
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlock Period'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deactivatePeriodLock(
        periodLockId: row.periodLockId,
        companyId: companyId,
        reason: reasonCtrl.text.trim(),
      );
      _showSnack('Period unlocked.');
      await _reload();
    } catch (e) {
      _showSnack(e.toString(), error: true);
    }
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : AppColors.darkgreen,
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    final companyId = _companyId;

    if (companyId == null || companyId <= 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Select a company to manage period locks and audit trail.',
          ),
        ),
      );
    }

    return Column(
      children: [
        Material(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.homeColor,
            tabs: const [
              Tab(text: 'Period Locks'),
              Tab(text: 'Audit Trail'),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [_buildLocksTab(), _buildAuditTab()],
                ),
        ),
      ],
    );
  }

  Widget _buildLocksTab() {
    final activeLocks = _locks.where((e) => e.isActive).toList(growable: false);

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          FilledButton.icon(
            onPressed: _addLock,
            icon: const Icon(Icons.lock_outline),
            label: const Text('Add Period Lock'),
          ),
          const SizedBox(height: 12),
          if (_locks.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No period locks found.'),
              ),
            ),
          ..._locks.map(
            (row) => Card(
              child: ListTile(
                title: Text('${row.startDate}  ->  ${row.endDate}'),
                subtitle: Text(
                  row.reason.isEmpty
                      ? (row.isActive ? 'Active lock' : 'Inactive lock')
                      : row.reason,
                ),
                leading: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: row.lockMode.toUpperCase() == 'SOFT'
                        ? const Color(0xFFFFF7ED)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    row.lockMode.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: row.lockMode.toUpperCase() == 'SOFT'
                          ? const Color(0xFF9A3412)
                          : const Color(0xFFB91C1C),
                    ),
                  ),
                ),
                trailing: row.isActive
                    ? IconButton(
                        tooltip: 'Unlock',
                        onPressed: () => _unlock(row),
                        icon: const Icon(Icons.lock_open, color: Colors.red),
                      )
                    : const Icon(Icons.check_circle, color: Colors.green),
              ),
            ),
          ),
          if (activeLocks.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Active locks: ${activeLocks.length}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAuditTab() {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _audits.isEmpty ? 1 : _audits.length,
        itemBuilder: (_, index) {
          if (_audits.isEmpty) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No audit entries yet.'),
              ),
            );
          }

          final row = _audits[index];
          final title =
              '${row.entityType.toUpperCase()} - ${row.action.toUpperCase()}';
          return Card(
            child: ListTile(
              leading: const Icon(Icons.history_toggle_off),
              title: Text(title),
              subtitle: Text(
                '${row.message.isEmpty ? '(no message)' : row.message}\n${row.createdAt}',
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}
