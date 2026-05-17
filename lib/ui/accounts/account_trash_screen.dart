import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../data/local/app_database.dart';
import '../../data/local/database_manager.dart';
import '../../repository/transactions_repository.dart';
import '../../theme/app_colors.dart';

class AccountTrashScreen extends StatefulWidget {
  final int companyId;

  const AccountTrashScreen({super.key, required this.companyId});

  @override
  State<AccountTrashScreen> createState() => _AccountTrashScreenState();
}

class _AccountTrashScreenState extends State<AccountTrashScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  int? _restoringAccId;
  int? _deletingAccId;
  bool _deletingAll = false;
  bool _bulkRestoring = false;
  bool _bulkDeleting = false;
  bool _syncingDeletedTx = false;
  final Set<int> _selectedAccIds = <int>{};

  AppDatabase get _db => DatabaseManager.instance.db;
  TransactionsRepository get _repo => TransactionsRepository(_db);
  bool get _isSelectionMode => _selectedAccIds.isNotEmpty;
  bool get _isBusy =>
      _restoringAccId != null ||
      _deletingAccId != null ||
      _deletingAll ||
      _bulkRestoring ||
      _bulkDeleting;

  @override
  void initState() {
    super.initState();
    _syncSoftDeletedAccountTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _syncSoftDeletedAccountTransactions() async {
    if (_syncingDeletedTx) return;
    _syncingDeletedTx = true;
    try {
      final rows =
          await (_db.select(_db.accPersonal)..where(
                (t) =>
                    t.companyId.equals(widget.companyId) &
                    t.isDeleted.equals(1),
              ))
              .get();
      if (rows.isEmpty) return;
      final accIds = rows.map((r) => r.accId).toSet().toList(growable: false);
      await _repo.setAccountTransactionsDeletedState(
        companyId: widget.companyId,
        accIds: accIds,
        isDeleted: true,
      );
    } catch (_) {
      // Ignore silently: this is a best-effort consistency sync.
    } finally {
      _syncingDeletedTx = false;
    }
  }

  Stream<List<AccPersonalData>> _watchDeletedAccounts() {
    final query = _db.select(_db.accPersonal)
      ..where(
        (t) => t.companyId.equals(widget.companyId) & t.isDeleted.equals(1),
      )
      ..orderBy([
        (t) => OrderingTerm.desc(t.updatedAt),
        (t) => OrderingTerm.asc(t.name),
      ]);

    return query.watch().map(
      (rows) => rows
          .where((r) {
            final q = _search.trim().toLowerCase();
            if (q.isEmpty) return true;
            final name = (r.name ?? '').toLowerCase();
            final phone = (r.phone ?? '').toLowerCase();
            final head = (r.statusg ?? '').toLowerCase();
            final id = r.accId.toString();
            return name.contains(q) ||
                phone.contains(q) ||
                head.contains(q) ||
                id.contains(q);
          })
          .toList(growable: false),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '-';
    final dt = DateTime.tryParse(iso.trim());
    if (dt == null) return '-';
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year.toString();
    return '$d/$m/$y';
  }

  void _toggleSelection(int accId) {
    setState(() {
      if (_selectedAccIds.contains(accId)) {
        _selectedAccIds.remove(accId);
      } else {
        _selectedAccIds.add(accId);
      }
    });
  }

  Future<void> _restoreSelected() async {
    if (_selectedAccIds.isEmpty || _isBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore selected accounts?'),
        content: Text(
          'Restore ${_selectedAccIds.length} selected account(s) from trash?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restore Selected'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _bulkRestoring = true);
    try {
      final selectedIds = _selectedAccIds.toList(growable: false);
      await _repo.setAccountTransactionsDeletedState(
        companyId: widget.companyId,
        accIds: selectedIds,
        isDeleted: false,
      );
      final restored =
          await (_db.update(_db.accPersonal)..where(
                (t) =>
                    t.companyId.equals(widget.companyId) &
                    t.accId.isIn(selectedIds) &
                    t.isDeleted.equals(1),
              ))
              .write(
                AccPersonalCompanion(
                  isDeleted: const Value(0),
                  isSynced: const Value(0),
                  updatedAt: Value(DateTime.now().toIso8601String()),
                ),
              );

      if (!mounted) return;
      setState(() => _selectedAccIds.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restored $restored selected account(s).'),
          backgroundColor: AppColors.darkgreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore selected accounts: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _bulkRestoring = false);
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedAccIds.isEmpty || _isBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected permanently?'),
        content: Text(
          'Delete ${_selectedAccIds.length} selected account(s) forever?\n\nDeleting accounts permanently will also remove all transactions and related data for those accounts. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Selected'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _bulkDeleting = true);
    try {
      final selectedIds = _selectedAccIds.toList(growable: false);
      await _deleteTransactionsForAccounts(selectedIds);
      await _deleteCurrencyMappingsForAccounts(selectedIds);

      final deleted =
          await (_db.delete(_db.accPersonal)..where(
                (t) =>
                    t.companyId.equals(widget.companyId) &
                    t.accId.isIn(selectedIds) &
                    t.isDeleted.equals(1),
              ))
              .go();

      if (!mounted) return;
      setState(() => _selectedAccIds.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted $deleted selected account(s) forever.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete selected accounts: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _bulkDeleting = false);
    }
  }

  Future<void> _restore(AccPersonalData row) async {
    if (_isBusy) {
      return;
    }

    final restore = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore account?'),
        content: Text(
          "Account '${(row.name ?? '').trim().isEmpty ? row.accId : row.name}' will return to Accounts list.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (restore != true || !mounted) return;

    setState(() => _restoringAccId = row.accId);
    try {
      await _repo.setAccountTransactionsDeletedState(
        companyId: widget.companyId,
        accIds: [row.accId],
        isDeleted: false,
      );
      await (_db.update(
        _db.accPersonal,
      )..where((t) => t.accId.equals(row.accId))).write(
        AccPersonalCompanion(
          isDeleted: const Value(0),
          isSynced: const Value(0),
          updatedAt: Value(DateTime.now().toIso8601String()),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account restored successfully.'),
          backgroundColor: AppColors.darkgreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _restoringAccId = null);
    }
  }

  Future<void> _deleteForever(AccPersonalData row) async {
    if (_isBusy) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account permanently?'),
        content: const Text(
          'Deleting this account permanently will also remove all transactions and related data for this account.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingAccId = row.accId);
    try {
      await _deleteTransactionsForAccounts([row.accId]);
      final deleted = await (_db.delete(
        _db.accPersonal,
      )..where((t) => t.accId.equals(row.accId) & t.isDeleted.equals(1))).go();
      await _deleteCurrencyMappingsForAccounts([row.accId]);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deleted > 0
                ? 'Account and related data deleted forever.'
                : 'Account was already removed.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingAccId = null);
    }
  }

  Future<void> _deleteAll() async {
    if (_isBusy || _isSelectionMode) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all trashed accounts?'),
        content: const Text(
          'This will permanently clear all deleted accounts from trash.\n\nIt will also remove all transactions and related data for those accounts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingAll = true);
    try {
      final rows =
          await (_db.select(_db.accPersonal)..where(
                (t) =>
                    t.companyId.equals(widget.companyId) &
                    t.isDeleted.equals(1),
              ))
              .get();

      if (rows.isNotEmpty) {
        final accIds = rows.map((r) => r.accId).toList(growable: false);
        await _deleteTransactionsForAccounts(accIds);
        await _deleteCurrencyMappingsForAccounts(accIds);
      }

      final deleted =
          await (_db.delete(_db.accPersonal)..where(
                (t) =>
                    t.companyId.equals(widget.companyId) &
                    t.isDeleted.equals(1),
              ))
              .go();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted $deleted account(s) from trash.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear account trash: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingAll = false);
    }
  }

  Future<void> _deleteCurrencyMappingsForAccounts(List<int> accIds) async {
    if (accIds.isEmpty) return;
    for (final accId in accIds) {
      await _db.customStatement(
        'DELETE FROM Account_PCurrencyAssignment WHERE AccID = ?1',
        [accId],
      );
      await _db.customStatement(
        'DELETE FROM AccountCurrencyMap WHERE AccID = ?1 AND CompanyID = ?2',
        [accId, widget.companyId],
      );
    }
  }

  Future<void> _deleteTransactionsForAccounts(List<int> accIds) async {
    if (accIds.isEmpty) return;

    final txRows =
        await (_db.select(_db.transactionsP)..where(
              (t) =>
                  t.companyId.equals(widget.companyId) & t.accId.isIn(accIds),
            ))
            .get();

    final voucherRefs = <String>{};
    final pairLinks = <String>{};
    for (final tx in txRows) {
      voucherRefs.add(tx.voucherNo.toString());
      final hwls = (tx.hwls ?? '').trim();
      if (hwls.isNotEmpty) voucherRefs.add(hwls);
      final others = (tx.others ?? '').trim();
      if (others.isNotEmpty) pairLinks.add(others);
    }

    await (_db.delete(_db.transactionsP)..where(
          (t) => t.companyId.equals(widget.companyId) & t.accId.isIn(accIds),
        ))
        .go();

    if (voucherRefs.isNotEmpty) {
      await (_db.delete(_db.transactionsP)..where(
            (t) =>
                t.companyId.equals(widget.companyId) &
                t.hwls.isIn(voucherRefs.toList(growable: false)),
          ))
          .go();
    }

    if (pairLinks.isNotEmpty) {
      await (_db.delete(_db.transactionsP)..where(
            (t) =>
                t.companyId.equals(widget.companyId) &
                t.others.isIn(pairLinks.toList(growable: false)),
          ))
          .go();
    }
  }

  Widget _buildItem(AccPersonalData row) {
    final restoring = _restoringAccId == row.accId;
    final deleting = _deletingAccId == row.accId;
    final isSelected = _selectedAccIds.contains(row.accId);
    final name = (row.name ?? '').trim().isEmpty
        ? 'Unknown account'
        : row.name!;
    final head = (row.statusg ?? '').trim().isEmpty ? 'No head' : row.statusg!;
    final phone = (row.phone ?? '').trim();

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEFFAF1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF74C69D) : const Color(0xFFE2E8F0),
          width: isSelected ? 1.2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onLongPress: () => _toggleSelection(row.accId),
          onTap: _isSelectionMode ? () => _toggleSelection(row.accId) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_off_outlined,
                    color: Color(0xFFBE123C),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Head: $head',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          phone,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Deleted on ${_formatDate(row.updatedAt)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (_isSelectionMode)
                  Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? const Color(0xFF0A6B1D)
                        : const Color(0xFF94A3B8),
                  )
                else ...[
                  PopupMenuButton<String>(
                    enabled: !(restoring || deleting || _isBusy),
                    tooltip: 'Actions',
                    onSelected: (action) {
                      if (action == 'restore') {
                        _restore(row);
                      } else if (action == 'delete') {
                        _deleteForever(row);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem<String>(
                        value: 'restore',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.restore),
                          title: Text('Restore'),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.delete_forever_outlined,
                            color: Colors.red,
                          ),
                          title: Text('Delete Forever'),
                        ),
                      ),
                    ],
                    icon: (restoring || deleting)
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.more_vert, color: Color(0xFF334155)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = _search.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('Account Trash'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Delete all',
            onPressed: (_deletingAll || _isSelectionMode) ? null : _deleteAll,
            icon: _deletingAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_sweep_outlined, color: Colors.red),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF3),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF065F46)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Deleted accounts are kept in trash. Restore any account when needed.',
                      style: TextStyle(
                        color: Color(0xFF065F46),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search deleted accounts',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: trimmed.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
            ),
            if (_isSelectionMode)
              Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFFAF1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 520;
                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${_selectedAccIds.length} selected',
                                style: const TextStyle(
                                  color: Color(0xFF065F46),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: _isBusy
                                    ? null
                                    : () => setState(
                                        () => _selectedAccIds.clear(),
                                      ),
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  onPressed: _isBusy ? null : _restoreSelected,
                                  style: FilledButton.styleFrom(
                                    foregroundColor: AppColors.darkgreen,
                                  ),
                                  icon: _bulkRestoring
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.restore),
                                  label: const Text('Restore'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _isBusy ? null : _deleteSelected,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  icon: _bulkDeleting
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.delete_outline),
                                  label: const Text('Delete'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Text(
                          '${_selectedAccIds.length} selected',
                          style: const TextStyle(
                            color: Color(0xFF065F46),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _isBusy
                              ? null
                              : () => setState(() => _selectedAccIds.clear()),
                          child: const Text('Clear'),
                        ),
                        const SizedBox(width: 6),
                        FilledButton.tonalIcon(
                          onPressed: _isBusy ? null : _restoreSelected,
                          style: FilledButton.styleFrom(
                            foregroundColor: AppColors.darkgreen,
                          ),
                          icon: _bulkRestoring
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.restore),
                          label: const Text('Restore'),
                        ),
                        const SizedBox(width: 6),
                        FilledButton.icon(
                          onPressed: _isBusy ? null : _deleteSelected,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          icon: _bulkDeleting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.delete_outline),
                          label: const Text('Delete'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            Expanded(
              child: StreamBuilder<List<AccPersonalData>>(
                stream: _watchDeletedAccounts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final rows = snapshot.data ?? const <AccPersonalData>[];
                  if (rows.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Trash is empty. Deleted accounts will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    itemCount: rows.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _buildItem(rows[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
