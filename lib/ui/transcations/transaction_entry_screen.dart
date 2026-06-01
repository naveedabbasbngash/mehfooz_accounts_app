import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/local/app_database.dart';
import '../../model/account_head_option.dart';
import '../../repository/transactions_repository.dart';
import '../../theme/app_colors.dart';
import '../../viewmodel/sync/sync_viewmodel.dart';

enum _EntrySide { debit, credit }

const _kEntryBlue = Color(0xFF1862A3);
const _kEntrySurface = Color(0xFFF8FBFF);

class TransactionEntryScreen extends StatefulWidget {
  final TransactionsRepository repo;
  final int companyId;
  final bool showAppBar;
  final bool enableQualityFields;
  final int? editVoucherNo;

  const TransactionEntryScreen({
    super.key,
    required this.repo,
    required this.companyId,
    this.showAppBar = true,
    this.enableQualityFields = false,
    this.editVoucherNo,
  });

  @override
  State<TransactionEntryScreen> createState() => _TransactionEntryScreenState();
}

class _TransactionEntryScreenState extends State<TransactionEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  final _descriptionCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _qualityCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _debitCtrl = TextEditingController();
  final _creditCtrl = TextEditingController();
  final _accountDisplayCtrl = TextEditingController();
  final _currencyDisplayCtrl = TextEditingController();
  final _qualityFocusNode = FocusNode();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isCash = false;
  DateTime _txDate = DateTime.now();

  List<AccPersonalData> _accounts = [];
  List<AccTypeData> _accountTypes = [];

  int? _selectedAccId;
  int? _selectedAccTypeId;
  int? _selectedCashAccId;
  _EntrySide _entrySide = _EntrySide.debit;
  String? _existingQuality;
  double? _existingRate;
  double? _existingWeight;
  List<String> _qualitySuggestions = const <String>[];
  bool _showQualitySuggestions = false;
  int _qualitySearchToken = 0;

  double _currentBalance = 0.0;
  double _projectedBalance = 0.0;

  bool get _isEdit => widget.editVoucherNo != null;

  @override
  void initState() {
    super.initState();
    _debitCtrl.addListener(_refreshProjectedBalance);
    _creditCtrl.addListener(_refreshProjectedBalance);
    _weightCtrl.addListener(_onRateWeightChanged);
    _rateCtrl.addListener(_onRateWeightChanged);
    _qualityFocusNode.addListener(() {
      if (!_qualityFocusNode.hasFocus) {
        if (mounted && _showQualitySuggestions) {
          setState(() => _showQualitySuggestions = false);
        }
        return;
      }
      if (widget.enableQualityFields) {
        _loadQualitySuggestions(_qualityCtrl.text);
      }
    });
    _bootstrapInitialData();
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _referenceCtrl.dispose();
    _qualityCtrl.dispose();
    _weightCtrl.dispose();
    _rateCtrl.dispose();
    _debitCtrl.dispose();
    _creditCtrl.dispose();
    _accountDisplayCtrl.dispose();
    _currencyDisplayCtrl.dispose();
    _qualityFocusNode.dispose();
    super.dispose();
  }

  Future<void> _bootstrapInitialData() async {
    await _loadInitialData();
    unawaited(_runPreloadSyncForEntry());
  }

  Future<void> _runPreloadSyncForEntry() async {
    SyncViewModel? syncVm;
    try {
      syncVm = context.read<SyncViewModel>();
    } catch (_) {
      syncVm = null;
    }
    if (syncVm == null) return;

    try {
      await syncVm
          .syncNowIfNeededSingleFlight(force: false, silent: true)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Best-effort preflight only.
      return;
    }

    await _refreshMasterDataAfterBackgroundSync();
  }

  Future<void> _refreshMasterDataAfterBackgroundSync() async {
    if (!mounted || _isLoading) return;

    try {
      final accounts = await widget.repo.getAccountsForCompany(
        companyId: widget.companyId,
      );
      if (!mounted) return;

      var selectedAccId = _selectedAccId;
      if (selectedAccId == null ||
          !accounts.any((acc) => acc.accId == selectedAccId)) {
        selectedAccId = accounts.isEmpty ? null : accounts.first.accId;
      }

      final cashAccounts = _cashAccountsFrom(accounts);
      var selectedCashAccId = _selectedCashAccId;
      if (selectedCashAccId == null ||
          !cashAccounts.any((acc) => acc.accId == selectedCashAccId)) {
        selectedCashAccId = cashAccounts.isEmpty
            ? null
            : cashAccounts.first.accId;
      }

      List<AccTypeData> accountTypes = [];
      int? selectedAccTypeId;
      var currentBalance = 0.0;
      if (selectedAccId != null) {
        accountTypes = await widget.repo.getAssignedAccTypesForAccount(
          accId: selectedAccId,
          companyId: widget.companyId,
        );
        selectedAccTypeId = _selectedAccTypeId;
        if (selectedAccTypeId == null ||
            !accountTypes.any((t) => t.accTypeId == selectedAccTypeId)) {
          selectedAccTypeId = accountTypes.isEmpty
              ? null
              : accountTypes.first.accTypeId;
        }
        if (selectedAccTypeId != null) {
          currentBalance = await widget.repo.getBalanceForAccountAndType(
            companyId: widget.companyId,
            accId: selectedAccId,
            accTypeId: selectedAccTypeId,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _selectedAccId = selectedAccId;
        _accountTypes = accountTypes;
        _selectedAccTypeId = selectedAccTypeId;
        _selectedCashAccId = selectedCashAccId;
        _currentBalance = currentBalance;
      });
      _accountDisplayCtrl.text = _accountLabelById(selectedAccId);
      _currencyDisplayCtrl.text = _currencyLabelById(selectedAccTypeId);
      _refreshProjectedBalance();
    } catch (_) {
      // Keep entry smooth; this refresh is intentionally silent.
    }
  }

  Future<void> _loadInitialData({int? preferredAccId}) async {
    setState(() => _isLoading = true);

    try {
      TransactionEditData? editingData;
      if (_isEdit) {
        editingData = await widget.repo.getTransactionForEditing(
          companyId: widget.companyId,
          voucherNo: widget.editVoucherNo!,
        );
        if (editingData == null) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          _showError('Transaction not found for editing');
          return;
        }
      }

      final accounts = await widget.repo.getAccountsForCompany(
        companyId: widget.companyId,
      );

      var selectedAccId = editingData?.accId ?? preferredAccId;
      if (selectedAccId == null ||
          !accounts.any((acc) => acc.accId == selectedAccId)) {
        selectedAccId = accounts.isEmpty ? null : accounts.first.accId;
      }

      final cashAccounts = _cashAccountsFrom(accounts);
      var selectedCashAccId = editingData?.cashAccId ?? _selectedCashAccId;
      if (selectedCashAccId == null ||
          !cashAccounts.any((acc) => acc.accId == selectedCashAccId)) {
        selectedCashAccId = cashAccounts.isEmpty
            ? null
            : cashAccounts.first.accId;
      }

      List<AccTypeData> accountTypes = [];
      int? selectedAccTypeId;
      var currentBalance = 0.0;

      if (selectedAccId != null) {
        accountTypes = await widget.repo.getAssignedAccTypesForAccount(
          accId: selectedAccId,
          companyId: widget.companyId,
        );
        final editingAccTypeId = editingData?.accTypeId;
        if (editingAccTypeId != null &&
            accountTypes.every((t) => t.accTypeId != editingAccTypeId)) {
          final allTypes = await widget.repo.getAllAccTypes();
          for (final t in allTypes) {
            if (t.accTypeId == editingAccTypeId) {
              accountTypes = [...accountTypes, t];
              break;
            }
          }
        }
        selectedAccTypeId = editingData?.accTypeId;
        if (selectedAccTypeId == null ||
            !accountTypes.any((t) => t.accTypeId == selectedAccTypeId)) {
          selectedAccTypeId = accountTypes.isEmpty
              ? null
              : accountTypes.first.accTypeId;
        }

        if (selectedAccTypeId != null) {
          currentBalance = await widget.repo.getBalanceForAccountAndType(
            companyId: widget.companyId,
            accId: selectedAccId,
            accTypeId: selectedAccTypeId,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _selectedAccId = selectedAccId;
        _accountTypes = accountTypes;
        _selectedAccTypeId = selectedAccTypeId;
        _selectedCashAccId = selectedCashAccId;
        _currentBalance = currentBalance;
        _isCash = editingData?.isCash ?? false;
        if (editingData != null) {
          _txDate = editingData.txDate;
          _entrySide = editingData.credit > 0
              ? _EntrySide.credit
              : _EntrySide.debit;
          _existingQuality = editingData.quality;
          _existingRate = editingData.rate;
          _existingWeight = editingData.weight;
        }
        _isLoading = false;
      });
      if (editingData != null) {
        _descriptionCtrl.text = editingData.description;
        _referenceCtrl.text = editingData.entryReference;
        _qualityCtrl.text = editingData.quality ?? '';
        _weightCtrl.text = editingData.weight == null
            ? ''
            : _amountInputText(editingData.weight!.abs());
        _rateCtrl.text = editingData.rate == null
            ? ''
            : _amountInputText(editingData.rate!);
        _debitCtrl.text = editingData.debit > 0
            ? _amountInputText(editingData.debit)
            : '';
        _creditCtrl.text = editingData.credit > 0
            ? _amountInputText(editingData.credit)
            : '';
      }
      _accountDisplayCtrl.text = _accountLabelById(selectedAccId);
      _currencyDisplayCtrl.text = _currencyLabelById(selectedAccTypeId);
      _refreshProjectedBalance();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Failed to load form data: $e');
    }
  }

  Future<void> _onAccountChanged(int? accId) async {
    if (accId == null) return;

    setState(() {
      _selectedAccId = accId;
      _accountTypes = [];
      _selectedAccTypeId = null;
      _currentBalance = 0.0;
    });
    _currencyDisplayCtrl.clear();

    try {
      final accountTypes = await widget.repo.getAssignedAccTypesForAccount(
        accId: accId,
        companyId: widget.companyId,
      );
      int? selectedAccTypeId = accountTypes.isEmpty
          ? null
          : accountTypes.first.accTypeId;
      var currentBalance = 0.0;

      if (selectedAccTypeId != null) {
        currentBalance = await widget.repo.getBalanceForAccountAndType(
          companyId: widget.companyId,
          accId: accId,
          accTypeId: selectedAccTypeId,
        );
      }

      if (!mounted) return;
      setState(() {
        _accountTypes = accountTypes;
        _selectedAccTypeId = selectedAccTypeId;
        _currentBalance = currentBalance;
      });
      _accountDisplayCtrl.text = _accountLabelById(accId);
      _currencyDisplayCtrl.text = _currencyLabelById(selectedAccTypeId);
      _refreshProjectedBalance();
    } catch (e) {
      _showError('Failed to load account types: $e');
    }
  }

  String _accountLabelById(int? accId) {
    if (accId == null) return '';
    AccPersonalData? match;
    for (final a in _accounts) {
      if (a.accId == accId) {
        match = a;
        break;
      }
    }
    if (match == null) return 'Account #$accId';

    final name = (match.name ?? '').trim();
    if (name.isEmpty) return 'Account #${match.accId}';
    return '$name (#${match.accId})';
  }

  String _currencyLabelById(int? accTypeId) {
    if (accTypeId == null) return '';
    for (final t in _accountTypes) {
      if (t.accTypeId != accTypeId) continue;
      final name = (t.accTypeName ?? '').trim();
      if (name.isNotEmpty) return name;
      final altName = (t.accTypeNameU ?? '').trim();
      if (altName.isNotEmpty) return altName;
      return 'Currency #$accTypeId';
    }
    return 'Currency #$accTypeId';
  }

  Future<void> _openCurrencyPicker() async {
    if (_accountTypes.isEmpty) {
      _showError(
        'No currency assigned for this account. Edit customer to assign currencies.',
      );
      return;
    }
    final pickedId = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => _CurrencyPickerScreen(
          accountTypes: _accountTypes,
          selectedAccTypeId: _selectedAccTypeId,
        ),
      ),
    );
    if (pickedId == null) return;
    await _onAccountTypeChanged(pickedId);
  }

  List<AccPersonalData> _cashAccountsFrom(List<AccPersonalData> accounts) {
    return accounts.where((a) {
      final headName = (a.statusg ?? '').trim().toLowerCase();
      return headName == 'cash';
    }).toList();
  }

  List<AccPersonalData> get _cashAccounts => _cashAccountsFrom(_accounts);

  Future<void> _openAccountPicker() async {
    final picked = await Navigator.of(context).push<AccPersonalData>(
      MaterialPageRoute(
        builder: (_) => _AccountPickerScreen(
          repo: widget.repo,
          companyId: widget.companyId,
          selectedAccId: _selectedAccId,
        ),
      ),
    );
    if (picked == null) return;
    final idx = _accounts.indexWhere((a) => a.accId == picked.accId);
    if (idx == -1) {
      setState(() => _accounts = [..._accounts, picked]);
    } else {
      final updated = [..._accounts];
      updated[idx] = picked;
      setState(() => _accounts = updated);
    }
    await _onAccountChanged(picked.accId);
  }

  Future<void> _onAccountTypeChanged(int? accTypeId) async {
    if (accTypeId == null || _selectedAccId == null) return;

    setState(() => _selectedAccTypeId = accTypeId);
    _currencyDisplayCtrl.text = _currencyLabelById(accTypeId);

    try {
      final currentBalance = await widget.repo.getBalanceForAccountAndType(
        companyId: widget.companyId,
        accId: _selectedAccId!,
        accTypeId: accTypeId,
      );
      if (!mounted) return;
      setState(() => _currentBalance = currentBalance);
      _refreshProjectedBalance();
    } catch (e) {
      _showError('Failed to load balance: $e');
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _txDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _kEntryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF16324B),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              headerBackgroundColor: _kEntryBlue,
              headerForegroundColor: Colors.white,
              todayForegroundColor: WidgetStatePropertyAll(_kEntryBlue),
              dayForegroundColor: const WidgetStatePropertyAll(
                Color(0xFF16324B),
              ),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) return;
    setState(() => _txDate = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedAccId == null) {
      _showError('Please select a customer/account');
      return;
    }
    if (_selectedAccTypeId == null) {
      _showError('Please select an account type');
      return;
    }
    if (_isCash && _cashAccounts.isEmpty) {
      _showError('No cash account found under Cash head');
      return;
    }
    if (_isCash && _selectedCashAccId == null) {
      _showError('Please select a cash account');
      return;
    }
    if (_isCash && _selectedCashAccId == _selectedAccId) {
      _showError('Cash account must be different from selected account');
      return;
    }

    final debit = _parseAmount(_debitCtrl.text);
    final credit = _parseAmount(_creditCtrl.text);

    final hasDebit = debit > 0;
    final hasCredit = credit > 0;

    if (hasDebit == hasCredit) {
      _showError('Enter either Debit or Credit (only one side)');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final quality = widget.enableQualityFields
          ? _qualityCtrl.text.trim()
          : _existingQuality;
      final weight = widget.enableQualityFields
          ? (() {
              final v = _parseAmount(_weightCtrl.text);
              return v > 0 ? v : null;
            })()
          : _existingWeight;
      final rate = widget.enableQualityFields
          ? (() {
              final v = _parseAmount(_rateCtrl.text);
              return v > 0 ? v : null;
            })()
          : _existingRate;

      if (_isEdit) {
        await widget.repo.updateTransactionWithLinkedEntries(
          companyId: widget.companyId,
          voucherNo: widget.editVoucherNo!,
          accId: _selectedAccId!,
          accTypeId: _selectedAccTypeId!,
          txDate: _txDate,
          description: _descriptionCtrl.text.trim(),
          entryReference: _referenceCtrl.text.trim(),
          quality: quality,
          weight: weight,
          rate: rate,
          debit: debit,
          credit: credit,
          isCash: _isCash,
          cashAccId: _isCash ? _selectedCashAccId : null,
        );
      } else {
        await widget.repo.insertTransactionEntry(
          companyId: widget.companyId,
          accId: _selectedAccId!,
          accTypeId: _selectedAccTypeId!,
          txDate: _txDate,
          description: _descriptionCtrl.text.trim(),
          entryReference: _referenceCtrl.text.trim(),
          quality: quality,
          weight: weight,
          rate: rate,
          debit: debit,
          credit: credit,
          isCash: _isCash,
          cashAccId: _isCash ? _selectedCashAccId : null,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? 'Transaction updated successfully'
                : 'Transaction saved successfully',
          ),
        ),
      );
      try {
        unawaited(
          context.read<SyncViewModel>().triggerSmartSync(immediate: true),
        );
      } catch (_) {
        // Sync VM may not be available in isolated routes/tests.
      }
      Navigator.pop(context, true);
    } catch (e) {
      _showError(
        _isEdit
            ? 'Failed to update transaction: $e'
            : 'Failed to save transaction: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _refreshProjectedBalance() {
    final debit = _parseAmount(_debitCtrl.text);
    final credit = _parseAmount(_creditCtrl.text);
    final projected = _currentBalance + credit - debit;
    if (!mounted) return;
    setState(() => _projectedBalance = projected);
  }

  double _parseAmount(String raw) {
    final normalized = raw.trim().replaceAll(',', '');
    return double.tryParse(normalized) ?? 0.0;
  }

  String _amountInputText(double value) {
    final safe = value.abs() < 0.0000005 ? 0.0 : value;
    if (safe == safe.roundToDouble()) return safe.toInt().toString();
    return safe
        .toStringAsFixed(6)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  Future<void> _loadQualitySuggestions(String query) async {
    if (!widget.enableQualityFields) return;
    final normalized = query.trim();
    if (normalized.isEmpty) {
      if (!mounted) return;
      setState(() {
        _qualitySuggestions = const <String>[];
        _showQualitySuggestions = false;
      });
      return;
    }

    final token = ++_qualitySearchToken;
    final rows = await widget.repo.searchQualitySuggestions(
      companyId: widget.companyId,
      query: normalized,
    );
    if (!mounted || token != _qualitySearchToken) return;

    setState(() {
      _qualitySuggestions = rows;
      _showQualitySuggestions = _qualityFocusNode.hasFocus && rows.isNotEmpty;
    });
  }

  void _applyQualitySuggestion(String value) {
    _qualityCtrl.text = value;
    _qualityCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: value.length),
    );
    setState(() => _showQualitySuggestions = false);
    FocusScope.of(context).unfocus();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  String _fmtDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  String _fmtAmount(double v) => v.toStringAsFixed(2);

  void _setEntrySide(_EntrySide side) {
    setState(() => _entrySide = side);

    if (side == _EntrySide.debit &&
        _parseAmount(_debitCtrl.text) <= 0 &&
        _creditCtrl.text.trim().isNotEmpty) {
      _creditCtrl.clear();
    }
    if (side == _EntrySide.credit &&
        _parseAmount(_creditCtrl.text) <= 0 &&
        _debitCtrl.text.trim().isNotEmpty) {
      _debitCtrl.clear();
    }

    _applyComputedAmountIfPossible();
  }

  void _applyQuickAmount(double amount) {
    final text = amount == amount.roundToDouble()
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);

    if (_entrySide == _EntrySide.debit) {
      _debitCtrl.text = text;
      _debitCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _debitCtrl.text.length),
      );
      _creditCtrl.clear();
    } else {
      _creditCtrl.text = text;
      _creditCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _creditCtrl.text.length),
      );
      _debitCtrl.clear();
    }
  }

  void _onRateWeightChanged() {
    if (!widget.enableQualityFields) return;
    _applyComputedAmountIfPossible();
  }

  void _applyComputedAmountIfPossible() {
    if (!widget.enableQualityFields) return;

    final weight = _parseAmount(_weightCtrl.text);
    final rate = _parseAmount(_rateCtrl.text);
    if (weight <= 0 || rate <= 0) return;

    final amount = weight * rate;
    final text = amount == amount.roundToDouble()
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);

    if (_entrySide == _EntrySide.debit) {
      _debitCtrl.text = text;
      _debitCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _debitCtrl.text.length),
      );
      _creditCtrl.clear();
      return;
    }

    _creditCtrl.text = text;
    _creditCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _creditCtrl.text.length),
    );
    _debitCtrl.clear();
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: _kEntrySurface,
      labelStyle: const TextStyle(
        color: Color(0xFF5F7893),
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF8AA0B5),
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _kEntryBlue.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _kEntryBlue.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kEntryBlue, width: 1.6),
      ),
    );
  }

  Widget _surfaceCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF9FBFF)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE8F3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x101862A3),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _balanceTile({
    required String label,
    required double value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _fmtAmount(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: value < 0 ? Colors.red.shade700 : color,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountField({
    required TextEditingController controller,
    required String label,
    required Color color,
    required IconData icon,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: color, fontWeight: FontWeight.w700),
      cursorColor: color,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration:
          _fieldDecoration(
            label: label,
            prefixIcon: Icon(icon, color: color),
          ).copyWith(
            labelStyle: TextStyle(color: color),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: color, width: 1.8),
            ),
          ),
    );
  }

  Widget _dateField() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: _fieldDecoration(
          label: 'Transaction Date *',
          prefixIcon: const Icon(Icons.event_outlined),
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(
          _fmtDate(_txDate),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(_isEdit ? 'Update Transaction' : 'New Transaction'),
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
            )
          : null,
      bottomNavigationBar: _isLoading
          ? null
          : AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                12 + MediaQuery.of(context).padding.bottom + bottomInset,
              ),
              child: Material(
                color: Colors.white,
                elevation: 10,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _submit,
                      icon: _isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isSaving
                            ? (_isEdit ? 'Updating...' : 'Saving...')
                            : (_isEdit ? 'Update' : 'Submit'),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kEntryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 430;

                  return Form(
                    key: _formKey,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        12,
                        16,
                        120 + bottomInset,
                      ),
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _kEntryBlue.withValues(alpha: 0.12),
                                Colors.white,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _kEntryBlue.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                height: 42,
                                width: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.post_add_outlined,
                                  color: _kEntryBlue,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _isEdit
                                      ? 'Update the transaction details with live balance preview.'
                                      : 'Create a debit or credit entry with live balance preview.',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _surfaceCard(
                          child: Column(
                            children: [
                              if (isNarrow) ...[
                                CheckboxListTile(
                                  value: _isCash,
                                  onChanged: (v) {
                                    final next = v ?? false;
                                    setState(() {
                                      _isCash = next;
                                      if (_isCash &&
                                          _selectedCashAccId == null &&
                                          _cashAccounts.isNotEmpty) {
                                        _selectedCashAccId =
                                            _cashAccounts.first.accId;
                                      }
                                    });
                                  },
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Cash transaction'),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                ),
                                const SizedBox(height: 8),
                                _dateField(),
                              ] else
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: CheckboxListTile(
                                        value: _isCash,
                                        onChanged: (v) {
                                          final next = v ?? false;
                                          setState(() {
                                            _isCash = next;
                                            if (_isCash &&
                                                _selectedCashAccId == null &&
                                                _cashAccounts.isNotEmpty) {
                                              _selectedCashAccId =
                                                  _cashAccounts.first.accId;
                                            }
                                          });
                                        },
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: const Text('Cash transaction'),
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(child: _dateField()),
                                  ],
                                ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                child: _isCash
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: DropdownButtonFormField<int>(
                                          key: ValueKey(
                                            'cash-${_selectedCashAccId ?? 0}-${_cashAccounts.length}',
                                          ),
                                          initialValue: _selectedCashAccId,
                                          decoration: _fieldDecoration(
                                            label: 'Cash Account *',
                                            prefixIcon: const Icon(
                                              Icons
                                                  .account_balance_wallet_outlined,
                                            ),
                                          ),
                                          isExpanded: true,
                                          items: _cashAccounts
                                              .map(
                                                (a) => DropdownMenuItem<int>(
                                                  value: a.accId,
                                                  child: Text(
                                                    _accountLabelById(a.accId),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (v) {
                                            setState(
                                              () => _selectedCashAccId = v,
                                            );
                                          },
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              if (_isCash && _cashAccounts.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'No account found with head "Cash".',
                                      style: TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _surfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _accountDisplayCtrl,
                                readOnly: true,
                                onTap: _openAccountPicker,
                                decoration: _fieldDecoration(
                                  label: 'Customer / Account *',
                                  hint: 'Tap to search and select',
                                  prefixIcon: const Icon(
                                    Icons.person_search_outlined,
                                  ),
                                  suffixIcon: const Icon(Icons.search),
                                ),
                                validator: (_) => _selectedAccId == null
                                    ? 'Please select account'
                                    : null,
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _currencyDisplayCtrl,
                                readOnly: true,
                                onTap: _openCurrencyPicker,
                                decoration: _fieldDecoration(
                                  label: 'Currency / Account Type *',
                                  hint: 'Tap to search and select',
                                  prefixIcon: const Icon(
                                    Icons.currency_exchange_outlined,
                                  ),
                                  suffixIcon: const Icon(Icons.search),
                                ),
                                validator: (_) => _selectedAccTypeId == null
                                    ? 'Please select currency'
                                    : null,
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: _accountTypes.isEmpty
                                    ? Container(
                                        margin: const EdgeInsets.only(top: 10),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(
                                            alpha: 0.07,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.red.withValues(
                                              alpha: 0.25,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'No currency assigned for this account. Edit customer to assign currencies.',
                                          style: TextStyle(
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _surfaceCard(
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _descriptionCtrl,
                                decoration: _fieldDecoration(
                                  label: 'Description',
                                  hint: 'Optional',
                                  prefixIcon: const Icon(
                                    Icons.description_outlined,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _referenceCtrl,
                                decoration: _fieldDecoration(
                                  label: 'Entry Reference',
                                  prefixIcon: const Icon(Icons.tag_outlined),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _surfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Amount',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ChoiceChip(
                                    label: const Text('Debit'),
                                    selected: _entrySide == _EntrySide.debit,
                                    selectedColor: Colors.red.withValues(
                                      alpha: 0.15,
                                    ),
                                    side: BorderSide(
                                      color: _entrySide == _EntrySide.debit
                                          ? Colors.red.shade300
                                          : Colors.grey.shade300,
                                    ),
                                    onSelected: (_) =>
                                        _setEntrySide(_EntrySide.debit),
                                  ),
                                  ChoiceChip(
                                    label: const Text('Credit'),
                                    selected: _entrySide == _EntrySide.credit,
                                    selectedColor: _kEntryBlue.withValues(
                                      alpha: 0.15,
                                    ),
                                    side: BorderSide(
                                      color: _entrySide == _EntrySide.credit
                                          ? _kEntryBlue.withValues(alpha: 0.45)
                                          : Colors.grey.shade300,
                                    ),
                                    onSelected: (_) =>
                                        _setEntrySide(_EntrySide.credit),
                                  ),
                                  ActionChip(
                                    avatar: const Icon(
                                      Icons.backspace_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Clear'),
                                    onPressed: () {
                                      _debitCtrl.clear();
                                      _creditCtrl.clear();
                                    },
                                  ),
                                ],
                              ),
                              if (widget.enableQualityFields) ...[
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _qualityCtrl,
                                  focusNode: _qualityFocusNode,
                                  onChanged: _loadQualitySuggestions,
                                  onTap: () {
                                    _loadQualitySuggestions(_qualityCtrl.text);
                                  },
                                  decoration: _fieldDecoration(
                                    label: 'Product/Quality',
                                    prefixIcon: const Icon(
                                      Icons.workspace_premium_outlined,
                                    ),
                                  ),
                                ),
                                if (_showQualitySuggestions &&
                                    _qualitySuggestions.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    constraints: const BoxConstraints(
                                      maxHeight: 190,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      itemCount: _qualitySuggestions.length,
                                      separatorBuilder: (_, _) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final suggestion =
                                            _qualitySuggestions[index];
                                        return ListTile(
                                          dense: true,
                                          title: Text(suggestion),
                                          onTap: () => _applyQualitySuggestion(
                                            suggestion,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                if (isNarrow) ...[
                                  TextFormField(
                                    controller: _weightCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: _fieldDecoration(
                                      label: 'Weight/Piece',
                                      hint: 'Enter weight/piece',
                                      prefixIcon: const Icon(
                                        Icons.monitor_weight_outlined,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: _rateCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: _fieldDecoration(
                                      label: 'Rate',
                                      prefixIcon: const Icon(
                                        Icons.trending_up_outlined,
                                      ),
                                    ),
                                  ),
                                ] else
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _weightCtrl,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          decoration: _fieldDecoration(
                                            label: 'Weight/Piece',
                                            hint: 'Enter weight/piece',
                                            prefixIcon: const Icon(
                                              Icons.monitor_weight_outlined,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _rateCtrl,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          decoration: _fieldDecoration(
                                            label: 'Rate',
                                            prefixIcon: const Icon(
                                              Icons.trending_up_outlined,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                              const SizedBox(height: 10),
                              if (isNarrow) ...[
                                _amountField(
                                  controller: _debitCtrl,
                                  label: 'Debit',
                                  color: Colors.red.shade700,
                                  icon: Icons.south_west_rounded,
                                  onChanged: (v) {
                                    if (_parseAmount(v) > 0 &&
                                        _entrySide != _EntrySide.debit) {
                                      setState(
                                        () => _entrySide = _EntrySide.debit,
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(height: 10),
                                _amountField(
                                  controller: _creditCtrl,
                                  label: 'Credit',
                                  color: _kEntryBlue,
                                  icon: Icons.north_east_rounded,
                                  onChanged: (v) {
                                    if (_parseAmount(v) > 0 &&
                                        _entrySide != _EntrySide.credit) {
                                      setState(
                                        () => _entrySide = _EntrySide.credit,
                                      );
                                    }
                                  },
                                ),
                              ] else
                                Row(
                                  children: [
                                    Expanded(
                                      child: _amountField(
                                        controller: _debitCtrl,
                                        label: 'Debit',
                                        color: Colors.red.shade700,
                                        icon: Icons.south_west_rounded,
                                        onChanged: (v) {
                                          if (_parseAmount(v) > 0 &&
                                              _entrySide != _EntrySide.debit) {
                                            setState(
                                              () =>
                                                  _entrySide = _EntrySide.debit,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _amountField(
                                        controller: _creditCtrl,
                                        label: 'Credit',
                                        color: _kEntryBlue,
                                        icon: Icons.north_east_rounded,
                                        onChanged: (v) {
                                          if (_parseAmount(v) > 0 &&
                                              _entrySide != _EntrySide.credit) {
                                            setState(
                                              () => _entrySide =
                                                  _EntrySide.credit,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [100, 500, 1000, 5000]
                                    .map(
                                      (v) => ActionChip(
                                        label: Text('+ $v'),
                                        onPressed: () =>
                                            _applyQuickAmount(v.toDouble()),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _surfaceCard(
                          child: isNarrow
                              ? Column(
                                  children: [
                                    _balanceTile(
                                      label: 'Current Balance',
                                      value: _currentBalance,
                                      color: _kEntryBlue,
                                    ),
                                    const SizedBox(height: 10),
                                    _balanceTile(
                                      label: 'Projected Balance',
                                      value: _projectedBalance,
                                      color: _projectedBalance < 0
                                          ? Colors.red.shade700
                                          : _kEntryBlue,
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: _balanceTile(
                                        label: 'Current Balance',
                                        value: _currentBalance,
                                        color: _kEntryBlue,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _balanceTile(
                                        label: 'Projected Balance',
                                        value: _projectedBalance,
                                        color: _projectedBalance < 0
                                            ? Colors.red.shade700
                                            : _kEntryBlue,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _CurrencyPickerScreen extends StatefulWidget {
  final List<AccTypeData> accountTypes;
  final int? selectedAccTypeId;

  const _CurrencyPickerScreen({
    required this.accountTypes,
    required this.selectedAccTypeId,
  });

  @override
  State<_CurrencyPickerScreen> createState() => _CurrencyPickerScreenState();
}

class _CurrencyPickerScreenState extends State<_CurrencyPickerScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AccTypeData> _filteredRows() {
    final query = _searchCtrl.text.trim().toLowerCase();
    return widget.accountTypes
        .where((type) {
          if (query.isEmpty) return true;
          final id = type.accTypeId.toString();
          final name = (type.accTypeName ?? '').toLowerCase();
          final alt = (type.accTypeNameU ?? '').toLowerCase();
          return id.contains(query) ||
              name.contains(query) ||
              alt.contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredRows();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(
        title: const Text('Select Currency'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF16324B),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Color(0xFFF9FBFF)],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _kEntryBlue.withValues(alpha: 0.12)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x101862A3),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Search Currency',
                  hintText: 'Type currency name or code',
                  filled: true,
                  fillColor: _kEntrySurface,
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: _kEntryBlue,
                  ),
                  suffixIcon: _searchCtrl.text.trim().isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: _kEntryBlue.withValues(alpha: 0.12),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: _kEntryBlue.withValues(alpha: 0.12),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: _kEntryBlue,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: _kEntryBlue.withValues(alpha: 0.10),
                        ),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.currency_exchange_rounded,
                            color: _kEntryBlue,
                            size: 30,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'No currency found.',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF16324B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final selected =
                          widget.selectedAccTypeId == row.accTypeId;
                      final name = (row.accTypeName ?? '').trim();
                      final altName = (row.accTypeNameU ?? '').trim();

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => Navigator.of(context).pop(row.accTypeId),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? _kEntryBlue.withValues(alpha: 0.08)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: selected
                                    ? _kEntryBlue.withValues(alpha: 0.32)
                                    : const Color(0xFFDCE8F3),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0D1862A3),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _kEntryBlue.withValues(alpha: 0.10),
                                  ),
                                  child: const Icon(
                                    Icons.currency_exchange_rounded,
                                    color: _kEntryBlue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name.isEmpty
                                            ? 'Currency #${row.accTypeId}'
                                            : name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF16324B),
                                        ),
                                      ),
                                      if (altName.isNotEmpty &&
                                          altName.toLowerCase() !=
                                              name.toLowerCase()) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          altName,
                                          style: const TextStyle(
                                            color: Color(0xFF6F8094),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (selected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: _kEntryBlue,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AccountPickerScreen extends StatefulWidget {
  final TransactionsRepository repo;
  final int companyId;
  final int? selectedAccId;

  const _AccountPickerScreen({
    required this.repo,
    required this.companyId,
    required this.selectedAccId,
  });

  @override
  State<_AccountPickerScreen> createState() => _AccountPickerScreenState();
}

class _AccountPickerScreenState extends State<_AccountPickerScreen> {
  final _searchCtrl = TextEditingController();

  bool _isLoading = true;
  int _requestCounter = 0;
  List<AccPersonalData> _results = [];

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final currentRequest = ++_requestCounter;
    setState(() => _isLoading = true);
    try {
      final rows = await widget.repo.searchAccountsForCompany(
        companyId: widget.companyId,
        query: _searchCtrl.text,
        limit: 100,
      );

      if (!mounted || currentRequest != _requestCounter) return;
      setState(() {
        _results = rows;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || currentRequest != _requestCounter) return;
      setState(() {
        _results = const [];
        _isLoading = false;
      });
    }
  }

  String _itemLabel(AccPersonalData row) {
    final name = (row.name ?? '').trim();
    if (name.isEmpty) return 'Account #${row.accId}';
    return '$name (#${row.accId})';
  }

  Future<void> _openAddAccount() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AccountUpsertScreen(
          repo: widget.repo,
          companyId: widget.companyId,
        ),
      ),
    );
    if (changed != true) return;

    await _search();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Account added')));
  }

  Future<void> _openEditAccount(AccPersonalData row) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AccountUpsertScreen(
          repo: widget.repo,
          companyId: widget.companyId,
          existingAccount: row,
        ),
      ),
    );
    if (changed != true) return;

    await _search();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Account updated')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(
        title: const Text('Select Account / Customer'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF16324B),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Add account',
            onPressed: _openAddAccount,
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Color(0xFFF9FBFF)],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _kEntryBlue.withValues(alpha: 0.12)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x101862A3),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => _search(),
                decoration: InputDecoration(
                  labelText: 'Search by account name',
                  hintText: 'Type customer name',
                  filled: true,
                  fillColor: _kEntrySurface,
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: _kEntryBlue,
                  ),
                  suffixIcon: _searchCtrl.text.trim().isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchCtrl.clear();
                            _search();
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: _kEntryBlue.withValues(alpha: 0.12),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: _kEntryBlue.withValues(alpha: 0.12),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: _kEntryBlue,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                ? Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: _kEntryBlue.withValues(alpha: 0.10),
                        ),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_search_rounded,
                            color: _kEntryBlue,
                            size: 30,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'No account found',
                            style: TextStyle(
                              color: Color(0xFF16324B),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    itemCount: _results.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final row = _results[i];
                      final selected = row.accId == widget.selectedAccId;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => Navigator.pop(context, row),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? _kEntryBlue.withValues(alpha: 0.08)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: selected
                                    ? _kEntryBlue.withValues(alpha: 0.32)
                                    : const Color(0xFFDCE8F3),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0D1862A3),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _kEntryBlue.withValues(alpha: 0.10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      ((row.name ?? '').trim().isEmpty
                                              ? 'A'
                                              : (row.name ?? '').trim()[0])
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: _kEntryBlue,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _itemLabel(row),
                                        style: const TextStyle(
                                          color: Color(0xFF16324B),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (row.phone != null &&
                                          row.phone!.trim().isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          row.phone!.trim(),
                                          style: const TextStyle(
                                            color: Color(0xFF6F8094),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (selected)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(
                                      Icons.check_circle_rounded,
                                      color: _kEntryBlue,
                                    ),
                                  ),
                                IconButton(
                                  tooltip: 'Edit account',
                                  onPressed: () => _openEditAccount(row),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: _kEntryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AccountUpsertScreen extends StatefulWidget {
  final TransactionsRepository repo;
  final int companyId;
  final AccPersonalData? existingAccount;

  const _AccountUpsertScreen({
    required this.repo,
    required this.companyId,
    this.existingAccount,
  });

  @override
  State<_AccountUpsertScreen> createState() => _AccountUpsertScreenState();
}

enum _HeadMenuAction { add, edit, delete }

class _AccountUpsertScreenState extends State<_AccountUpsertScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _newCurrencyCtrl = TextEditingController();

  bool _isLoadingCurrencies = true;
  bool _isSaving = false;
  bool _addingCurrency = false;
  List<AccTypeData> _currencies = [];
  final Set<int> _selectedCurrencyIds = <int>{};
  List<AccountHeadOption> _heads = [];
  int? _selectedHeadId;

  bool get _isEdit => widget.existingAccount != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.existingAccount?.name ?? '';
    _phoneCtrl.text = widget.existingAccount?.phone ?? '';
    _addressCtrl.text = widget.existingAccount?.address ?? '';
    _loadCurrencies();
  }

  Future<void> _loadCurrencies() async {
    try {
      final all = await widget.repo.getAllAccTypes();
      final heads = await widget.repo.getAllAccountHeads();
      final selected = <int>{};
      int? selectedHeadId;

      final existing = widget.existingAccount;
      if (existing != null) {
        final assigned = await widget.repo.getAssignedAccTypesForAccount(
          accId: existing.accId,
          companyId: widget.companyId,
        );
        selected.addAll(assigned.map((e) => e.accTypeId));

        if (existing.chartOfAccountId != null &&
            existing.chartOfAccountId! > 0) {
          selectedHeadId = existing.chartOfAccountId;
        } else {
          final existingHeadName = (existing.statusg ?? '').trim();
          if (existingHeadName.isNotEmpty) {
            for (final head in heads) {
              if (head.accHeadName.toLowerCase() ==
                  existingHeadName.toLowerCase()) {
                selectedHeadId = head.accHeadId;
                break;
              }
            }
          }
        }
      } else {
        selected.addAll(all.map((e) => e.accTypeId));
      }

      if (!mounted) return;
      setState(() {
        _currencies = all;
        _heads = heads;
        _selectedHeadId = selectedHeadId;
        _selectedCurrencyIds
          ..clear()
          ..addAll(selected);
        _isLoadingCurrencies = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingCurrencies = false);
    }
  }

  Future<void> _addCurrencyInline() async {
    SyncViewModel? syncVm;
    try {
      syncVm = context.read<SyncViewModel>();
    } catch (_) {
      syncVm = null;
    }

    final name = _newCurrencyCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _addingCurrency = true);
    try {
      final newId = await widget.repo.createCurrencyType(currencyName: name);
      final all = await widget.repo.getAllAccTypes();
      if (!mounted) return;
      setState(() {
        _currencies = all;
        _selectedCurrencyIds.add(newId);
        _newCurrencyCtrl.clear();
      });
      if (syncVm != null) {
        unawaited(syncVm.triggerSmartSync(immediate: true, force: true));
      }
    } finally {
      if (mounted) setState(() => _addingCurrency = false);
    }
  }

  Future<void> _reloadHeads({int? preferredHeadId}) async {
    final heads = await widget.repo.getAllAccountHeads();
    var selected = preferredHeadId ?? _selectedHeadId;
    if (selected != null && !heads.any((h) => h.accHeadId == selected)) {
      selected = null;
    }
    if (!mounted) return;
    setState(() {
      _heads = heads;
      _selectedHeadId = selected;
    });
  }

  AccountHeadOption? _selectedHeadOption() {
    if (_selectedHeadId == null) return null;
    for (final h in _heads) {
      if (h.accHeadId == _selectedHeadId) return h;
    }
    return null;
  }

  Future<void> _openAddHeadScreen() async {
    final created = await Navigator.of(context).push<AccountHeadOption>(
      MaterialPageRoute(builder: (_) => _HeadUpsertScreen(repo: widget.repo)),
    );
    if (created == null) return;

    try {
      await _reloadHeads(preferredHeadId: created.accHeadId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add head: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openEditSelectedHeadScreen() async {
    final selected = _selectedHeadOption();
    if (selected == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a head first')));
      return;
    }

    final updated = await Navigator.of(context).push<AccountHeadOption>(
      MaterialPageRoute(
        builder: (_) =>
            _HeadUpsertScreen(repo: widget.repo, existingHead: selected),
      ),
    );
    if (updated == null) return;

    try {
      await _reloadHeads(preferredHeadId: updated.accHeadId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to edit head: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteSelectedHead() async {
    SyncViewModel? syncVm;
    try {
      syncVm = context.read<SyncViewModel>();
    } catch (_) {
      syncVm = null;
    }

    final selected = _selectedHeadOption();
    if (selected == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a head first')));
      return;
    }

    try {
      await widget.repo.deleteAccountHead(accHeadId: selected.accHeadId);
      await _reloadHeads();
      if (syncVm != null) {
        unawaited(syncVm.triggerSmartSync(immediate: true, force: true));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Head deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete head: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _onHeadMenuSelected(_HeadMenuAction action) async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    switch (action) {
      case _HeadMenuAction.add:
        await _openAddHeadScreen();
        break;
      case _HeadMenuAction.edit:
        await _openEditSelectedHeadScreen();
        break;
      case _HeadMenuAction.delete:
        await _deleteSelectedHead();
        break;
    }
  }

  Future<void> _save() async {
    SyncViewModel? syncVm;
    try {
      syncVm = context.read<SyncViewModel>();
    } catch (_) {
      syncVm = null;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final selectedHead = _selectedHeadOption();
    if (selectedHead == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select account head')),
      );
      return;
    }
    final headName = selectedHead.accHeadName.trim();
    if (headName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select account head')),
      );
      return;
    }
    if (_selectedCurrencyIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please assign at least one currency')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isEdit) {
        final accId = widget.existingAccount!.accId;
        await widget.repo.updateAccountBasic(
          accId: accId,
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          statusg: headName,
          chartOfAccountId: selectedHead.accHeadId,
        );
        await widget.repo.replaceAccountCurrencies(
          accId: accId,
          accTypeIds: _selectedCurrencyIds.toList(),
          companyId: widget.companyId,
        );
      } else {
        final newAccId = await widget.repo.createAccountForCompany(
          companyId: widget.companyId,
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          statusg: headName,
          chartOfAccountId: selectedHead.accHeadId,
        );
        await widget.repo.replaceAccountCurrencies(
          accId: newAccId,
          accTypeIds: _selectedCurrencyIds.toList(),
          companyId: widget.companyId,
        );
      }

      if (syncVm != null) {
        unawaited(syncVm.triggerSmartSync(immediate: true, force: true));
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save account: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _newCurrencyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Edit Account / Customer' : 'Add Account / Customer',
        ),
        backgroundColor: AppColors.white_color,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(
              'Save',
              style: TextStyle(
                color: _isSaving ? Colors.grey : AppColors.darkgreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          children: [
            if (_isSaving) const LinearProgressIndicator(minHeight: 2),
            if (_isSaving) const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey(
                      'head-${_heads.length}-${_selectedHeadId ?? 0}',
                    ),
                    initialValue: _selectedHeadId,
                    decoration: const InputDecoration(
                      labelText: 'Account Head',
                      border: OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    items: _heads
                        .map(
                          (h) => DropdownMenuItem<int>(
                            value: h.accHeadId,
                            child: Text(
                              h.accHeadName.trim().isEmpty
                                  ? 'Unnamed Head'
                                  : h.accHeadName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedHeadId = v),
                    validator: (v) =>
                        v == null ? 'Please select account head' : null,
                  ),
                ),
                PopupMenuButton<_HeadMenuAction>(
                  tooltip: 'Head actions',
                  onSelected: _onHeadMenuSelected,
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _HeadMenuAction.add,
                      child: Text('Add Head'),
                    ),
                    PopupMenuItem(
                      value: _HeadMenuAction.edit,
                      child: Text('Edit Selected Head'),
                    ),
                    PopupMenuItem(
                      value: _HeadMenuAction.delete,
                      child: Text('Delete Selected Head'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name *'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(labelText: 'Address'),
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            const Text(
              'Assign Currencies',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCurrencyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Add Currency',
                      hintText: 'e.g. USD',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addingCurrency ? null : _addCurrencyInline,
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_isLoadingCurrencies)
              const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: _currencies.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Text('No currencies available'),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _currencies.length,
                        itemBuilder: (_, i) {
                          final c = _currencies[i];
                          final id = c.accTypeId;
                          final selected = _selectedCurrencyIds.contains(id);
                          return CheckboxListTile(
                            dense: true,
                            value: selected,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              (c.accTypeName ?? '').trim().isEmpty
                                  ? 'Unnamed Currency'
                                  : c.accTypeName!,
                            ),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedCurrencyIds.add(id);
                                } else {
                                  _selectedCurrencyIds.remove(id);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Saving...' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeadUpsertScreen extends StatefulWidget {
  final TransactionsRepository repo;
  final AccountHeadOption? existingHead;

  const _HeadUpsertScreen({required this.repo, this.existingHead});

  @override
  State<_HeadUpsertScreen> createState() => _HeadUpsertScreenState();
}

class _HeadUpsertScreenState extends State<_HeadUpsertScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.existingHead != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.existingHead?.accHeadName ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    SyncViewModel? syncVm;
    try {
      syncVm = context.read<SyncViewModel>();
    } catch (_) {
      syncVm = null;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        final id = widget.existingHead!.accHeadId;
        await widget.repo.updateAccountHead(
          accHeadId: id,
          accHeadName: _nameCtrl.text.trim(),
        );
        if (syncVm != null) {
          unawaited(syncVm.triggerSmartSync(immediate: true, force: true));
        }
        if (!mounted) return;
        Navigator.pop(
          context,
          AccountHeadOption(accHeadId: id, accHeadName: _nameCtrl.text.trim()),
        );
      } else {
        final id = await widget.repo.createAccountHead(
          accHeadName: _nameCtrl.text.trim(),
        );
        if (syncVm != null) {
          unawaited(syncVm.triggerSmartSync(immediate: true, force: true));
        }
        if (!mounted) return;
        Navigator.pop(
          context,
          AccountHeadOption(accHeadId: id, accHeadName: _nameCtrl.text.trim()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save head: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Account Head' : 'Add Account Head'),
        backgroundColor: AppColors.white_color,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          children: [
            if (_saving) const LinearProgressIndicator(minHeight: 2),
            if (_saving) const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Head Name *',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Head name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving...' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
