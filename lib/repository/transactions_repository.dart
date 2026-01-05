import 'package:drift/drift.dart';
import 'package:flutter/cupertino.dart';
import '../data/local/app_database.dart';
import '../model/balance_currency_ui.dart';
import '../model/balance_matrix_result.dart';
import '../model/balance_row.dart';
import '../model/last_credit_row.dart';
import '../model/pending_group_row.dart';
import '../model/simple_currency_summary.dart';
import '../model/tx_filter.dart';
import '../model/tx_item_ui.dart';

class TransactionsRepository {
  final AppDatabase db;

  TransactionsRepository(this.db);

  // =========================================================
  // PENDING GROUPS (NotPaidGroupedScreen) ✅ already company scoped
  // =========================================================
  Future<List<PendingGroupRow>> getPendingGroups({
    required int accId,
    required int companyId,
    required bool showAll,
  }) async {
    const query = r"""
WITH RankedTransactions AS (
    SELECT 
        tp.VoucherNo,
        substr(tp.TDate,1,10) AS TDate,
        tp.msgno,
        tp.hwls1,
        tp.advancemess,
        tp.AccTypeID,
        tp.AccID,
        ap.Name,
        at.AccTypeName,
        tp.PD,
        tp.currencystatus,
        CAST(IFNULL(tp.Cr, 0) AS REAL) AS Cr,
        CAST(IFNULL(tp.Dr, 0) AS REAL) AS Dr
    FROM Transactions_P tp
    INNER JOIN Acc_Personal ap ON tp.AccID = ap.AccID
    INNER JOIN AccType at      ON tp.AccTypeID = at.AccTypeID
    WHERE tp.AccID = ?1
      AND tp.CompanyID = ?2
)
SELECT 
    MIN(VoucherNo) AS voucherNo,
    MIN(TDate)     AS beginDate,
    msgno          AS msgno,
    SUM(CASE WHEN currencystatus LIKE '%np%' THEN Cr ELSE 0 END) AS notPaidAmount,
    SUM(CASE WHEN currencystatus LIKE '%P%'  THEN Dr ELSE 0 END) AS paidAmount,
    SUM(CASE WHEN currencystatus LIKE '%p%'  THEN Dr ELSE 0 END)
      - SUM(CASE WHEN currencystatus LIKE '%np%' THEN Cr ELSE 0 END) AS balance,
    MAX(hwls1)        AS sender,
    MAX(advancemess)  AS receiver,
    AccTypeID         AS accTypeId,
    AccID             AS accId,
    MAX(Name)         AS name,
    MAX(AccTypeName)  AS accTypeName,
    MAX(PD)           AS pd
FROM RankedTransactions
GROUP BY msgno, AccTypeID, AccID
HAVING 
    CASE 
        WHEN ?3 = 1 THEN 1 
        ELSE (
            (SUM(CASE WHEN currencystatus LIKE '%p%' THEN Dr ELSE 0 END)
             - SUM(CASE WHEN currencystatus LIKE '%np%' THEN Cr ELSE 0 END)) < 0
        )
    END
ORDER BY accTypeName COLLATE NOCASE ASC, beginDate ASC, voucherNo ASC;
""";

    // --------------------------------------------------
    // 🔍 LOG INPUTS
    // --------------------------------------------------
    debugPrint("📌 getPendingGroups()");
    debugPrint("   accId     = $accId");
    debugPrint("   companyId = $companyId");
    debugPrint("   showAll   = $showAll");

    final result = await db.customSelect(
      query,
      variables: [
        Variable.withInt(accId),
        Variable.withInt(companyId),
        Variable.withInt(showAll ? 1 : 0),
      ],
      readsFrom: {db.transactionsP, db.accPersonal, db.accType},
    ).get();

    // --------------------------------------------------
    // 🔍 LOG RESULT COUNT
    // --------------------------------------------------
    debugPrint("✅ PendingGroup query returned ${result.length} rows");

    // --------------------------------------------------
    // 🔍 LOG FIRST FEW ROWS (VERY IMPORTANT)
    // --------------------------------------------------
    for (int i = 0; i < result.length && i < 5; i++) {
      debugPrint("🔎 Row[$i]: ${result[i].data}");
    }

    // --------------------------------------------------
    // 🔁 MAP + LOG MODEL CONVERSION
    // --------------------------------------------------
    final rows = <PendingGroupRow>[];

    for (final row in result) {
      try {
        final mapped = PendingGroupRow.fromRow(row.data);
        rows.add(mapped);
      } catch (e, s) {
        debugPrint("❌ Mapping error for row: ${row.data}");
        debugPrint("❌ Error: $e");
        debugPrintStack(stackTrace: s);
      }
    }

    debugPrint("📦 PendingGroupRow mapped count: ${rows.length}");

    return rows;
  }



