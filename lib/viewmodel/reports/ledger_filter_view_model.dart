import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../model/ledger_models.dart';
import '../../repository/transactions_repository.dart';
import '../../data/local/database_manager.dart';
import '../../services/global_state.dart';

class LedgerFilterViewModel extends ChangeNotifier {
  final TransactionsRepository _repo =
  TransactionsRepository(DatabaseManager.instance.db);

  // =========================================================
  // STATE
  // =========================================================
  List<String> currencies = [];
  List<String> accountSuggestions = [];

  bool loading = false;

  int get _companyId => GlobalState.instance.companyId;

  // =========================================================
  // LOAD CURRENCIES — COMPANY SCOPED
  // =========================================================
  Future<void> loadCurrencies() async {
    final rows = await DatabaseManager.instance.db.customSelect(
      '''
      SELECT DISTINCT at.AccTypeName
      FROM AccType at
      INNER JOIN Transactions_P tp
        ON tp.AccTypeID = at.AccTypeID
      WHERE tp.CompanyID = ?1
      ORDER BY at.AccTypeName COLLATE NOCASE;
      ''',
      variables: [Variable.withInt(_companyId)],
      readsFrom: {
        DatabaseManager.instance.db.accType,
        DatabaseManager.instance.db.transactionsP,
      },
    ).get();

    currencies = rows
        .map((r) => (r.data['AccTypeName'] as String).trim())
        .where((e) => e.isNotEmpty)
        .toList();

    notifyListeners();
  }

  // =========================================================
  // SEARCH ACCOUNTS — COMPANY SCOPED
  // =========================================================
  Future<void> searchAccounts(String q) async {
    if (q.trim().isEmpty) {
      accountSuggestions = [];
      notifyListeners();
      return;
    }

    final like = "%${q.trim()}%";

    final rows = await DatabaseManager.instance.db.customSelect(
      '''
      SELECT AccID, Name
      FROM Acc_Personal
      WHERE CompanyID = ?1
        AND Name LIKE ?2 ESCAPE '\\'
      ORDER BY Name COLLATE NOCASE
      LIMIT 25
      ''',
      variables: [
        Variable.withInt(_companyId),
        Variable.withString(like),
      ],
      readsFrom: {DatabaseManager.instance.db.accPersonal},
    ).get();

    accountSuggestions =
        rows.map((r) => (r.data['Name'] as String).trim()).toList();

    notifyListeners();
  }

  // =========================================================
  // RESOLVE ACCOUNT ID — COMPANY SAFE
  // =========================================================
  Future<int?> resolveAccId(String name) {
    return _repo.findAccIdByExactNameLoose(
      companyId: _companyId,
      name: name,
    );
  }

  // =========================================================
  // RESOLVE CURRENCY TYPE ID — COMPANY SAFE
  // =========================================================
  Future<int?> resolveAccTypeId(String currency) {
    return _repo.resolveAccTypeIdByName(
      companyId: _companyId,
      currencyName: currency,
    );
  }

  // =========================================================
  // LOAD LEDGER (OPENING + ROWS) — REAL / DECIMAL SAFE ✅
  // =========================================================
  Future<LedgerResult?> loadLedger({
    required String accountName,
    required String currency,
    required String fromDate, // yyyy-MM-dd
    required String toDate,   // yyyy-MM-dd
  }) async {
    loading = true;
    notifyListeners();

    final accId = await resolveAccId(accountName);
    final accTypeId = await resolveAccTypeId(currency);

    if (accId == null || accTypeId == null) {
      loading = false;
      notifyListeners();
      return null;
    }

    // -------------------------
    // OPENING BALANCE (REAL)
    // -------------------------
    final double opening = await _repo.ledgerOpeningBalance(
      companyId: _companyId,
      accId: accId,
      accTypeId: accTypeId,
      fromDate: fromDate,
    );

    // -------------------------
    // LEDGER ROWS (REAL)
    // -------------------------
    final rowsRaw = await _repo.fetchLedgerRowsRaw(
      companyId: _companyId,
      accId: accId,
      accTypeId: accTypeId,
      fromDate: fromDate,
      toDate: toDate,
    );

    final dateParser = DateFormat('yyyy-MM-dd');

    final rows = rowsRaw.map((e) {
      final d = e['tDate'] as String;

      final dr = (e['dr'] as num?)?.toDouble() ?? 0.0;
      final cr = (e['cr'] as num?)?.toDouble() ?? 0.0;

      return LedgerTxn(
        voucherNo: "${e['voucherNo']}",
        tDate: dateParser.parse(d),
        description: e['description'] ?? '',
        dr: dr.abs() < 0.005 ? 0.0 : dr,
        cr: cr.abs() < 0.005 ? 0.0 : cr,
      );
    }).toList();

    loading = false;
    notifyListeners();

    return LedgerResult(
      openingBalance: opening.abs() < 0.005 ? 0.0 : opening,
      rows: rows,
    );
  }
}