import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/local/database_manager.dart';
import '../../model/account_head_option.dart';
import '../../repository/transactions_repository.dart';
import '../../viewmodel/profile/profile_view_model.dart';
import '../../viewmodel/sync/sync_viewmodel.dart';

const Color _kChartBlue = Color(0xFF1862A3);
const Color _kChartBlueDark = Color(0xFF0D4F88);
const Color _kChartBg = Color(0xFFF3F7FC);

class ChartOfAccountsScreen extends StatefulWidget {
  const ChartOfAccountsScreen({super.key});

  @override
  State<ChartOfAccountsScreen> createState() => _ChartOfAccountsScreenState();
}

class _ChartOfAccountsScreenState extends State<ChartOfAccountsScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabController;

  bool _busy = false;
  bool _chartSyncing = false;
  int _activeTabIndex = 0;
  String _searchQuery = '';
  String _chartSyncMessage = '';
  List<AccountHeadListRow> _headRows = const [];
  List<AccountSubHeadListRow> _subHeadRows = const [];
  List<AccountHeadOption> _chartRows = const [];

  TransactionsRepository get _repo =>
      TransactionsRepository(DatabaseManager.instance.db);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    final nextIndex = _tabController.index;
    if (_activeTabIndex == nextIndex) return;
    if (!mounted) return;
    setState(() => _activeTabIndex = nextIndex);
  }

  Future<void> _loadAll() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final results = await Future.wait([
        _repo.getAccountHeadRows(),
        _repo.getAccountSubHeadRows(),
        _repo.getAllAccountHeads(),
      ]);
      if (!mounted) return;
      setState(() {
        _headRows = results[0] as List<AccountHeadListRow>;
        _subHeadRows = results[1] as List<AccountSubHeadListRow>;
        _chartRows = results[2] as List<AccountHeadOption>;
      });
    } catch (e) {
      _showMessage('Failed to load chart of accounts: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? const Color(0xFFB3261E) : _kChartBlue,
        content: Text(text),
      ),
    );
  }

  Future<int> _countPendingChartSyncRows() async {
    final row = await DatabaseManager.instance.db.customSelect('''
      SELECT
        (SELECT COUNT(*) FROM AccountHeads WHERE COALESCE(IsSynced, 0) = 0) +
        (SELECT COUNT(*) FROM AccountSubHeads WHERE COALESCE(IsSynced, 0) = 0) +
        (SELECT COUNT(*) FROM ChartOfAccounts WHERE COALESCE(IsSynced, 0) = 0)
          AS pending_count
      ''').getSingle();
    return int.tryParse('${row.data['pending_count'] ?? 0}') ?? 0;
  }

  Future<void> _syncChartChangesNow() async {
    if (!mounted) return;
    late final SyncViewModel syncVM;
    try {
      syncVM = context.read<SyncViewModel>();
    } on ProviderNotFoundException {
      _showMessage(
        'Saved locally. Sync is not available on this screen.',
        error: true,
      );
      return;
    }

    if (!syncVM.canSync) {
      _showMessage(
        'Saved locally. Sync is disabled until database import/package status is ready.',
        error: true,
      );
      return;
    }

    setState(() {
      _chartSyncing = true;
      _chartSyncMessage = 'Uploading chart changes to server...';
    });

    try {
      await syncVM.syncNowIfNeededSingleFlight(force: true, silent: false);
      if (!mounted) return;

      final pending = await _countPendingChartSyncRows();
      if (!mounted) return;

      if (pending == 0) {
        _showMessage('Chart changes uploaded to server.');
      } else {
        _showMessage(
          'Saved locally. $pending chart change${pending == 1 ? '' : 's'} still pending upload.',
          error: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        'Saved locally, but upload failed: ${_friendlyError(e)}',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _chartSyncing = false;
          _chartSyncMessage = '';
        });
      }
    }
  }

  String get _query => _searchQuery.trim().toLowerCase();

  bool _containsQuery(List<String> values) {
    if (_query.isEmpty) return true;
    return values.any((value) => value.toLowerCase().contains(_query));
  }

  List<AccountHeadListRow> get _filteredHeads => _headRows
      .where(
        (row) => _containsQuery([
          row.accountHeadId.toString(),
          row.accountHeadName,
          row.normalBalance,
        ]),
      )
      .toList(growable: false);

  List<AccountSubHeadListRow> get _filteredSubHeads => _subHeadRows
      .where(
        (row) => _containsQuery([
          row.accountSubHeadId.toString(),
          row.accountHeadId.toString(),
          row.code,
          row.accountSubHeadName,
          row.accountHeadName,
        ]),
      )
      .toList(growable: false);

  List<AccountHeadOption> get _filteredCharts => _chartRows
      .where(
        (row) => _containsQuery([
          row.accHeadId.toString(),
          row.accHeadName,
          row.accountHeadId?.toString() ?? '',
          row.accountHeadName ?? '',
          row.accountSubHeadId?.toString() ?? '',
          row.accountSubHeadCode ?? '',
          row.accountSubHeadName ?? '',
          row.chartCode ?? '',
        ]),
      )
      .toList(growable: false);

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  String _label(String? value, {required String fallback}) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String _initials(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final word = words.first;
      return word.length >= 2
          ? word.substring(0, 2).toUpperCase()
          : word.toUpperCase();
    }
    return (words.first[0] + words.last[0]).toUpperCase();
  }

  List<AccountSubHeadListRow> _subHeadsForHead(int accountHeadId) =>
      _subHeadRows
          .where((row) => row.accountHeadId == accountHeadId)
          .toList(growable: false);

  String _friendlyError(Object error) {
    final text = error.toString();
    const prefix = 'Invalid argument(s): ';
    return text.startsWith(prefix) ? text.substring(prefix.length) : text;
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _kChartBlue),
      filled: true,
      fillColor: const Color(0xFFF8FBFF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDDECF8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDDECF8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _kChartBlue, width: 1.4),
      ),
    );
  }

  bool _ensureCanEditChart() {
    final profileVM = context.read<ProfileViewModel>();
    if (profileVM.isSubscriptionExpired) {
      _showMessage(
        'Your package has expired. Renew from Profile to edit chart records.',
        error: true,
      );
      return false;
    }
    if (!profileVM.canUseDatabase) {
      _showMessage(
        'Import a local database before editing chart records.',
        error: true,
      );
      return false;
    }
    return true;
  }

  Future<void> _openSubHeadEditor({AccountSubHeadListRow? existing}) async {
    if (!_ensureCanEditChart()) return;
    if (_headRows.isEmpty) {
      _showMessage(
        'Account heads are required before adding sub heads.',
        error: true,
      );
      return;
    }

    var selectedHeadId =
        existing?.accountHeadId ?? _headRows.first.accountHeadId;
    if (!_headRows.any((row) => row.accountHeadId == selectedHeadId)) {
      selectedHeadId = _headRows.first.accountHeadId;
    }

    final initialCode = (existing?.code.trim().isNotEmpty ?? false)
        ? existing!.code
        : await _repo.getNextAccountSubHeadCode(
            accountHeadId: selectedHeadId,
            excludingAccountSubHeadId: existing?.accountSubHeadId,
          );
    final formKey = GlobalKey<FormState>();
    final codeController = TextEditingController(text: initialCode);
    final nameController = TextEditingController(
      text: existing?.accountSubHeadName ?? '',
    );
    var saving = false;
    var sheetActive = true;

    if (!mounted) {
      codeController.dispose();
      nameController.dispose();
      return;
    }

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) {
          return ScaffoldMessenger(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: StatefulBuilder(
                builder: (sheetContext, setSheetState) {
                  void showSheetMessage(String text, {bool error = false}) {
                    if (!sheetContext.mounted) return;
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: error
                            ? const Color(0xFFB3261E)
                            : _kChartBlue,
                        content: Text(text),
                      ),
                    );
                  }

                  Future<void> save() async {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    setSheetState(() => saving = true);
                    try {
                      if (existing == null) {
                        await _repo.createAccountSubHead(
                          accountHeadId: selectedHeadId,
                          accountSubHeadName: nameController.text,
                          code: codeController.text,
                        );
                      } else {
                        await _repo.updateAccountSubHead(
                          accountSubHeadId: existing.accountSubHeadId,
                          accountHeadId: selectedHeadId,
                          accountSubHeadName: nameController.text,
                          code: codeController.text,
                        );
                      }
                      showSheetMessage(
                        existing == null
                            ? 'Sub head created.'
                            : 'Sub head updated.',
                      );
                      await Future.delayed(const Duration(milliseconds: 250));
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop(true);
                      }
                    } catch (e) {
                      showSheetMessage(_friendlyError(e), error: true);
                      if (sheetContext.mounted) {
                        setSheetState(() => saving = false);
                      }
                    }
                  }

                  return _EditorSheetFrame(
                    title: existing == null ? 'Add Sub Head' : 'Edit Sub Head',
                    subtitle:
                        'Create clean account categories under the right head.',
                    icon: Icons.category_rounded,
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<int>(
                            initialValue: selectedHeadId,
                            isExpanded: true,
                            decoration: _fieldDecoration(
                              label: 'Account Head',
                              icon: Icons.account_tree_rounded,
                            ),
                            items: _headRows
                                .map(
                                  (head) => DropdownMenuItem<int>(
                                    value: head.accountHeadId,
                                    child: Text(head.accountHeadName),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: saving
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    () async {
                                      setSheetState(
                                        () => selectedHeadId = value,
                                      );
                                      if (existing != null &&
                                          existing.accountHeadId == value &&
                                          existing.code.trim().isNotEmpty) {
                                        codeController.text = existing.code;
                                        return;
                                      }
                                      final nextCode = await _repo
                                          .getNextAccountSubHeadCode(
                                            accountHeadId: value,
                                            excludingAccountSubHeadId:
                                                existing?.accountSubHeadId,
                                          );
                                      if (sheetActive && sheetContext.mounted) {
                                        setSheetState(
                                          () => codeController.text = nextCode,
                                        );
                                      }
                                    }();
                                  },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: nameController,
                            textInputAction: TextInputAction.next,
                            decoration: _fieldDecoration(
                              label: 'Sub Head Name',
                              icon: Icons.badge_rounded,
                              hint: 'Current Assets',
                            ),
                            validator: (value) =>
                                (value?.trim().isEmpty ?? true)
                                ? 'Sub head name is required'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: codeController,
                            readOnly: true,
                            textInputAction: TextInputAction.done,
                            decoration:
                                _fieldDecoration(
                                  label: 'Code',
                                  icon: Icons.code_rounded,
                                  hint: '01-01',
                                ).copyWith(
                                  helperText:
                                      'Auto-generated from account head code',
                                ),
                          ),
                          const SizedBox(height: 18),
                          _SheetPrimaryButton(
                            label: existing == null
                                ? 'Create Sub Head'
                                : 'Save Sub Head',
                            icon: Icons.check_circle_rounded,
                            saving: saving,
                            onPressed: save,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      );

      if (saved == true) {
        await _loadAll();
        await _syncChartChangesNow();
      }
    } finally {
      sheetActive = false;
      codeController.dispose();
      nameController.dispose();
    }
  }

  Future<void> _openChartEditor({AccountHeadOption? existing}) async {
    if (!_ensureCanEditChart()) return;
    if (_headRows.isEmpty || _subHeadRows.isEmpty) {
      _showMessage(
        'Create account heads and sub heads before chart accounts.',
        error: true,
      );
      return;
    }

    var selectedHeadId =
        existing?.accountHeadId ?? _headRows.first.accountHeadId;
    if (!_headRows.any((row) => row.accountHeadId == selectedHeadId)) {
      selectedHeadId = _headRows.first.accountHeadId;
    }
    var subHeads = _subHeadsForHead(selectedHeadId);
    if (subHeads.isEmpty) {
      selectedHeadId = _subHeadRows.first.accountHeadId;
      subHeads = _subHeadsForHead(selectedHeadId);
    }
    var selectedSubHeadId =
        existing?.accountSubHeadId ??
        (subHeads.isEmpty ? 0 : subHeads.first.accountSubHeadId);
    if (!subHeads.any((row) => row.accountSubHeadId == selectedSubHeadId)) {
      selectedSubHeadId = subHeads.isEmpty
          ? 0
          : subHeads.first.accountSubHeadId;
    }

    final initialCode = (existing?.chartCode?.trim().isNotEmpty ?? false)
        ? existing!.chartCode!
        : await _repo.getNextChartAccountCode(
            accountSubHeadId: selectedSubHeadId,
            excludingChartOfAccountId: existing?.accHeadId,
          );
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: existing?.accHeadName ?? '',
    );
    final codeController = TextEditingController(text: initialCode);
    var saving = false;
    var sheetActive = true;

    if (!mounted) {
      nameController.dispose();
      codeController.dispose();
      return;
    }

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) {
          return ScaffoldMessenger(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: StatefulBuilder(
                builder: (sheetContext, setSheetState) {
                  void showSheetMessage(String text, {bool error = false}) {
                    if (!sheetContext.mounted) return;
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: error
                            ? const Color(0xFFB3261E)
                            : _kChartBlue,
                        content: Text(text),
                      ),
                    );
                  }

                  List<AccountSubHeadListRow> currentSubHeads() =>
                      _subHeadsForHead(selectedHeadId);

                  Future<void> save() async {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    if (selectedSubHeadId <= 0) {
                      showSheetMessage('Select a sub head first.', error: true);
                      return;
                    }
                    setSheetState(() => saving = true);
                    try {
                      if (existing == null) {
                        await _repo.createChartAccount(
                          chartAccountName: nameController.text,
                          accountHeadId: selectedHeadId,
                          accountSubHeadId: selectedSubHeadId,
                          code: codeController.text,
                        );
                      } else {
                        await _repo.updateChartAccount(
                          chartOfAccountId: existing.accHeadId,
                          chartAccountName: nameController.text,
                          accountHeadId: selectedHeadId,
                          accountSubHeadId: selectedSubHeadId,
                          code: codeController.text,
                        );
                      }
                      showSheetMessage(
                        existing == null
                            ? 'Chart account created.'
                            : 'Chart account updated.',
                      );
                      await Future.delayed(const Duration(milliseconds: 250));
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop(true);
                      }
                    } catch (e) {
                      showSheetMessage(_friendlyError(e), error: true);
                      if (sheetContext.mounted) {
                        setSheetState(() => saving = false);
                      }
                    }
                  }

                  final matchingSubHeads = currentSubHeads();
                  final safeSubHeadValue =
                      matchingSubHeads.any(
                        (row) => row.accountSubHeadId == selectedSubHeadId,
                      )
                      ? selectedSubHeadId
                      : null;

                  return _EditorSheetFrame(
                    title: existing == null
                        ? 'Add Chart Account'
                        : 'Edit Chart Account',
                    subtitle:
                        'Link the account to the correct financial group and category.',
                    icon: Icons.account_balance_wallet_rounded,
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<int>(
                            initialValue: selectedHeadId,
                            isExpanded: true,
                            decoration: _fieldDecoration(
                              label: 'Account Head',
                              icon: Icons.account_tree_rounded,
                            ),
                            items: _headRows
                                .map(
                                  (head) => DropdownMenuItem<int>(
                                    value: head.accountHeadId,
                                    child: Text(head.accountHeadName),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: saving
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    () async {
                                      final nextSubHeads = _subHeadsForHead(
                                        value,
                                      );
                                      final nextSubHeadId = nextSubHeads.isEmpty
                                          ? 0
                                          : nextSubHeads.first.accountSubHeadId;
                                      setSheetState(() {
                                        selectedHeadId = value;
                                        selectedSubHeadId = nextSubHeadId;
                                      });
                                      final nextCode = await _repo
                                          .getNextChartAccountCode(
                                            accountSubHeadId: nextSubHeadId,
                                            excludingChartOfAccountId:
                                                existing?.accHeadId,
                                          );
                                      if (sheetActive && sheetContext.mounted) {
                                        setSheetState(
                                          () => codeController.text = nextCode,
                                        );
                                      }
                                    }();
                                  },
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<int>(
                            key: ValueKey(
                              'chart-subhead-$selectedHeadId-$safeSubHeadValue',
                            ),
                            initialValue: safeSubHeadValue,
                            isExpanded: true,
                            decoration: _fieldDecoration(
                              label: 'Sub Head',
                              icon: Icons.category_rounded,
                            ),
                            items: matchingSubHeads
                                .map(
                                  (subHead) => DropdownMenuItem<int>(
                                    value: subHead.accountSubHeadId,
                                    child: Text(
                                      subHead.code.isEmpty
                                          ? subHead.accountSubHeadName
                                          : '${subHead.code} - ${subHead.accountSubHeadName}',
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: saving
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    () async {
                                      setSheetState(
                                        () => selectedSubHeadId = value,
                                      );
                                      if (existing != null &&
                                          existing.accountSubHeadId == value &&
                                          (existing.chartCode
                                                  ?.trim()
                                                  .isNotEmpty ??
                                              false)) {
                                        codeController.text =
                                            existing.chartCode!;
                                        return;
                                      }
                                      final nextCode = await _repo
                                          .getNextChartAccountCode(
                                            accountSubHeadId: value,
                                            excludingChartOfAccountId:
                                                existing?.accHeadId,
                                          );
                                      if (sheetActive && sheetContext.mounted) {
                                        setSheetState(
                                          () => codeController.text = nextCode,
                                        );
                                      }
                                    }();
                                  },
                            validator: (_) => matchingSubHeads.isEmpty
                                ? 'Create a sub head for this account head first'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: nameController,
                            textInputAction: TextInputAction.next,
                            decoration: _fieldDecoration(
                              label: 'Chart Account Name',
                              icon: Icons.badge_rounded,
                              hint: 'Cash in Hand',
                            ),
                            validator: (value) =>
                                (value?.trim().isEmpty ?? true)
                                ? 'Chart account name is required'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: codeController,
                            readOnly: true,
                            textInputAction: TextInputAction.done,
                            decoration:
                                _fieldDecoration(
                                  label: 'Chart Code',
                                  icon: Icons.code_rounded,
                                  hint: '01-01-001',
                                ).copyWith(
                                  helperText:
                                      'Auto-generated from sub-head code',
                                ),
                          ),
                          const SizedBox(height: 18),
                          _SheetPrimaryButton(
                            label: existing == null
                                ? 'Create Chart Account'
                                : 'Save Chart Account',
                            icon: Icons.check_circle_rounded,
                            saving: saving,
                            onPressed: save,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      );

      if (saved == true) {
        await _loadAll();
        await _syncChartChangesNow();
      }
    } finally {
      sheetActive = false;
      nameController.dispose();
      codeController.dispose();
    }
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB3261E),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteSubHead(AccountSubHeadListRow row) async {
    if (!_ensureCanEditChart()) return;
    final confirmed = await _confirmDelete(
      title: 'Delete Sub Head?',
      message:
          'This will remove "${row.accountSubHeadName}" from active sub heads. Linked chart accounts must be moved first.',
    );
    if (!confirmed) return;

    try {
      await _repo.deleteAccountSubHead(accountSubHeadId: row.accountSubHeadId);
      await _loadAll();
      _showMessage('Sub head deleted.');
      await _syncChartChangesNow();
    } catch (e) {
      _showMessage(_friendlyError(e), error: true);
    }
  }

  Future<void> _deleteChart(AccountHeadOption row) async {
    if (!_ensureCanEditChart()) return;
    final confirmed = await _confirmDelete(
      title: 'Delete Chart Account?',
      message:
          'This will remove "${row.accHeadName}" from active chart accounts. Accounts using it must be moved first.',
    );
    if (!confirmed) return;

    try {
      await _repo.deleteChartAccount(chartOfAccountId: row.accHeadId);
      await _loadAll();
      _showMessage('Chart account deleted.');
      await _syncChartChangesNow();
    } catch (e) {
      _showMessage(_friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final heads = _filteredHeads;
    final subHeads = _filteredSubHeads;
    final charts = _filteredCharts;

    return Scaffold(
      backgroundColor: _kChartBg,
      floatingActionButton: _buildFloatingActionButton(),
      body: Stack(
        children: [
          const _ChartBackdrop(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: _buildHeader(
                    heads: heads.length,
                    subHeads: subHeads.length,
                    charts: charts.length,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: _buildSearchField(),
                ),
                if (_chartSyncing)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                    child: _buildChartSyncBanner(),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: _buildTabs(),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildHeadsTab(heads),
                      _buildSubHeadsTab(subHeads),
                      _buildChartAccountsTab(charts),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSyncBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD7E6F5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x121862A3),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: _kChartBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _chartSyncMessage.isEmpty
                  ? 'Uploading chart changes to server...'
                  : _chartSyncMessage,
              style: const TextStyle(
                color: Color(0xFF163A5F),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    if (_activeTabIndex == 0) return const SizedBox.shrink();

    final isSubHead = _activeTabIndex == 1;
    return FloatingActionButton.extended(
      heroTag: 'chart_of_accounts_action',
      elevation: 8,
      backgroundColor: _kChartBlueDark,
      foregroundColor: Colors.white,
      icon: Icon(
        isSubHead
            ? Icons.add_business_rounded
            : Icons.account_balance_wallet_rounded,
      ),
      label: Text(isSubHead ? 'Add Sub Head' : 'Add Chart'),
      onPressed: _busy
          ? null
          : () => isSubHead ? _openSubHeadEditor() : _openChartEditor(),
    );
  }

  Widget _buildHeader({
    required int heads,
    required int subHeads,
    required int charts,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kChartBlue, _kChartBlueDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x261862A3),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.schema_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chart of Accounts',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Review account heads, sub heads, and chart accounts from the local database.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeaderStat(
                  label: 'Heads',
                  value: heads.toString(),
                  icon: Icons.account_tree_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderStat(
                  label: 'Sub Heads',
                  value: subHeads.toString(),
                  icon: Icons.category_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderStat(
                  label: 'Chart',
                  value: charts.toString(),
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Search head, sub head, chart account, code, or ID',
        prefixIcon: const Icon(Icons.search_rounded, color: _kChartBlue),
        suffixIcon: _searchQuery.trim().isEmpty
            ? IconButton(
                tooltip: 'Refresh',
                onPressed: _busy ? null : _loadAll,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _kChartBlue,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, color: _kChartBlue),
              )
            : IconButton(
                tooltip: 'Clear search',
                onPressed: _clearSearch,
                icon: const Icon(Icons.close_rounded, color: _kChartBlue),
              ),
        filled: true,
        fillColor: Colors.white,
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
          borderSide: const BorderSide(color: _kChartBlue, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDECF8)),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: _kChartBlue,
          borderRadius: BorderRadius.circular(14),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF315B7E),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        tabs: const [
          Tab(text: 'Heads'),
          Tab(text: 'Sub Heads'),
          Tab(text: 'Chart'),
        ],
      ),
    );
  }

  Widget _buildHeadsTab(List<AccountHeadListRow> rows) {
    return _TabList(
      busy: _busy,
      emptyTitle: _query.isEmpty
          ? 'No account heads found'
          : 'No matching head',
      emptyMessage: _query.isEmpty
          ? 'Account heads will appear here after sync or database setup.'
          : 'Clear search to view all account heads.',
      onRefresh: _loadAll,
      children: [
        const _LockedHeadsNotice(),
        ...rows.map(
          (row) => _DataCard(
            avatar: _initials(row.accountHeadName),
            title: row.accountHeadName,
            subtitle: 'AccountHeadID ${row.accountHeadId}',
            icon: Icons.account_tree_outlined,
            actions: const [],
            chips: [
              const _InfoChip(
                icon: Icons.lock_outline_rounded,
                label: 'Locked',
              ),
              _InfoChip(
                icon: Icons.tag_rounded,
                label: 'ID ${row.accountHeadId}',
              ),
              _InfoChip(
                icon: row.normalBalance.toLowerCase() == 'credit'
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                label: row.normalBalance.isEmpty
                    ? 'Normal Balance'
                    : row.normalBalance,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubHeadsTab(List<AccountSubHeadListRow> rows) {
    final grouped = <String, List<AccountSubHeadListRow>>{};
    for (final row in rows) {
      final key = _label(
        row.accountHeadName,
        fallback: 'Head ${row.accountHeadId}',
      );
      grouped.putIfAbsent(key, () => <AccountSubHeadListRow>[]).add(row);
    }

    return _TabList(
      busy: _busy,
      emptyTitle: _query.isEmpty
          ? 'No account sub heads found'
          : 'No matching sub head',
      emptyMessage: _query.isEmpty
          ? 'Sub heads will appear here after sync or database setup.'
          : 'Clear search to view all account sub heads.',
      onRefresh: _loadAll,
      children: grouped.entries
          .map(
            (entry) => _GroupCard(
              title: entry.key,
              countLabel:
                  '${entry.value.length} sub head${entry.value.length == 1 ? '' : 's'}',
              children: entry.value
                  .map(
                    (row) => _DataCard(
                      avatar: row.code.isEmpty
                          ? _initials(row.accountSubHeadName)
                          : row.code,
                      title: row.accountSubHeadName,
                      subtitle: 'AccountSubHeadID ${row.accountSubHeadId}',
                      icon: Icons.category_outlined,
                      compact: true,
                      actions: [
                        _CardActionButton(
                          tooltip: 'Edit sub head',
                          icon: Icons.edit_rounded,
                          color: _kChartBlue,
                          onPressed: () => _openSubHeadEditor(existing: row),
                        ),
                        _CardActionButton(
                          tooltip: 'Delete sub head',
                          icon: Icons.delete_outline_rounded,
                          color: const Color(0xFFB3261E),
                          onPressed: () => _deleteSubHead(row),
                        ),
                      ],
                      chips: [
                        if (row.code.isNotEmpty)
                          _InfoChip(icon: Icons.code_rounded, label: row.code),
                        _InfoChip(
                          icon: Icons.tag_rounded,
                          label: 'ID ${row.accountSubHeadId}',
                        ),
                        _InfoChip(
                          icon: Icons.account_tree_outlined,
                          label: 'Head ${row.accountHeadId}',
                        ),
                      ],
                    ),
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildChartAccountsTab(List<AccountHeadOption> rows) {
    final sortedRows = [...rows]
      ..sort((a, b) {
        int compareText(String left, String right) =>
            left.toLowerCase().compareTo(right.toLowerCase());
        final byHead = compareText(
          a.accountHeadName ?? '',
          b.accountHeadName ?? '',
        );
        if (byHead != 0) return byHead;
        final bySubHeadCode = compareText(
          a.accountSubHeadCode ?? '',
          b.accountSubHeadCode ?? '',
        );
        if (bySubHeadCode != 0) return bySubHeadCode;
        final byChartCode = compareText(a.chartCode ?? '', b.chartCode ?? '');
        if (byChartCode != 0) return byChartCode;
        return compareText(a.accHeadName, b.accHeadName);
      });

    final grouped = <String, Map<String, List<AccountHeadOption>>>{};
    for (final row in sortedRows) {
      final key = _label(row.accountHeadName, fallback: 'Unassigned Head');
      final subHeadName = _label(
        row.accountSubHeadName,
        fallback: 'No Sub Head',
      );
      final subHeadCode = _label(row.accountSubHeadCode, fallback: '');
      final subHeadKey = subHeadCode.isEmpty
          ? subHeadName
          : '$subHeadCode - $subHeadName';

      grouped
          .putIfAbsent(key, () => <String, List<AccountHeadOption>>{})
          .putIfAbsent(subHeadKey, () => <AccountHeadOption>[])
          .add(row);
    }

    return _TabList(
      busy: _busy,
      emptyTitle: _query.isEmpty
          ? 'No chart accounts found'
          : 'No matching chart account',
      emptyMessage: _query.isEmpty
          ? 'Chart accounts will appear here after sync or database setup.'
          : 'Clear search to view all chart accounts.',
      onRefresh: _loadAll,
      children: grouped.entries
          .map((entry) {
            final chartCount = entry.value.values.fold<int>(
              0,
              (total, charts) => total + charts.length,
            );
            return _GroupCard(
              title: entry.key,
              countLabel:
                  '$chartCount chart account${chartCount == 1 ? '' : 's'}',
              children: entry.value.entries
                  .map(
                    (subEntry) => _ChartSubHeadSection(
                      title: subEntry.key,
                      countLabel:
                          '${subEntry.value.length} chart${subEntry.value.length == 1 ? '' : 's'}',
                      children: subEntry.value
                          .map(_buildChartAccountCard)
                          .toList(growable: false),
                    ),
                  )
                  .toList(growable: false),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildChartAccountCard(AccountHeadOption row) {
    final chartCode = _label(row.chartCode, fallback: '');

    return _DataCard(
      avatar: _initials(row.accHeadName),
      title: row.accHeadName,
      subtitle: 'ChartOfAccountID ${row.accHeadId}',
      icon: Icons.account_balance_wallet_outlined,
      compact: true,
      actions: [
        _CardActionButton(
          tooltip: 'Edit chart account',
          icon: Icons.edit_rounded,
          color: _kChartBlue,
          onPressed: () => _openChartEditor(existing: row),
        ),
        _CardActionButton(
          tooltip: 'Delete chart account',
          icon: Icons.delete_outline_rounded,
          color: const Color(0xFFB3261E),
          onPressed: () => _deleteChart(row),
        ),
      ],
      chips: [
        if (chartCode.isNotEmpty)
          _InfoChip(icon: Icons.code_rounded, label: chartCode),
        _InfoChip(icon: Icons.tag_rounded, label: 'COA ${row.accHeadId}'),
        if ((row.accountHeadId ?? 0) > 0)
          _InfoChip(
            icon: Icons.account_tree_outlined,
            label: 'Head ${row.accountHeadId}',
          ),
      ],
    );
  }
}

class _TabList extends StatelessWidget {
  final bool busy;
  final String emptyTitle;
  final String emptyMessage;
  final Future<void> Function() onRefresh;
  final List<Widget> children;

  const _TabList({
    required this.busy,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onRefresh,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _kChartBlue,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (busy && children.isEmpty)
            const _LoadingCard()
          else if (children.isEmpty)
            _EmptyChartCard(title: emptyTitle, message: emptyMessage)
          else
            ...children,
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final String title;
  final String countLabel;
  final List<Widget> children;

  const _GroupCard({
    required this.title,
    required this.countLabel,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4EEF8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x101862A3),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kChartBlue, _kChartBlueDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.folder_open_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        countLabel,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE4EEF8)),
          ...children,
        ],
      ),
    );
  }
}

class _LockedHeadsNotice extends StatelessWidget {
  const _LockedHeadsNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCFE2F5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: _kChartBlue,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Heads are locked',
                  style: TextStyle(
                    color: Color(0xFF0D4F88),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Top-level heads are master data. Add or edit Sub Heads and Chart Accounts instead.',
                  style: TextStyle(
                    color: Color(0xFF315B7E),
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
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

class _ChartSubHeadSection extends StatelessWidget {
  final String title;
  final String countLabel;
  final List<Widget> children;

  const _ChartSubHeadSection({
    required this.title,
    required this.countLabel,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDECF8)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3FC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.category_rounded,
                    color: _kChartBlue,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        countLabel,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFDDECF8)),
          ...children,
        ],
      ),
    );
  }
}

class _DataCard extends StatelessWidget {
  final String avatar;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> chips;
  final bool compact;
  final List<Widget> actions;

  const _DataCard({
    required this.avatar,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.chips,
    this.compact = false,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.fromLTRB(
        14,
        compact ? 12 : 14,
        14,
        compact ? 12 : 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 38 : 42,
            height: compact ? 38 : 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: avatar.length <= 5
                  ? Text(
                      avatar,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _kChartBlue,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : Icon(icon, color: _kChartBlue, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Row(mainAxisSize: MainAxisSize.min, children: actions),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: chips),
              ],
            ),
          ),
        ],
      ),
    );

    if (compact) return content;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4EEF8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x101862A3),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: content,
    );
  }
}

class _EditorSheetFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _EditorSheetFrame({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.92;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        FocusManager.instance.primaryFocus?.unfocus();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          Navigator.of(context).pop();
        });
      },
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Color(0x331862A3),
                blurRadius: 28,
                offset: Offset(0, -10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7E6F5),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_kChartBlue, _kChartBlueDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Icon(icon, color: Colors.white),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12.5,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetPrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool saving;
  final Future<void> Function() onPressed;

  const _SheetPrimaryButton({
    required this.label,
    required this.icon,
    required this.saving,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: _kChartBlueDark,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: saving ? null : onPressed,
        icon: saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon),
        label: Text(
          saving ? 'Saving...' : label,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _CardActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.08),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 17, color: color),
          ),
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _HeaderStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 17),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7FD),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDDECF8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _kChartBlue),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF315B7E),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4EEF8)),
      ),
      child: const Center(child: CircularProgressIndicator(color: _kChartBlue)),
    );
  }
}

class _EmptyChartCard extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyChartCard({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4EEF8)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FC),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.schema_outlined,
              color: _kChartBlue,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartBackdrop extends StatelessWidget {
  const _ChartBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE7F1FB), Color(0xFFF3F7FC)],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}
