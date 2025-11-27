import 'dart:async';
import 'package:flutter/material.dart';

import '../model/tx_filter.dart';
import '../model/tx_item_ui.dart';
import '../model/balance_currency_ui.dart';
import '../repository/transactions_repository.dart';

class TransactionsViewModel extends ChangeNotifier {
  final TransactionsRepository repo;

  TransactionsViewModel({required this.repo}) {
    _setupAutoResetListeners();
    _reloadItems();
    _updateSelectedAccIdFromSearch();
    _reloadBalance();
  }

  /* -----------------------------------------------------
   * PRIVATE STATE
   * ----------------------------------------------------- */
  String _search = "";
  TxFilter _filter = TxFilter.all;

  String? _startDate; // yyyy-MM-dd
  String? _endDate;

  String? _selectedCurrency;
  int? _selectedAccId;

  List<TxItemUi> _items = [];
  List<String> _currencies = [];

  List<BalanceCurrencyUi> _balanceByCurrency = [];

  StreamSubscription? _itemsSub;
  StreamSubscription? _balanceSub;

  /* -----------------------------------------------------
   * PUBLIC GETTERS — USED IN UI
   * ----------------------------------------------------- */

  String get search => _search;
  TxFilter get filter => _filter;

  String? get selectedCurrency => _selectedCurrency;
  List<String> get currencies => _currencies;

  List<TxItemUi> get items => _items;

  int? get selectedAccId => _selectedAccId;
  List<BalanceCurrencyUi> get balanceByCurrency => _balanceByCurrency;

  String? get startDate => _startDate;
  String? get endDate => _endDate;

  // --------------------------
  // DATE CHIP LABEL (Google style)
  // --------------------------
  String get dateLabel {
    if (_startDate == null && _endDate == null) return "Dates";
    if (_startDate != null && _endDate == null) return _startDate!;
    if (_startDate != null && _endDate != null) {
      if (_startDate == _endDate) return _startDate!;
      return "$_startDate → $_endDate";
    }
    return "Dates";
  }

  // For date picker chip
  String get formattedDateRange => dateLabel;

  /* -----------------------------------------------------
   * SEARCH SUGGESTIONS
   * ----------------------------------------------------- */
  List<String> get suggestions {
    return _items
        .map((e) => e.name ?? "")
        .where((n) => n.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  /* -----------------------------------------------------
   * SETTERS
   * ----------------------------------------------------- */

  void setSearch(String v) {
    _search = v.trim();
    notifyListeners();
    _reloadItems();
    _updateSelectedAccIdFromSearch();
  }

  void setFilter(TxFilter f) {
    _filter = f;
    notifyListeners();
    _reloadItems();
    // Note: balance mode does NOT use _filter, list only
  }

  void setDateRange(String? start, String? end) {
    _startDate = start;
    _endDate = end;

    notifyListeners();
    _reloadItems();
    _reloadBalance();
  }

  void clearDateRange() {
    _startDate = null;
    _endDate = null;
    notifyListeners();
    _reloadItems();
    _reloadBalance();
  }

  void setSelectedCurrency(String? cur) {
    _selectedCurrency = cur;
    notifyListeners();
    _reloadItems();
  }

  /* -----------------------------------------------------
   * AUTO RESET WHEN SEARCH CLEARS
   * ----------------------------------------------------- */
  void _setupAutoResetListeners() {
    if (_search.isEmpty) {
      _selectedCurrency = null;
      _selectedAccId = null;
    }
  }

  /* -----------------------------------------------------
   * TRANSACTION LIST FLOW
   * ----------------------------------------------------- */
  void _reloadItems() {
    _itemsSub?.cancel();

    _itemsSub = repo
        .watchLastTransactions(
      limit: 100,
      name: _search.isEmpty ? null : _search,
      filter: _filter,
      startDate: _startDate,
      endDate: _endDate,
    )
        .listen((list) {
      // Apply currency filter
      final filtered = (_selectedCurrency == null)
          ? list
          : list
          .where((e) =>
      (e.currency ?? "")
          .toLowerCase() ==
          _selectedCurrency!.toLowerCase())
          .toList();

      _items = filtered;

      // Currency list
      _currencies = list
          .map((e) => e.currency ?? "")
          .where((e) => e.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      notifyListeners();
    });
  }

  /* -----------------------------------------------------
   * BALANCE FLOW (only when selectedAccId != null)
   * ----------------------------------------------------- */
  void _reloadBalance() {
    _balanceSub?.cancel();

    if (_selectedAccId == null) {
      _balanceByCurrency = [];
      notifyListeners();
      return;
    }

    _balanceSub = repo
        .watchBalanceByCurrencyForAccId(
      accId: _selectedAccId!,
      startDate: _startDate,
      endDate: _endDate,
    )
        .listen((rows) {
      _balanceByCurrency = rows;
      notifyListeners();
    });
  }

  /* -----------------------------------------------------
   * UPDATE selectedAccId BASED ON SEARCH
   * (same behaviour as Kotlin: find ID by exact name)
   * ----------------------------------------------------- */
  Future<void> _updateSelectedAccIdFromSearch() async {
    if (_search.isEmpty) {
      _selectedAccId = null;
      _balanceByCurrency = [];
      notifyListeners();
      return;
    }

    final id = await repo.findAccIdByExactNameLoose(_search);
    _selectedAccId = id;
    _reloadBalance();
  }

  @override
  void dispose() {
    _itemsSub?.cancel();
    _balanceSub?.cancel();
    super.dispose();
  }
}