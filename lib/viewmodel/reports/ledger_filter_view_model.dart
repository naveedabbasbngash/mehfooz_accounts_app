import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../model/ledger_models.dart';
import '../../repository/transactions_repository.dart';
import '../../data/local/database_manager.dart';

class LedgerFilterViewModel extends ChangeNotifier {
  final _repo = TransactionsRepository(DatabaseManager.instance.db);

  List<String> currencies = [];
  List<String> accountSuggestions = [];

  bool loading = false;

  // =========================================================
  // Load currencies (same as Kotlin loadCurrencies)
  // =========================================================
  Future<void> loadCurrencies() async {
    final result = await DatabaseManager.instance.db.customSelect(
      'SELECT AccTypeName FROM AccType ORDER BY AccTypeName COLLATE NOCASE;',
    ).get();

    currencies = result
        .map((r) => (r.data['AccTypeName'] as String).trim())
        .where((e) => e.isNotEmpty)
        .toList();

    notifyListeners();
  }

  // =========================================================
  // Search accounts (like Kotlin searchAccounts)
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
      WHERE Name LIKE ?1 ESCAPE '\\'
      LIMIT 25
      ''',
      variables: [Variable.withString(like)],
    ).get();

    accountSuggestions =
        rows.map((r) => (r.data['Name'] as String).trim()).toList();

    notifyListeners();
  }

  // =========================================================
  // Resolve Account ID (Kotlin resolveAccId)
  // =========================================================
  Future<int?> resolveAccId(String name) async {
    final exact = await _repo.resolveAccIdExact(name);
    if (exact != null) return exact;

    final loose = await _repo.resolveAccIdLoose(name);
    return loose;
  }

  // =========================================================
  // Resolve Currency Type ID (Kotlin resolveAccTypeId)
  // =========================================================
  Future<int?> resolveAccTypeId(String currency) async {
    return await _repo.findAccTypeIdByName(currency);
  }

  // =========================================================
  // Fetch Ledger + Opening balance (Kotlin fetchLedgerData)
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

    final opening = await _repo.ledgerOpeningBalance(
      accId: accId,
      accTypeId: accTypeId,
      fromDate: fromDate,
    );

    final rowsRaw = await _repo.fetchLedgerRowsRaw(
      accId: accId,
      accTypeId: accTypeId,
      fromDate: fromDate,
      toDate: toDate,
    );

    final dateParser = DateFormat('yyyy-MM-dd');

    final rows = rowsRaw.map((e) {
      final d = e['tDate'] as String;
      return LedgerTxn(
        voucherNo: "${e['voucherNo']}",
        tDate: dateParser.parse(d),
        description: e['description'] ?? '',
        dr: e['dr'] as int,
        cr: e['cr'] as int,
      );
    }).toList();

    loading = false;
    notifyListeners();

    return LedgerResult(
      openingBalanceCents: opening,
      rows: rows,
    );
  }
}