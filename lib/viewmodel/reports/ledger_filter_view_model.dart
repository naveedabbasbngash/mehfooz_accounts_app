import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../model/ledger_models.dart';
import '../../repository/transactions_repository.dart';
import '../../data/local/database_manager.dart';
import '../../services/global_state.dart';

class LedgerFilterViewModel extends ChangeNotifier {
  final TransactionsRepository _repo = TransactionsRepository(
    DatabaseManager.instance.db,
  );

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
    final rows = await DatabaseManager.instance.db
        .customSelect(
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
        )
        .get();

    currencies = rows
        .map((r) => (r.data['AccTypeName'] as String).trim())
        .where((e) => e.isNotEmpty)
        .toList();

    notifyListeners();
  }

  Future<void> loadCurrenciesForAccountName(String accountName) async {
    final name = accountName.trim();
    if (name.isEmpty) {
      currencies = [];
      notifyListeners();
      return;
    }

    final accId = await resolveAccId(name);
    if (accId == null) {
      currencies = [];
      notifyListeners();
      return;
    }

    final rows = await DatabaseManager.instance.db
        .customSelect(
          '''
      SELECT DISTINCT at.AccTypeName
      FROM Transactions_P tp
      INNER JOIN AccType at
        ON at.AccTypeID = tp.AccTypeID
      WHERE tp.CompanyID = ?1
        AND tp.AccID = ?2
        AND COALESCE(tp.IsDeleted, 0) = 0
      ORDER BY at.AccTypeName COLLATE NOCASE;
      ''',
          variables: [Variable.withInt(_companyId), Variable.withInt(accId)],
          readsFrom: {
            DatabaseManager.instance.db.transactionsP,
            DatabaseManager.instance.db.accType,
          },
        )
        .get();

    currencies = rows
        .map((r) => (r.data['AccTypeName'] as String?)?.trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

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

    final rows = await DatabaseManager.instance.db
        .customSelect(
          '''
      SELECT AccID, Name
      FROM Acc_Personal
      WHERE CompanyID = ?1
        AND Name LIKE ?2 ESCAPE '\\'
      ORDER BY Name COLLATE NOCASE
      LIMIT 25
      ''',
          variables: [Variable.withInt(_companyId), Variable.withString(like)],
          readsFrom: {DatabaseManager.instance.db.accPersonal},
        )
        .get();

    accountSuggestions = rows
        .map((r) => (r.data['Name'] as String).trim())
        .toList();

    notifyListeners();
  }

  // =========================================================
  // RESOLVE ACCOUNT ID — COMPANY SAFE
  // =========================================================
  Future<int?> resolveAccId(String name) {
    return _repo.findAccIdByExactNameLoose(companyId: _companyId, name: name);
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
    required String toDateExclusive, // yyyy-MM-dd (exclusive upper bound)
  }) async {
    final totalSw = Stopwatch()..start();
    debugPrint(
      "[LedgerPerf][VM] load:start account='$accountName' currency='$currency' "
      "from=$fromDate toExclusive=$toDateExclusive companyId=$_companyId",
    );

    loading = true;
    notifyListeners();

    final resolveSw = Stopwatch()..start();
    final accId = await resolveAccId(accountName);
    final accTypeId = await resolveAccTypeId(currency);
    resolveSw.stop();
    debugPrint(
      "[LedgerPerf][VM] resolve:done accId=$accId accTypeId=$accTypeId "
      "elapsedMs=${resolveSw.elapsedMilliseconds}",
    );

    if (accId == null || accTypeId == null) {
      loading = false;
      notifyListeners();
      totalSw.stop();
      debugPrint(
        "[LedgerPerf][VM] load:abort unresolved ids elapsedMs=${totalSw.elapsedMilliseconds}",
      );
      return null;
    }

    // -------------------------
    // OPENING BALANCE (REAL)
    // -------------------------
    final openingSw = Stopwatch()..start();
    final double opening = await _repo.ledgerOpeningBalance(
      companyId: _companyId,
      accId: accId,
      accTypeId: accTypeId,
      fromDate: fromDate,
    );
    openingSw.stop();
    debugPrint(
      "[LedgerPerf][VM] opening:done opening=$opening elapsedMs=${openingSw.elapsedMilliseconds}",
    );

    // -------------------------
    // LEDGER ROWS (REAL)
    // -------------------------
    final rowsSw = Stopwatch()..start();
    final rowsRaw = await _repo.fetchLedgerRowsRaw(
      companyId: _companyId,
      accId: accId,
      accTypeId: accTypeId,
      fromDate: fromDate,
      toDateExclusive: toDateExclusive,
    );
    rowsSw.stop();
    debugPrint(
      "[LedgerPerf][VM] rowsRaw:done count=${rowsRaw.length} elapsedMs=${rowsSw.elapsedMilliseconds}",
    );

    final mapSw = Stopwatch()..start();
    final normalizedRows = rowsRaw
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
    final rows = await compute(_mapLedgerRowsInIsolate, normalizedRows);
    mapSw.stop();
    debugPrint(
      "[LedgerPerf][VM] mapIsolate:done count=${rows.length} elapsedMs=${mapSw.elapsedMilliseconds}",
    );

    loading = false;
    notifyListeners();
    totalSw.stop();
    debugPrint(
      "[LedgerPerf][VM] load:done totalRows=${rows.length} totalElapsedMs=${totalSw.elapsedMilliseconds}",
    );

    return LedgerResult(
      openingBalance: opening.abs() < 0.005 ? 0.0 : opening,
      rows: rows,
    );
  }
}

List<LedgerTxn> _mapLedgerRowsInIsolate(List<Map<String, dynamic>> rowsRaw) {
  final dateParser = DateFormat('yyyy-MM-dd');
  double? asDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  return rowsRaw
      .map((e) {
        final d = (e['tDate'] as String?) ?? '';
        final dr = (e['dr'] as num?)?.toDouble() ?? 0.0;
        final cr = (e['cr'] as num?)?.toDouble() ?? 0.0;
        final quality = (e['quality'] as String?) ?? '';
        final rate = asDoubleOrNull(e['rate']);
        final weight = asDoubleOrNull(e['weight']);

        return LedgerTxn(
          voucherNo: "${e['voucherNo']}",
          tDate: DateTime.tryParse(d) ?? dateParser.parse(d),
          description: (e['description'] as String?) ?? '',
          quality: quality,
          rate: rate,
          weight: weight,
          dr: dr.abs() < 0.005 ? 0.0 : dr,
          cr: cr.abs() < 0.005 ? 0.0 : cr,
        );
      })
      .toList(growable: false);
}