  // =========================================================
  // TRANSACTIONS LIST ✅ companyId already added (keep same)
  // =========================================================
  Stream<List<TxItemUi>> watchLastTransactions({
    required int companyId,
    int limit = 100,
    String? name,
    TxFilter filter = TxFilter.all,
    String? startDate, // yyyy-MM-dd
    String? endDate,   // yyyy-MM-dd
  }) {
    final only = filter.asOnlyParam;

    const sql = r'''
      SELECT 
          t.VoucherNo                  AS voucherNo,
          substr(t.TDate,1,10)         AS date,
          COALESCE(p.Name, '')         AS name,
          t.Description                AS description,
          COALESCE(t.Dr, 0)            AS drCents,
          COALESCE(t.Cr, 0)            AS crCents,
          t.Status                     AS status,
          COALESCE(at.AccTypeName, '') AS currency
      FROM Transactions_P t
      INNER JOIN Acc_Personal p ON p.AccID = t.AccID
      INNER JOIN AccType at      ON at.AccTypeID = t.AccTypeID
      WHERE t.CompanyID = ?1
        AND (?2 IS NULL OR ?2 = '' OR p.Name LIKE '%' || ?2 || '%')
        AND (
              UPPER(?3) = 'ALL'
           OR (UPPER(?3) = 'DEBIT'  AND COALESCE(t.Dr, 0) > 0)
           OR (UPPER(?3) = 'CREDIT' AND COALESCE(t.Cr, 0) > 0)
        )
        AND (?4 IS NULL OR substr(t.TDate,1,10) >= ?4)
        AND (?5 IS NULL OR substr(t.TDate,1,10) <= ?5)
      ORDER BY t.VoucherNo DESC
      LIMIT ?6;
    ''';

    return db.customSelect(
      sql,
      variables: [
        Variable.withInt(companyId),
        (name == null || name.trim().isEmpty)
            ? const Variable(null)
            : Variable.withString(name.trim()),
        Variable.withString(only),
        startDate == null ? const Variable(null) : Variable.withString(startDate),
        endDate == null ? const Variable(null) : Variable.withString(endDate),
        Variable.withInt(limit),
      ],
      readsFrom: {db.transactionsP, db.accPersonal, db.accType},
    ).watch().map((rows) {
      return rows.map((r) => TxItemUi.fromRow(r.data)).toList();
    });
  }

  // =========================================================
  // FIND ACCID BY NAME ✅ add OPTIONAL companyId (won't break old calls)
  // =========================================================
  Future<int?> findAccIdByExactNameLoose({
    required int companyId,
    required String name,
  }) async {
    final rows = await db.customSelect(
      '''
    SELECT AccID AS accId
    FROM Acc_Personal
    WHERE CompanyID = ?1
      AND REPLACE(TRIM(Name), '  ', ' ')
          = REPLACE(TRIM(?2), '  ', ' ') COLLATE NOCASE
    LIMIT 1
    ''',
      variables: [
        Variable.withInt(companyId),
        Variable.withString(name),
      ],
      readsFrom: {db.accPersonal},
    ).get();

    if (rows.isEmpty) return null;
    return rows.first.data['accId'] as int?;
  }

