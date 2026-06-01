import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/local/app_database.dart';
import '../../data/local/database_manager.dart';
import '../../model/account_head_option.dart';
import '../../model/user_model.dart';
import '../../repository/transactions_repository.dart';
import '../../services/local_storage.dart';
import '../../viewmodel/home/home_view_model.dart';
import '../../viewmodel/sync/sync_viewmodel.dart';
import '../commons/currency_flag.dart';

enum _AccountListPill { all, added }

const Color _kAccountsBlue = Color(0xFF1862A3);
const Color _kAccountsBlueDark = Color(0xFF0F4E88);
const Color _kAccountsBg = Color(0xFFF4F8FC);

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  _AccountListPill _activePill = _AccountListPill.all;
  bool _busy = false;
  bool _canCreateAccounts = true;
  final Set<int> _selectedAccountIds = <int>{};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>('');

  AppDatabase get _db => DatabaseManager.instance.db;
  TransactionsRepository get _repo => TransactionsRepository(_db);
  bool get _isSelectionMode => _selectedAccountIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadAccountCreationAccess();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadAccountCreationAccess() async {
    final user = await LocalStorageService.loadLastUsedUser();
    if (!mounted) return;
    setState(() => _canCreateAccounts = _canCreateAccountsFor(user));
  }

  bool _canCreateAccountsFor(UserModel? user) {
    final roles = (user?.roleCodes ?? const <String>[])
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

  Stream<List<AccPersonalData>> _watchAccounts(int companyId) {
    final query = _db.select(_db.accPersonal)
      ..where(
        (t) =>
            t.companyId.equals(companyId) &
            (t.isDeleted.isNull() | t.isDeleted.equals(0)),
      )
      ..orderBy([
        (t) => OrderingTerm.asc(t.name),
        (t) => OrderingTerm.asc(t.accId),
      ]);

    return query.watch();
  }

  Future<List<AccTypeData>> _loadCurrencies() {
    final query = _db.select(_db.accType)
      ..orderBy([
        (t) => OrderingTerm.asc(t.accTypeName),
        (t) => OrderingTerm.asc(t.accTypeId),
      ]);
    return query.get();
  }

  Future<List<AccountHeadOption>> _loadHeads() {
    return _repo.getAllAccountHeads();
  }

  int? _findHeadIdByNameLoose(List<AccountHeadOption> heads, String? name) {
    final target = (name ?? '').trim().toLowerCase();
    if (target.isEmpty) return null;
    for (final head in heads) {
      if (head.accHeadName.trim().toLowerCase() == target) {
        return head.accHeadId;
      }
    }
    return null;
  }

  bool _matchesSearch(AccPersonalData row, String searchQuery) {
    final q = searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;

    final name = (row.name ?? '').toLowerCase();
    final status = (row.statusg ?? '').toLowerCase();
    final phone = (row.phone ?? '').toLowerCase();
    final id = row.accId.toString();

    return name.contains(q) ||
        status.contains(q) ||
        phone.contains(q) ||
        id.contains(q);
  }

  bool _isAddedAccount(AccPersonalData row) {
    final source = (row.wName ?? '').trim();
    if (source.isEmpty) return false;
    final normalized = source.toUpperCase();
    return normalized == 'MOBILE' || source.contains('@');
  }

  String _ownerLabel(AccPersonalData row) {
    final raw = (row.wName ?? '').trim();
    if (raw.isEmpty) return '';
    if (raw.toUpperCase() == 'MOBILE') return '';
    return raw;
  }

  bool _matchesActivePill(AccPersonalData row) {
    if (_activePill == _AccountListPill.all) return true;
    return _isAddedAccount(row);
  }

  Future<void> _logAccountsRefreshSnapshot(
    String stage,
    int companyId, {
    String? companyName,
  }) async {
    try {
      final companies = await _db.customSelect('''
        SELECT CompanyID, CompanyName
        FROM Company
        ORDER BY CompanyID ASC
        ''').get();
      final companyRows = companies
          .map(
            (row) =>
                '${row.data['CompanyID']}:${row.data['CompanyName'] ?? '(null)'}',
          )
          .join(', ');

      final accounts = await _db
          .customSelect(
            '''
        SELECT AccID, Name
        FROM Acc_Personal
        WHERE CompanyID = ?1
          AND COALESCE(IsDeleted, 0) = 0
        ORDER BY AccID ASC
        LIMIT 12
        ''',
            variables: [Variable.withInt(companyId)],
          )
          .get();
      final accountRows = accounts
          .map((row) => '${row.data['AccID']}:${row.data['Name'] ?? '(null)'}')
          .join(', ');

      debugPrint(
        "🏢 [ACCOUNTS_DEBUG] $stage company=$companyId:${companyName ?? '(unknown)'} "
        "companies=[${companyRows.isEmpty ? '(empty)' : companyRows}] "
        "accounts=[${accountRows.isEmpty ? '(empty)' : accountRows}]",
      );
    } catch (e) {
      debugPrint("⚠️ [ACCOUNTS_DEBUG] failed to log $stage snapshot: $e");
    }
  }

  Future<Set<int>> _selectedCurrencyIds(int accId, int companyId) async {
    final rows = await _db
        .customSelect(
          '''
          SELECT AccTypeID
          FROM AccountCurrencyMap
          WHERE AccID = ?1
            AND CompanyID = ?2
            AND COALESCE(IsEnabled, 1) = 1
          ORDER BY AccTypeID
          ''',
          variables: [Variable.withInt(accId), Variable.withInt(companyId)],
        )
        .get();

    return rows
        .map((r) => int.tryParse((r.data['AccTypeID'] ?? '').toString()) ?? 0)
        .where((id) => id > 0)
        .toSet();
  }

  Future<bool> _accountNameExists(
    int companyId,
    String name, {
    int? excludeAccId,
  }) async {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    if (excludeAccId == null) {
      final rows = await _db
          .customSelect(
            '''
            SELECT 1
            FROM Acc_Personal
            WHERE CompanyID = ?1
              AND LOWER(TRIM(COALESCE(Name, ''))) = ?2
              AND COALESCE(IsDeleted, 0) = 0
            LIMIT 1
            ''',
            variables: [
              Variable.withInt(companyId),
              Variable.withString(normalized),
            ],
          )
          .get();
      return rows.isNotEmpty;
    }

    final rows = await _db
        .customSelect(
          '''
          SELECT 1
          FROM Acc_Personal
          WHERE CompanyID = ?1
            AND AccID <> ?2
            AND LOWER(TRIM(COALESCE(Name, ''))) = ?3
            AND COALESCE(IsDeleted, 0) = 0
          LIMIT 1
          ''',
          variables: [
            Variable.withInt(companyId),
            Variable.withInt(excludeAccId),
            Variable.withString(normalized),
          ],
        )
        .get();
    return rows.isNotEmpty;
  }

  Future<void> _saveCurrencySelections({
    required int accId,
    required int companyId,
    required List<AccTypeData> allCurrencies,
    required Set<int> selected,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final selectedSorted = selected.where((id) => id > 0).toList()..sort();

    await _db.transaction(() async {
      // Soft-delete previous assignment rows so deletes can be synced.
      await _db.customStatement(
        '''
        UPDATE Account_PCurrencyAssignment
        SET IsDeleted = 1,
            IsSynced = 0,
            UpdatedAt = ?1,
            CompanyID = COALESCE(CompanyID, ?2)
        WHERE AccID = ?3
        ''',
        [now, companyId, accId],
      );

      for (final accTypeId in selectedSorted) {
        final existing = await _db
            .customSelect(
              '''
              SELECT RegID
              FROM Account_PCurrencyAssignment
              WHERE AccID = ?1
                AND AccountTypeID = ?2
              ORDER BY RegID DESC
              LIMIT 1
              ''',
              variables: [Variable.withInt(accId), Variable.withInt(accTypeId)],
            )
            .get();

        if (existing.isNotEmpty) {
          final regId =
              int.tryParse((existing.first.data['RegID'] ?? '0').toString()) ??
              0;
          if (regId > 0) {
            await _db.customStatement(
              '''
              UPDATE Account_PCurrencyAssignment
              SET IsDeleted = 0,
                  IsSynced = 0,
                  UpdatedAt = ?1,
                  CompanyID = ?2,
                  AccID = ?3,
                  AccountTypeID = ?4
              WHERE RegID = ?5
              ''',
              [now, companyId, accId, accTypeId, regId],
            );
            continue;
          }
        }

        final regId = await _repo.getNextCurrencyAssignmentRegId();
        await _db.customStatement(
          '''
          INSERT INTO Account_PCurrencyAssignment
            (RegID, AccID, AccountTypeID, CompanyID, IsDeleted, IsSynced, UpdatedAt)
          VALUES (?1, ?2, ?3, ?4, 0, 0, ?5)
          ''',
          [regId, accId, accTypeId, companyId, now],
        );
      }

      for (final cur in allCurrencies) {
        final accTypeId = cur.accTypeId;
        await _db.customStatement(
          '''
          INSERT OR REPLACE INTO AccountCurrencyMap
            (AccID, AccTypeID, CompanyID, IsEnabled, UpdatedAt)
          VALUES (?1, ?2, ?3, ?4, ?5)
          ''',
          [
            accId,
            accTypeId,
            companyId,
            selected.contains(accTypeId) ? 1 : 0,
            now,
          ],
        );
      }
    });
  }

  void _triggerBackgroundAssignmentSync() {
    unawaited(() async {
      try {
        await context.read<SyncViewModel>().syncNowSingleFlight(silent: true);
      } catch (_) {
        // Best effort only.
      }
    }());
  }

  Future<void> _addAccount(int companyId) async {
    if (_busy) return;
    if (!_canCreateAccounts) {
      _showReadOnlyAccountsMessage();
      return;
    }

    final currencies = await _loadCurrencies();
    final heads = await _loadHeads();
    if (!mounted) return;
    if (currencies.isEmpty) {
      _showMessage('No currencies found in AccType.', error: true);
      return;
    }
    if (heads.isEmpty) {
      _showMessage(
        'No heads found. Please add a head first from Heads menu.',
        error: true,
      );
      return;
    }

    final result = await showModalBottomSheet<_AccountEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountEditorSheet(
        title: 'Add Account',
        heads: heads,
        currencies: currencies,
        initialSelectedHeadId: heads.first.accHeadId,
        initialSelectedCurrencyIds: currencies.map((c) => c.accTypeId).toSet(),
      ),
    );

    if (result == null) return;

    if (await _accountNameExists(companyId, result.name)) {
      _showMessage('Account name already exists in this company.', error: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final nextId = await _repo.getNextAccId();
      final now = DateTime.now().toIso8601String();
      final currentUser = await LocalStorageService.loadLastUsedUser();
      final creatorUserId = int.tryParse(currentUser?.id.trim() ?? '');
      final creatorEmail = currentUser?.email.trim() ?? '';
      final normalizedHead = _repo.normalizeHeadNameForAccount(
        accountName: result.name,
        requestedHeadName: result.selectedHeadName,
      );

      await _db
          .into(_db.accPersonal)
          .insert(
            AccPersonalCompanion(
              accId: Value(nextId),
              rDate: Value(now),
              name: Value(result.name.trim()),
              phone: Value(
                result.phone.trim().isEmpty ? null : result.phone.trim(),
              ),
              statusg: Value(normalizedHead),
              chartOfAccountId: Value(result.selectedHeadId),
              companyId: Value(companyId),
              userId: Value(
                creatorUserId != null && creatorUserId > 0
                    ? creatorUserId
                    : null,
              ),
              wName: Value(creatorEmail.isEmpty ? 'MOBILE' : creatorEmail),
              isSynced: const Value(0),
              updatedAt: Value(now),
              isDeleted: const Value(0),
            ),
          );

      await _saveCurrencySelections(
        accId: nextId,
        companyId: companyId,
        allCurrencies: currencies,
        selected: result.selectedCurrencyIds,
      );
      _triggerBackgroundAssignmentSync();

      _showMessage('Account added successfully.');
    } catch (e) {
      _showMessage('Failed to add account: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editAccount(AccPersonalData row, int companyId) async {
    if (_busy) return;
    if (!_canCreateAccounts) {
      _showReadOnlyAccountsMessage();
      return;
    }

    final currencies = await _loadCurrencies();
    final heads = await _loadHeads();
    if (!mounted) return;
    if (currencies.isEmpty) {
      _showMessage('No currencies found in AccType.', error: true);
      return;
    }
    if (heads.isEmpty) {
      _showMessage(
        'No heads found. Please add a head first from Heads menu.',
        error: true,
      );
      return;
    }

    final selected = await _selectedCurrencyIds(row.accId, companyId);
    if (!mounted) return;

    final result = await showModalBottomSheet<_AccountEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountEditorSheet(
        title: 'Edit Account',
        heads: heads,
        currencies: currencies,
        initialName: row.name ?? '',
        initialSelectedHeadId:
            row.chartOfAccountId ?? _findHeadIdByNameLoose(heads, row.statusg),
        initialPhone: row.phone ?? '',
        initialSelectedCurrencyIds: selected,
      ),
    );

    if (result == null) return;

    if (await _accountNameExists(
      companyId,
      result.name,
      excludeAccId: row.accId,
    )) {
      _showMessage('Account name already exists in this company.', error: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final now = DateTime.now().toIso8601String();
      final normalizedHead = _repo.normalizeHeadNameForAccount(
        accountName: result.name,
        requestedHeadName: result.selectedHeadName,
      );

      await (_db.update(
        _db.accPersonal,
      )..where((t) => t.accId.equals(row.accId))).write(
        AccPersonalCompanion(
          name: Value(result.name.trim()),
          phone: Value(
            result.phone.trim().isEmpty ? null : result.phone.trim(),
          ),
          statusg: Value(normalizedHead),
          chartOfAccountId: Value(result.selectedHeadId),
          updatedAt: Value(now),
          isSynced: const Value(0),
        ),
      );

      await _saveCurrencySelections(
        accId: row.accId,
        companyId: companyId,
        allCurrencies: currencies,
        selected: result.selectedCurrencyIds,
      );
      _triggerBackgroundAssignmentSync();

      _showMessage('Account updated successfully.');
    } catch (e) {
      _showMessage('Failed to update account: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount(AccPersonalData row, int companyId) async {
    if (_busy) return;
    if (!_canCreateAccounts) {
      _showReadOnlyAccountsMessage();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text(
          "Delete '${(row.name ?? '').trim().isEmpty ? 'this account' : row.name}'?",
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

    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await _repo.setAccountTransactionsDeletedState(
        companyId: companyId,
        accIds: [row.accId],
        isDeleted: true,
      );

      await (_db.update(
        _db.accPersonal,
      )..where((t) => t.accId.equals(row.accId))).write(
        AccPersonalCompanion(
          isDeleted: const Value(1),
          isSynced: const Value(0),
          updatedAt: Value(DateTime.now().toIso8601String()),
        ),
      );
      _selectedAccountIds.remove(row.accId);

      _showMessage('Account deleted.');
    } catch (e) {
      _showMessage('Failed to delete account: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleAccountSelection(int accId) {
    if (!_canCreateAccounts) return;
    setState(() {
      if (_selectedAccountIds.contains(accId)) {
        _selectedAccountIds.remove(accId);
      } else {
        _selectedAccountIds.add(accId);
      }
    });
  }

  Future<void> _deleteSelectedAccounts(int companyId) async {
    if (_selectedAccountIds.isEmpty || _busy) return;
    if (!_canCreateAccounts) {
      _showReadOnlyAccountsMessage();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete selected accounts?'),
        content: Text(
          "Move ${_selectedAccountIds.length} selected account(s) to Trash?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Selected'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final now = DateTime.now().toIso8601String();
      final selectedIds = _selectedAccountIds.toList(growable: false);

      await _repo.setAccountTransactionsDeletedState(
        companyId: companyId,
        accIds: selectedIds,
        isDeleted: true,
      );

      await (_db.update(_db.accPersonal)..where(
            (t) => t.companyId.equals(companyId) & t.accId.isIn(selectedIds),
          ))
          .write(
            AccPersonalCompanion(
              isDeleted: const Value(1),
              isSynced: const Value(0),
              updatedAt: Value(now),
            ),
          );

      setState(() => _selectedAccountIds.clear());
      _showMessage('${selectedIds.length} account(s) moved to Trash.');
    } catch (e) {
      _showMessage('Failed to delete selected accounts: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red : _kAccountsBlueDark,
      ),
    );
  }

  void _showReadOnlyAccountsMessage() {
    _showMessage('Viewer role has read-only access to accounts', error: true);
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final single = parts.first;
      return single.length >= 2
          ? single.substring(0, 2).toUpperCase()
          : single.toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
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

  Color _statusBackground(String status) {
    final normalized = status.trim().toUpperCase();
    if (normalized == 'SUPPLIER') return const Color(0xFFFFF4E5);
    if (normalized == 'CUSTOMER') return const Color(0xFFEFF6FF);
    return const Color(0xFFF1F5F9);
  }

  Color _statusForeground(String status) {
    final normalized = status.trim().toUpperCase();
    if (normalized == 'SUPPLIER') return const Color(0xFF9A3412);
    if (normalized == 'CUSTOMER') return const Color(0xFF1D4ED8);
    return const Color(0xFF334155);
  }

  Widget _buildAccountCard({
    required AccPersonalData row,
    required int companyId,
    required bool isSelected,
  }) {
    final name = (row.name ?? '').trim();
    final statusRaw = (row.statusg ?? '').trim();
    final status = statusRaw.isEmpty ? 'CUSTOMER' : statusRaw.toUpperCase();
    final phone = (row.phone ?? '').trim();
    final updated = _formatDate(row.updatedAt);
    final ownerLabel = _ownerLabel(row);
    final cardBorderWidth = isSelected ? 1.3 : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? const Color(0xFF60A5FA) : const Color(0xFFDCE7F8),
          width: cardBorderWidth,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            InkWell(
              onTap: () {
                if (_isSelectionMode) {
                  _toggleAccountSelection(row.accId);
                  return;
                }
                if (!_canCreateAccounts) return;
                _editAccount(row, companyId);
              },
              onLongPress: _canCreateAccounts
                  ? () => _toggleAccountSelection(row.accId)
                  : null,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _initials(name.isEmpty ? 'Unknown' : name),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? 'Unknown Account' : name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
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
                                  color: _statusBackground(status),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _statusForeground(status),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (phone.isNotEmpty)
                            Row(
                              children: [
                                const Icon(
                                  Icons.phone_outlined,
                                  size: 14,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  phone,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF475569),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          if (phone.isNotEmpty) const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule_outlined,
                                size: 14,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Updated $updated',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_isSelectionMode)
                      Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? _kAccountsBlue
                            : const Color(0xFF94A3B8),
                      )
                    else if (_canCreateAccounts) ...[
                      PopupMenuButton<String>(
                        enabled: !_busy,
                        tooltip: 'Actions',
                        icon: const Icon(
                          Icons.more_vert,
                          color: Color(0xFF334155),
                        ),
                        onSelected: (action) {
                          if (action == 'edit') {
                            _editAccount(row, companyId);
                          } else if (action == 'delete') {
                            _deleteAccount(row, companyId);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Edit'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              title: Text('Delete'),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: 'Delete account',
                        onPressed: _busy
                            ? null
                            : () => _deleteAccount(row, companyId),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (ownerLabel.isNotEmpty)
              Positioned(
                top: 0,
                right: 0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4F7),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(8),
                      ),
                      border: Border(
                        left: BorderSide(
                          color: const Color(0xFFD1D5DB),
                          width: cardBorderWidth,
                        ),
                        bottom: BorderSide(
                          color: const Color(0xFFD1D5DB),
                          width: cardBorderWidth,
                        ),
                      ),
                    ),
                    child: Text(
                      ownerLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final companyId = context.select<HomeViewModel, int?>(
      (vm) => vm.selectedCompanyId,
    );
    final companyName =
        (context.select<HomeViewModel, String?>(
                  (vm) => vm.selectedCompanyName,
                ) ??
                'Selected Company')
            .trim();

    if (companyId == null) {
      return const Center(child: Text('Please select a company first.'));
    }

    return Scaffold(
      backgroundColor: _kAccountsBg,
      floatingActionButton: _isSelectionMode || !_canCreateAccounts
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : () => _addAccount(companyId),
              backgroundColor: _kAccountsBlue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add Account'),
            ),
      body: Stack(
        children: [
          const _AccountsBackdrop(),
          SafeArea(
            child: StreamBuilder<List<AccPersonalData>>(
              stream: _watchAccounts(companyId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allRows = snapshot.data ?? const <AccPersonalData>[];
                final addedCount = allRows.where(_isAddedAccount).length;

                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_kAccountsBlue, _kAccountsBlueDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x261862A3),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.groups_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  companyName.isEmpty
                                      ? 'Company #$companyId'
                                      : companyName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Accounts',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${allRows.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Text(
                                  'Total',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                      child: ValueListenableBuilder<String>(
                        valueListenable: _searchQueryNotifier,
                        builder: (context, searchQuery, _) => TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: (value) =>
                              _searchQueryNotifier.value = value,
                          decoration: InputDecoration(
                            hintText: 'Search by name, status, phone or ID',
                            prefixIcon: const Icon(
                              Icons.search,
                              color: _kAccountsBlue,
                            ),
                            suffixIcon: searchQuery.trim().isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      _searchQueryNotifier.value = '';
                                      if (!_searchFocusNode.hasFocus) {
                                        _searchFocusNode.requestFocus();
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.close,
                                      color: _kAccountsBlue,
                                    ),
                                  ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFFDCE7F8),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: _kAccountsBlue,
                                width: 1.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    ValueListenableBuilder<String>(
                      valueListenable: _searchQueryNotifier,
                      builder: (context, searchQuery, _) {
                        final rows = allRows
                            .where(_matchesActivePill)
                            .where((row) => _matchesSearch(row, searchQuery))
                            .toList();
                        final emptyMessage = searchQuery.trim().isNotEmpty
                            ? 'No account found for this search.'
                            : _activePill == _AccountListPill.added
                            ? 'No accounts added from app yet.'
                            : 'No accounts for this company yet.';

                        return Expanded(
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  2,
                                  14,
                                  6,
                                ),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ChoiceChip(
                                      label: Text('All (${allRows.length})'),
                                      selected:
                                          _activePill == _AccountListPill.all,
                                      selectedColor: const Color(0xFFE9F3FF),
                                      backgroundColor: Colors.white,
                                      side: const BorderSide(
                                        color: Color(0xFFDCE7F8),
                                      ),
                                      labelStyle: TextStyle(
                                        color:
                                            _activePill == _AccountListPill.all
                                            ? _kAccountsBlue
                                            : const Color(0xFF475569),
                                        fontWeight: FontWeight.w700,
                                      ),
                                      onSelected: (_) {
                                        setState(() {
                                          _activePill = _AccountListPill.all;
                                          _selectedAccountIds.clear();
                                        });
                                      },
                                    ),
                                    ChoiceChip(
                                      label: Text(
                                        'Added Accounts ($addedCount)',
                                      ),
                                      selected:
                                          _activePill == _AccountListPill.added,
                                      selectedColor: const Color(0xFFE9F3FF),
                                      backgroundColor: Colors.white,
                                      side: const BorderSide(
                                        color: Color(0xFFDCE7F8),
                                      ),
                                      labelStyle: TextStyle(
                                        color:
                                            _activePill ==
                                                _AccountListPill.added
                                            ? _kAccountsBlue
                                            : const Color(0xFF475569),
                                        fontWeight: FontWeight.w700,
                                      ),
                                      onSelected: (_) {
                                        setState(() {
                                          _activePill = _AccountListPill.added;
                                          _selectedAccountIds.clear();
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  4,
                                  14,
                                  6,
                                ),
                                child: Row(
                                  children: [
                                    const Text(
                                      'Account List',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _AccountMetaChip(
                                      icon: Icons.manage_search_rounded,
                                      label: '${rows.length} shown',
                                    ),
                                    if (_isSelectionMode) ...[
                                      const Spacer(),
                                      TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => setState(
                                                () =>
                                                    _selectedAccountIds.clear(),
                                              ),
                                        child: const Text('Clear'),
                                      ),
                                      const SizedBox(width: 4),
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        onPressed: _busy
                                            ? null
                                            : () => _deleteSelectedAccounts(
                                                companyId,
                                              ),
                                        icon: _busy
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(Icons.delete_outline),
                                        label: Text(
                                          'Delete (${_selectedAccountIds.length})',
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Expanded(
                                child: RefreshIndicator(
                                  color: _kAccountsBlue,
                                  onRefresh: () async {
                                    await _logAccountsRefreshSnapshot(
                                      'before-refresh',
                                      companyId,
                                      companyName: companyName,
                                    );
                                    await context
                                        .read<SyncViewModel>()
                                        .syncNowSingleFlight(silent: true);
                                    await _logAccountsRefreshSnapshot(
                                      'after-refresh',
                                      companyId,
                                      companyName: companyName,
                                    );
                                  },
                                  child: rows.isEmpty
                                      ? ListView(
                                          physics:
                                              const AlwaysScrollableScrollPhysics(),
                                          padding: const EdgeInsets.fromLTRB(
                                            14,
                                            24,
                                            14,
                                            96,
                                          ),
                                          children: [
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                minHeight: 280,
                                              ),
                                              child: Center(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 64,
                                                      height: 64,
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFE2E8F0,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              18,
                                                            ),
                                                      ),
                                                      child: const Icon(
                                                        Icons
                                                            .account_balance_wallet_outlined,
                                                        color: Color(
                                                          0xFF475569,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 14),
                                                    Text(
                                                      emptyMessage,
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFF475569,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    if (searchQuery
                                                        .trim()
                                                        .isEmpty)
                                                      FilledButton.icon(
                                                        onPressed:
                                                            _busy ||
                                                                !_canCreateAccounts
                                                            ? null
                                                            : () => _addAccount(
                                                                companyId,
                                                              ),
                                                        style:
                                                            FilledButton.styleFrom(
                                                              backgroundColor:
                                                                  _kAccountsBlue,
                                                              foregroundColor:
                                                                  Colors.white,
                                                            ),
                                                        icon: const Icon(
                                                          Icons
                                                              .person_add_alt_1,
                                                        ),
                                                        label: const Text(
                                                          'Create First Account',
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : ListView.separated(
                                          physics:
                                              const AlwaysScrollableScrollPhysics(),
                                          padding: const EdgeInsets.fromLTRB(
                                            14,
                                            0,
                                            14,
                                            96,
                                          ),
                                          itemCount: rows.length,
                                          separatorBuilder: (_, index) =>
                                              const SizedBox(height: 10),
                                          itemBuilder: (context, index) =>
                                              _buildAccountCard(
                                                row: rows[index],
                                                companyId: companyId,
                                                isSelected: _selectedAccountIds
                                                    .contains(
                                                      rows[index].accId,
                                                    ),
                                              ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountEditorResult {
  final String name;
  final int selectedHeadId;
  final String selectedHeadName;
  final String phone;
  final Set<int> selectedCurrencyIds;

  const _AccountEditorResult({
    required this.name,
    required this.selectedHeadId,
    required this.selectedHeadName,
    required this.phone,
    required this.selectedCurrencyIds,
  });
}

class _AccountEditorSheet extends StatefulWidget {
  final String title;
  final List<AccountHeadOption> heads;
  final List<AccTypeData> currencies;
  final String initialName;
  final int? initialSelectedHeadId;
  final String initialPhone;
  final Set<int> initialSelectedCurrencyIds;

  const _AccountEditorSheet({
    required this.title,
    required this.heads,
    required this.currencies,
    required this.initialSelectedCurrencyIds,
    this.initialName = '',
    this.initialSelectedHeadId,
    this.initialPhone = '',
  });

  @override
  State<_AccountEditorSheet> createState() => _AccountEditorSheetState();
}

class _AccountEditorSheetState extends State<_AccountEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final TextEditingController _currencySearchController =
      TextEditingController();
  int? _selectedHeadId;
  late Set<int> _selectedCurrencyIds;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _selectedHeadId = widget.initialSelectedHeadId;
    _selectedCurrencyIds = Set<int>.from(widget.initialSelectedCurrencyIds);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _currencySearchController.dispose();
    super.dispose();
  }

  void _toggleAll(bool selectAll) {
    setState(() {
      _selectedCurrencyIds = selectAll
          ? widget.currencies.map((c) => c.accTypeId).toSet()
          : <int>{};
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedHeadId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select account head.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedCurrencyIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one currency.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final selectedHead = widget.heads.where(
      (h) => h.accHeadId == _selectedHeadId,
    );
    if (selectedHead.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected head not found. Please select again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _AccountEditorResult(
        name: _nameController.text.trim(),
        selectedHeadId: _selectedHeadId!,
        selectedHeadName: selectedHead.first.accHeadName,
        phone: _phoneController.text.trim(),
        selectedCurrencyIds: _selectedCurrencyIds,
      ),
    );
  }

  void _toggleCurrency(int id) {
    setState(() {
      if (_selectedCurrencyIds.contains(id)) {
        _selectedCurrencyIds.remove(id);
      } else {
        _selectedCurrencyIds.add(id);
      }
    });
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD9E2EC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD9E2EC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kAccountsBlue, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final query = _currencySearchController.text.trim().toLowerCase();
    final filteredCurrencies = widget.currencies
        .where((currency) {
          if (query.isEmpty) return true;
          final name = (currency.accTypeName ?? '').toLowerCase();
          final altName = (currency.accTypeNameU ?? '').toLowerCase();
          final id = currency.accTypeId.toString();
          return name.contains(query) ||
              altName.contains(query) ||
              id.contains(query);
        })
        .toList(growable: false);

    return Container(
      decoration: const BoxDecoration(
        color: _kAccountsBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(14, 10, 14, inset + safeBottom + 14),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFBFD7F3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: _kAccountsBlue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${_selectedCurrencyIds.length} currencies selected',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          DropdownButtonFormField<int>(
                            initialValue: _selectedHeadId,
                            decoration: _fieldDecoration(
                              label: 'Account Head',
                              hint: 'Select account head',
                              icon: Icons.account_tree_outlined,
                            ),
                            items: widget.heads
                                .map(
                                  (h) => DropdownMenuItem<int>(
                                    value: h.accHeadId,
                                    child: Text(
                                      h.accHeadName,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) =>
                                setState(() => _selectedHeadId = value),
                            validator: (value) {
                              if (value == null) {
                                return 'Please select account head.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            decoration: _fieldDecoration(
                              label: 'Account Name',
                              hint: 'Enter account name',
                              icon: Icons.person_outline,
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Account name is required.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _phoneController,
                            textInputAction: TextInputAction.done,
                            keyboardType: TextInputType.phone,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: _fieldDecoration(
                              label: 'Phone (optional)',
                              hint: '03xx xxxxxxx',
                              icon: Icons.phone_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
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
                              const Text(
                                'Assign Currencies',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () => _toggleAll(true),
                                child: const Text(
                                  'Select all',
                                  style: TextStyle(color: _kAccountsBlue),
                                ),
                              ),
                              TextButton(
                                onPressed: () => _toggleAll(false),
                                child: const Text(
                                  'Clear',
                                  style: TextStyle(color: _kAccountsBlue),
                                ),
                              ),
                            ],
                          ),
                          TextField(
                            controller: _currencySearchController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Search currencies',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon:
                                  _currencySearchController.text.trim().isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _currencySearchController.clear();
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.close),
                                    ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            height: screenHeight < 740 ? 220 : 280,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: filteredCurrencies.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No currency found.',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: filteredCurrencies.length,
                                    itemBuilder: (context, index) {
                                      final currency =
                                          filteredCurrencies[index];
                                      final id = currency.accTypeId;
                                      final label = (currency.accTypeName ?? '')
                                          .trim();
                                      final localizedName =
                                          (currency.accTypeNameU ?? '').trim();
                                      final selected = _selectedCurrencyIds
                                          .contains(id);

                                      return CheckboxListTile(
                                        value: selected,
                                        onChanged: (_) => _toggleCurrency(id),
                                        controlAffinity:
                                            ListTileControlAffinity.trailing,
                                        activeColor: _kAccountsBlue,
                                        secondary: CurrencyFlagBadge(
                                          currency: label,
                                          size: 24,
                                          flagField: currency.flag,
                                        ),
                                        title: Text(
                                          label.isEmpty
                                              ? 'Currency #$id'
                                              : label,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        subtitle:
                                            localizedName.isNotEmpty &&
                                                localizedName.toLowerCase() !=
                                                    label.toLowerCase()
                                            ? Text(
                                                localizedName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              )
                                            : null,
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check),
                    label: const Text('Save Account'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kAccountsBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AccountMetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE7F8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF475569)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountsBackdrop extends StatelessWidget {
  const _AccountsBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: _kAccountsBg),
        Positioned(
          top: -90,
          right: -80,
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
          top: 180,
          left: -90,
          child: Container(
            width: 180,
            height: 180,
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