  // =========================================================
  // BALANCE BY CURRENCY FOR AccID ✅ add companyId OPTIONAL
  // =========================================================
  Stream<List<BalanceCurrencyUi>> watchBalanceByCurrencyForAccId({
    required int accId,
    int? companyId,
    String? startDate,
    String? endDate,
  }) {
    final sql = (companyId == null)
        ? r'''
        SELECT 
          at.AccTypeName AS currency,
          IFNULL(SUM(CAST(t.Cr AS REAL)), 0.0) AS cr,
          IFNULL(SUM(CAST(t.Dr AS REAL)), 0.0) AS dr
        FROM Transactions_P t
        INNER JOIN AccType at ON at.AccTypeID = t.AccTypeID
        WHERE t.AccID = ?1
          AND (?2 IS NULL OR substr(t.TDate,1,10) >= ?2)
          AND (?3 IS NULL OR substr(t.TDate,1,10) <= ?3)
        GROUP BY at.AccTypeName
        ORDER BY at.AccTypeName COLLATE NOCASE ASC
      '''
        : r'''
        SELECT 
          at.AccTypeName AS currency,
          IFNULL(SUM(CAST(t.Cr AS REAL)), 0.0) AS cr,
          IFNULL(SUM(CAST(t.Dr AS REAL)), 0.0) AS dr
        FROM Transactions_P t
        INNER JOIN AccType at ON at.AccTypeID = t.AccTypeID
        WHERE t.CompanyID = ?1
          AND t.AccID = ?2
          AND (?3 IS NULL OR substr(t.TDate,1,10) >= ?3)
          AND (?4 IS NULL OR substr(t.TDate,1,10) <= ?4)
        GROUP BY at.AccTypeName
        ORDER BY at.AccTypeName COLLATE NOCASE ASC
      ''';

    final vars = (companyId == null)
        ? [
      Variable.withInt(accId),
      startDate == null ? const Variable(null) : Variable.withString(startDate),
      endDate == null ? const Variable(null) : Variable.withString(endDate),
    ]
        : [
      Variable.withInt(companyId),
      Variable.withInt(accId),
      startDate == null ? const Variable(null) : Variable.withString(startDate),
      endDate == null ? const Variable(null) : Variable.withString(endDate),
    ];

    double _fixZero(double v) => v.abs() < 0.005 ? 0.0 : v;

    return db.customSelect(
      sql,
      variables: vars,
      readsFrom: {db.transactionsP, db.accType},
    ).watch().map((rows) {
      return rows.map((row) {
        final cr = (row.data['cr'] as num?)?.toDouble() ?? 0.0;
        final dr = (row.data['dr'] as num?)?.toDouble() ?? 0.0;

        return BalanceCurrencyUi(
          currency: (row.data['currency'] as String?) ?? '',
          credit: _fixZero(cr),
          debit: _fixZero(dr),
        );
      }).toList();
    });
  }


  // =========================================================
  // ✅ RESOLVE AccTypeID BY NAME — add OPTIONAL companyId
  // (This fixes your "resolveAccTypeIdByName missing" + company safe)
  // =========================================================
  Future<int?> resolveAccTypeIdByName({
    required int companyId,
    required String currencyName,
  }) async {
    final rows = await db.customSelect(
      '''
    SELECT DISTINCT at.AccTypeID AS id
    FROM AccType at
    INNER JOIN Transactions_P tp
      ON tp.AccTypeID = at.AccTypeID
    WHERE tp.CompanyID = ?1
      AND LOWER(at.AccTypeName) = LOWER(?2)
    LIMIT 1
    ''',
      variables: [
        Variable.withInt(companyId),
        Variable.withString(currencyName),
      ],
      readsFrom: {db.accType, db.transactionsP},
    ).get();

    if (rows.isEmpty) return null;
    return rows.first.data['id'] as int?;
  }
  // =========================================================
  // BALANCE MATRIX ✅ add OPTIONAL companyId (recommended)
  // =========================================================
  Future<BalanceMatrixResult> getBalanceMatrix({int? companyId}) async {
    // ===============================
    // STEP 1: LOAD CURRENCIES
    // ===============================
    final curSql = (companyId == null)
        ? r'''
        SELECT at.AccTypeName AS cur
        FROM AccType at
        JOIN Transactions_P tp ON at.AccTypeID = tp.AccTypeID
        GROUP BY at.AccTypeName
        HAVING 
          IFNULL(SUM(CAST(tp.Cr AS REAL)),0.0) 
        - IFNULL(SUM(CAST(tp.Dr AS REAL)),0.0) <> 0
        ORDER BY at.AccTypeName COLLATE NOCASE
      '''
        : r'''
        SELECT at.AccTypeName AS cur
        FROM AccType at
        JOIN Transactions_P tp ON at.AccTypeID = tp.AccTypeID
        WHERE tp.CompanyID = ?1
        GROUP BY at.AccTypeName
        HAVING 
          IFNULL(SUM(CAST(tp.Cr AS REAL)),0.0) 
        - IFNULL(SUM(CAST(tp.Dr AS REAL)),0.0) <> 0
        ORDER BY at.AccTypeName COLLATE NOCASE
      ''';

    final curRows = await db.customSelect(
      curSql,
      variables: companyId == null ? const [] : [Variable.withInt(companyId)],
    ).get();

    List<String> currencies = curRows
        .map((r) => (r.data['cur'] as String?)?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    if (currencies.isEmpty) {
      return BalanceMatrixResult(currencies: [], rows: []);
    }

    // ===============================
    // STEP 2: LOAD RAW NET DATA
    // ===============================
    final rawSql = (companyId == null)
        ? r'''
        SELECT 
          ap.Name AS name,
          at.AccTypeName AS cur,
          IFNULL(SUM(CAST(tp.Cr AS REAL)),0.0)
        - IFNULL(SUM(CAST(tp.Dr AS REAL)),0.0) AS net
        FROM Acc_Personal ap
        LEFT JOIN Transactions_P tp ON ap.AccID = tp.AccID
        LEFT JOIN AccType at ON tp.AccTypeID = at.AccTypeID
        GROUP BY ap.Name, at.AccTypeName
        ORDER BY ap.Name COLLATE NOCASE, at.AccTypeName COLLATE NOCASE
      '''
        : r'''
        SELECT 
          ap.Name AS name,
          at.AccTypeName AS cur,
          IFNULL(SUM(CAST(tp.Cr AS REAL)),0.0)
        - IFNULL(SUM(CAST(tp.Dr AS REAL)),0.0) AS net
        FROM Acc_Personal ap
        LEFT JOIN Transactions_P tp 
          ON ap.AccID = tp.AccID
         AND tp.CompanyID = ?1
        LEFT JOIN AccType at ON tp.AccTypeID = at.AccTypeID
        GROUP BY ap.Name, at.AccTypeName
        ORDER BY ap.Name COLLATE NOCASE, at.AccTypeName COLLATE NOCASE
      ''';

    final rawRows = await db.customSelect(
      rawSql,
      variables: companyId == null ? const [] : [Variable.withInt(companyId)],
    ).get();

    double _fixZero(double v) => v.abs() < 0.005 ? 0.0 : v;

    // ===============================
    // STEP 3: PIVOT DATA (KEEP + & −)
    // ===============================
    final Map<String, Map<String, double>> pivot = {};

    for (final row in rawRows) {
      final name = (row.data['name'] as String?)?.trim();
      final cur = (row.data['cur'] as String?)?.trim();
      final net = _fixZero((row.data['net'] as num?)?.toDouble() ?? 0.0);

      if (name == null || name.isEmpty) continue;
      if (cur == null || cur.isEmpty) continue;
      if (net == 0.0) continue; // ✅ ONLY skip pure zero

      pivot.putIfAbsent(name, () => {});
      pivot[name]![cur] = net; // ✅ keep + and −
    }

    // ===============================
    // STEP 4: BUILD ROWS
    // ===============================
    final rows = pivot.entries
        .map((e) => BalanceRow(
      name: e.key,
      byCurrency: Map<String, double>.from(e.value),
    ))
        .toList()
      ..sort((a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // ===============================
    // STEP 5: CLEAN UNUSED CURRENCIES
    // ===============================
    final usedCurrencies = <String>{};
    for (final r in rows) {
      r.byCurrency.forEach((k, v) {
        if (v != 0.0) usedCurrencies.add(k);
      });
    }

    currencies = currencies.where(usedCurrencies.contains).toList();

    return BalanceMatrixResult(
      currencies: currencies,
      rows: rows,
    );
  }
  // =========================================================
  // CREDIT MATRIX ✅ add OPTIONAL companyId
  // =========================================================
  Future<BalanceMatrixResult> getCreditMatrix({int? companyId}) async {
    final curSql = (companyId == null)
        ? r'''
        SELECT at.AccTypeName AS cur
        FROM AccType at
        JOIN Transactions_P tp 
          ON at.AccTypeID = tp.AccTypeID
         AND tp.AccID != 1
        GROUP BY at.AccTypeName
        HAVING IFNULL(SUM(CAST(tp.Cr AS REAL)), 0.0) > 0
        ORDER BY at.AccTypeName COLLATE NOCASE
      '''
        : r'''
        SELECT at.AccTypeName AS cur
        FROM AccType at
        JOIN Transactions_P tp 
          ON at.AccTypeID = tp.AccTypeID
         AND tp.AccID != 1
        WHERE tp.CompanyID = ?1
        GROUP BY at.AccTypeName
        HAVING IFNULL(SUM(CAST(tp.Cr AS REAL)), 0.0) > 0
        ORDER BY at.AccTypeName COLLATE NOCASE
      ''';

    final curRows = await db.customSelect(
      curSql,
      variables: companyId == null ? const [] : [Variable.withInt(companyId)],
    ).get();

    var currencies = curRows
        .map((r) => (r.data['cur'] as String?)?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    if (currencies.isEmpty) {
      return BalanceMatrixResult(currencies: [], rows: []);
    }

    final rawSql = (companyId == null)
        ? r'''
        SELECT 
          ap.Name AS name,
          at.AccTypeName AS cur,
          IFNULL(SUM(CAST(tp.Cr AS REAL)), 0.0) AS sumCr,
          IFNULL(SUM(CAST(tp.Dr AS REAL)), 0.0) AS sumDr
        FROM Acc_Personal ap
        LEFT JOIN Transactions_P tp 
          ON ap.AccID = tp.AccID
         AND tp.AccID != 1
        LEFT JOIN AccType at ON tp.AccTypeID = at.AccTypeID
        GROUP BY ap.Name, at.AccTypeName
        ORDER BY ap.Name COLLATE NOCASE, at.AccTypeName COLLATE NOCASE
      '''
        : r'''
        SELECT 
          ap.Name AS name,
          at.AccTypeName AS cur,
          IFNULL(SUM(CAST(tp.Cr AS REAL)), 0.0) AS sumCr,
          IFNULL(SUM(CAST(tp.Dr AS REAL)), 0.0) AS sumDr
        FROM Acc_Personal ap
        LEFT JOIN Transactions_P tp 
          ON ap.AccID = tp.AccID
         AND tp.AccID != 1
         AND tp.CompanyID = ?1
        LEFT JOIN AccType at ON tp.AccTypeID = at.AccTypeID
        GROUP BY ap.Name, at.AccTypeName
        ORDER BY ap.Name COLLATE NOCASE, at.AccTypeName COLLATE NOCASE
      ''';

    final rawRows = await db.customSelect(
      rawSql,
      variables: companyId == null ? const [] : [Variable.withInt(companyId)],
    ).get();

    double _fixZero(double v) => v.abs() < 0.005 ? 0.0 : v;

    final Map<String, Map<String, double>> pivot = {};

    for (final row in rawRows) {
      final name = (row.data['name'] as String?)?.trim() ?? 'Unknown';
      final cur = (row.data['cur'] as String?)?.trim();
      final cr = (row.data['sumCr'] as num?)?.toDouble() ?? 0.0;
      final dr = (row.data['sumDr'] as num?)?.toDouble() ?? 0.0;

      final net = _fixZero(cr - dr);
      if (cur == null || cur.isEmpty || net <= 0) continue;

      pivot.putIfAbsent(name, () => {});
      pivot[name]![cur] = net;
    }

    var rows = pivot.entries
        .map((e) => BalanceRow(
      name: e.key,
      byCurrency: Map<String, double>.from(e.value),
    ))
        .where((r) => r.byCurrency.values.any((v) => v > 0))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final usedCurrencies = <String>{};
    for (final row in rows) {
      row.byCurrency.forEach((cur, v) {
        if (v > 0) usedCurrencies.add(cur);
      });
    }
    currencies = currencies.where(usedCurrencies.contains).toList();

    return BalanceMatrixResult(currencies: currencies, rows: rows);
  }
  // =========================================================
  // LEDGER (keep your existing methods)
  // ✅ add OPTIONAL companyId safely
  // =========================================================

  Future<int?> resolveAccIdExact(String name) async {
    final rows = await db.customSelect(
      '''
      SELECT AccID AS accId
      FROM Acc_Personal
      WHERE TRIM(Name) = TRIM(?1) COLLATE NOCASE
      LIMIT 1;
      ''',
      variables: [Variable.withString(name)],
    ).get();

    if (rows.isEmpty) return null;
    return rows.first.data['accId'] as int?;
  }

  Future<int?> resolveAccIdLoose(String name) async {
    final rows = await db.customSelect(
      '''
      SELECT AccID AS accId
      FROM Acc_Personal
      WHERE REPLACE(TRIM(Name), '  ', ' ')
            = REPLACE(TRIM(?1), '  ', ' ') COLLATE NOCASE
      LIMIT 1;
      ''',
      variables: [Variable.withString(name)],
    ).get();

    if (rows.isEmpty) return null;
    return rows.first.data['accId'] as int?;
  }

  Future<int?> findAccTypeIdByName(String currency) async {
    final rows = await db.customSelect(
      '''
      SELECT AccTypeID AS id
      FROM AccType
      WHERE TRIM(AccTypeName) = TRIM(?1) COLLATE NOCASE
      LIMIT 1;
      ''',
      variables: [Variable.withString(currency)],
    ).get();

    if (rows.isEmpty) return null;
    return rows.first.data['id'] as int?;
  }

  Future<double> ledgerOpeningBalance({
    int? companyId,
    required int accId,
    required int accTypeId,
    required String fromDate,
  }) async {
    final sql = (companyId == null)
        ? r'''
        SELECT IFNULL(SUM(Cr),0.0) - IFNULL(SUM(Dr),0.0) AS opening
        FROM Transactions_P
        WHERE AccID = ?1
          AND AccTypeID = ?2
          AND substr(TDate,1,10) < ?3
      '''
        : r'''
        SELECT IFNULL(SUM(Cr),0.0) - IFNULL(SUM(Dr),0.0) AS opening
        FROM Transactions_P
        WHERE CompanyID = ?1
          AND AccID = ?2
          AND AccTypeID = ?3
          AND substr(TDate,1,10) < ?4
      ''';

    final vars = (companyId == null)
        ? [
      Variable.withInt(accId),
      Variable.withInt(accTypeId),
      Variable.withString(fromDate),
    ]
        : [
      Variable.withInt(companyId),
      Variable.withInt(accId),
      Variable.withInt(accTypeId),
      Variable.withString(fromDate),
    ];

    final rows = await db.customSelect(sql, variables: vars).get();

    if (rows.isEmpty) return 0.0;

    final raw = (rows.first.data['opening'] as num?)?.toDouble() ?? 0.0;

    // 🔒 kill -0.00 noise
    return raw.abs() < 0.005 ? 0.0 : raw;
  }


  Future<List<Map<String, dynamic>>> fetchLedgerRowsRaw({
    int? companyId,
    required int accId,
    required int accTypeId,
    required String fromDate,
    required String toDate,
  }) async {
    final sql = (companyId == null)
        ? r'''
          SELECT
              t.VoucherNo            AS voucherNo,
              substr(t.TDate,1,10)   AS tDate,
              t.Description          AS description,
              IFNULL(t.Dr,0)         AS dr,
              IFNULL(t.Cr,0)         AS cr
          FROM Transactions_P t
          WHERE t.AccID = ?1
            AND t.AccTypeID = ?2
            AND t.TDate IS NOT NULL
            AND substr(t.TDate,1,10) BETWEEN ?3 AND ?4
          ORDER BY substr(t.TDate,1,10) ASC, t.VoucherNo ASC
        '''
        : r'''
          SELECT
              t.VoucherNo            AS voucherNo,
              substr(t.TDate,1,10)   AS tDate,
              t.Description          AS description,
              IFNULL(t.Dr,0)         AS dr,
              IFNULL(t.Cr,0)         AS cr
          FROM Transactions_P t
          WHERE t.CompanyID = ?1
            AND t.AccID = ?2
            AND t.AccTypeID = ?3
            AND t.TDate IS NOT NULL
            AND substr(t.TDate,1,10) BETWEEN ?4 AND ?5
          ORDER BY substr(t.TDate,1,10) ASC, t.VoucherNo ASC
        ''';

    final vars = (companyId == null)
        ? [
      Variable.withInt(accId),
      Variable.withInt(accTypeId),
      Variable.withString(fromDate),
      Variable.withString(toDate),
    ]
        : [
      Variable.withInt(companyId),
      Variable.withInt(accId),
      Variable.withInt(accTypeId),
      Variable.withString(fromDate),
      Variable.withString(toDate),
    ];

    return db.customSelect(sql, variables: vars).get().then(
          (rows) => rows.map((r) => r.data).toList(),
    );
  }

  // =========================================================
  // LAST CREDIT SUMMARY ✅ add OPTIONAL companyId
  // =========================================================
  Future<List<LastCreditRow>> getLastCreditSummary({
    int? companyId,
    required int currencyId,
  }) async {
    final sql = (companyId == null)
        ? r'''
          WITH LastCredit AS (
              SELECT AccID, AccTypeID, MAX(TDate) AS LastCreditDate
              FROM Transactions_P
              WHERE Cr > 0
              GROUP BY AccID, AccTypeID
          ),
          LastCreditSum AS (
              SELECT
                  T.AccID,
                  T.AccTypeID,
                  SUM(T.Cr) AS LastCreditAmount,
                  LC.LastCreditDate
              FROM Transactions_P AS T
              INNER JOIN LastCredit AS LC
                  ON T.AccID = LC.AccID
                  AND T.AccTypeID = LC.AccTypeID
                  AND T.TDate = LC.LastCreditDate
              GROUP BY T.AccID, T.AccTypeID, LC.LastCreditDate
          )
          SELECT
              A.AccTypeName AS CurrencyName,
              P.AccID,
              P.Name AS Customer,
              P.Address,
              T.AccTypeID AS CurrencyID,
              SUM(T.Cr - T.Dr) AS NetBalance,
              MAX(T.TDate) AS LastTransactionDate,
              CAST(julianday('now') - julianday(LC.LastCreditDate) AS INTEGER) AS DaysSinceLastCredit,
              LC.LastCreditAmount
          FROM Transactions_P AS T
          INNER JOIN Acc_Personal AS P
              ON T.AccID = P.AccID
          LEFT JOIN LastCreditSum AS LC
              ON T.AccID = LC.AccID
              AND T.AccTypeID = LC.AccTypeID
          LEFT JOIN AccType AS A
              ON T.AccTypeID = A.AccTypeID
          WHERE T.AccTypeID = ?1
          GROUP BY
              A.AccTypeName,
              P.AccID,
              P.Name,
              P.Address,
              T.AccTypeID,
              LC.LastCreditAmount,
              LC.LastCreditDate
          HAVING SUM(T.Cr - T.Dr) <> 0
             AND SUM(T.Cr - T.Dr) < 0
          ORDER BY CurrencyName, DaysSinceLastCredit DESC
        '''
        : r'''
          WITH LastCredit AS (
              SELECT AccID, AccTypeID, MAX(TDate) AS LastCreditDate
              FROM Transactions_P
              WHERE CompanyID = ?1 AND Cr > 0
              GROUP BY AccID, AccTypeID
          ),
          LastCreditSum AS (
              SELECT
                  T.AccID,
                  T.AccTypeID,
                  SUM(T.Cr) AS LastCreditAmount,
                  LC.LastCreditDate
              FROM Transactions_P AS T
              INNER JOIN LastCredit AS LC
                  ON T.AccID = LC.AccID
                  AND T.AccTypeID = LC.AccTypeID
                  AND T.TDate = LC.LastCreditDate
              WHERE T.CompanyID = ?1
              GROUP BY T.AccID, T.AccTypeID, LC.LastCreditDate
          )
          SELECT
              A.AccTypeName AS CurrencyName,
              P.AccID,
              P.Name AS Customer,
              P.Address,
              T.AccTypeID AS CurrencyID,
              SUM(T.Cr - T.Dr) AS NetBalance,
              MAX(T.TDate) AS LastTransactionDate,
              CAST(julianday('now') - julianday(LC.LastCreditDate) AS INTEGER) AS DaysSinceLastCredit,
              LC.LastCreditAmount
          FROM Transactions_P AS T
          INNER JOIN Acc_Personal AS P
              ON T.AccID = P.AccID
          LEFT JOIN LastCreditSum AS LC
              ON T.AccID = LC.AccID
              AND T.AccTypeID = LC.AccTypeID
          LEFT JOIN AccType AS A
              ON T.AccTypeID = A.AccTypeID
          WHERE T.CompanyID = ?1
            AND T.AccTypeID = ?2
          GROUP BY
              A.AccTypeName,
              P.AccID,
              P.Name,
              P.Address,
              T.AccTypeID,
              LC.LastCreditAmount,
              LC.LastCreditDate
          HAVING SUM(T.Cr - T.Dr) <> 0
             AND SUM(T.Cr - T.Dr) < 0
          ORDER BY CurrencyName, DaysSinceLastCredit DESC
        ''';

    final vars = (companyId == null)
        ? [Variable.withInt(currencyId)]
        : [Variable.withInt(companyId), Variable.withInt(currencyId)];

    final result = await db.customSelect(
      sql,
      variables: vars,
      readsFrom: {db.transactionsP, db.accPersonal, db.accType},
    ).get();

    return result.map((row) => LastCreditRow.fromRow(row.data)).toList();
  }
}