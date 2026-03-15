import 'package:drift/drift.dart';
import 'package:flutter/cupertino.dart';
import '../data/local/app_database.dart';
import '../model/balance_currency_ui.dart';
import '../model/balance_matrix_result.dart';
import '../model/balance_row.dart';
import '../model/last_credit_row.dart';
import '../model/pending_currency_summary.dart';
import '../model/pending_group_row.dart';
import '../model/pending_status_summary.dart';
import '../model/simple_currency_summary.dart';
import '../model/subgroup_balance_row.dart';
import '../model/tx_filter.dart';
import '../model/tx_item_ui.dart';

class TransactionsRepository {
  final AppDatabase db;

  TransactionsRepository(this.db);

  String _pendingStatusClause(String statusFilter) {
    switch (statusFilter.toUpperCase()) {
      case 'PAID':
        // Paid tab uses both statuses, then filters in HAVING.
        return "((tp.Status = 'Not Paid ( + )' AND tp.currencystatus = 'np') OR (tp.Status = 'Paid ( - )' AND tp.st = 'lok' AND tp.currencystatus = 'p'))";
      case 'NOTPAID':
        // Include both paid/not-paid rows so net balance per voucher is accurate.
        return "((tp.Status = 'Not Paid ( + )' AND tp.currencystatus = 'np') OR (tp.Status = 'Paid ( - )' AND tp.st = 'lok' AND tp.currencystatus = 'p'))";
      case 'ALL':
      default:
        return "((tp.Status = 'Not Paid ( + )' AND tp.currencystatus = 'np') OR (tp.Status = 'Paid ( - )' AND tp.st = 'lok' AND tp.currencystatus = 'p'))";
    }
  }

  String _pendingHavingClause(String statusFilter) {
    switch (statusFilter.toUpperCase()) {
      case 'PAID':
        return "(SUM(tp.Cr) - SUM(tp.Dr) < 0 OR (SUM(tp.Cr) - SUM(tp.Dr) > 0 AND MAX(tp.Status) = 'Paid ( - )'))";
      case 'NOTPAID':
        return "SUM(tp.Cr) - SUM(tp.Dr) > 0";
      case 'ALL':
      default:
        return "SUM(tp.Cr) - SUM(tp.Dr) <> 0";
    }
  }

  String _pendingBalanceExpr(String statusFilter) {
    if (statusFilter.toUpperCase() == 'PAID') {
      return "-SUM(tp.Dr)";
    }
    return "SUM(tp.Cr) - SUM(tp.Dr)";
  }

  String _pendingOrderByClause(String statusFilter) {
    if (statusFilter.toUpperCase() == 'ALL') {
      return "CASE WHEN SUM(tp.Cr) - SUM(tp.Dr) > 0 THEN 0 ELSE 1 END ASC, MIN(tp.TDate) DESC, MIN(tp.VoucherNo) DESC";
    }
    return "MIN(tp.TDate) DESC, MIN(tp.VoucherNo) DESC";
  }

  // =========================================================
  // PENDING BY CLICKED CURRENCY (Home pending tile tap)
  // =========================================================
  Future<List<PendingGroupRow>> getPendingByCurrencyClick({
    required int companyId,
    required String currency,
    String statusFilter = 'ALL',
  }) async {
    debugPrint(
      "📌 getPendingByCurrencyClick companyId=$companyId currency=$currency status=$statusFilter",
    );

    final statusClause = _pendingStatusClause(statusFilter);
    final havingClause = _pendingHavingClause(statusFilter);
    final balanceExpr = _pendingBalanceExpr(statusFilter);
    final orderByClause = _pendingOrderByClause(statusFilter);

    final query = """
SELECT 
    tp.hwls AS VoucherReference, 
    MIN(tp.VoucherNo) AS FirstVoucherNo, 
    MIN(substr(tp.TDate, 1, 10)) AS TDate, 
    MAX(tp.msgno) AS msgno, 
    COALESCE(
        MAX(CASE WHEN tp.Dr > 0 THEN tp.hwls1 END), 
        MAX(tp.hwls1), 
        'No Sender'
    ) AS Sender, 
    COALESCE(
        MAX(CASE WHEN tp.Cr > 0 THEN tp.advancemess END), 
        MAX(tp.advancemess), 
        'No Receiver'
    ) AS Receiver, 
    tp.AccID, 
    MAX(p.Name) AS AccountName, 
    at.AccTypeName AS Currency, 
    SUM(tp.Cr) AS Credit, 
    SUM(tp.Dr) AS Debit, 
    $balanceExpr AS Balance, 
    CASE 
        WHEN SUM(tp.Cr) - SUM(tp.Dr) > 0 THEN 'Not Paid'
        WHEN SUM(tp.Cr) - SUM(tp.Dr) < 0 THEN 'Paid'
    END AS PaymentStatus,
    tp.CompanyID,
    tp.AccTypeID
FROM Transactions_P AS tp 
LEFT JOIN Acc_Personal AS p ON tp.AccID = p.AccID 
LEFT JOIN AccType AS at ON tp.AccTypeID = at.AccTypeID
WHERE 
    tp.AccID = 3
    AND tp.hwls IS NOT NULL
    AND tp.hwls != ''
    AND (
        $statusClause
    )
    AND tp.CompanyID = ?1
    AND UPPER(at.AccTypeName) = UPPER(?2)
GROUP BY tp.hwls, tp.AccID, at.AccTypeName
HAVING $havingClause
ORDER BY $orderByClause;
""";

    final result = await db
        .customSelect(
          query,
          variables: [
            Variable.withInt(companyId),
            Variable.withString(currency),
          ],
          readsFrom: {db.transactionsP, db.accPersonal, db.accType},
        )
        .get();

    debugPrint(
      "✅ getPendingByCurrencyClick returned rows=${result.length}",
    );
    for (int i = 0; i < result.length && i < 3; i++) {
      debugPrint("🔎 clickRow[$i] ${result[i].data}");
    }

    return result.map((row) => PendingGroupRow.fromRow(row.data)).toList();
  }

  // =========================================================
  // PENDING GROUPS (NotPaidGroupedScreen) ✅ already company scoped
  // =========================================================
  Future<List<PendingGroupRow>> getPendingGroups({
    required int accId,
    required int companyId,
    String statusFilter = 'ALL',
  }) async {
    final statusClause = _pendingStatusClause(statusFilter);
    final havingClause = _pendingHavingClause(statusFilter);
    final balanceExpr = _pendingBalanceExpr(statusFilter);
    final orderByClause = _pendingOrderByClause(statusFilter);

    final query = """
SELECT 
    tp.hwls AS VoucherReference, 
    MIN(tp.VoucherNo) AS FirstVoucherNo, 
    MIN(substr(tp.TDate, 1, 10)) AS TDate, 
    MAX(tp.msgno) AS msgno, 
    COALESCE(
        MAX(CASE WHEN tp.Dr > 0 THEN tp.hwls1 END), 
        MAX(tp.hwls1), 
        'No Sender'
    ) AS Sender, 
    COALESCE(
        MAX(CASE WHEN tp.Cr > 0 THEN tp.advancemess END), 
        MAX(tp.advancemess), 
        'No Receiver'
    ) AS Receiver, 
    tp.AccID, 
    MAX(p.Name) AS AccountName, 
    at.AccTypeName AS Currency, 
    SUM(tp.Cr) AS Credit, 
    SUM(tp.Dr) AS Debit, 
    $balanceExpr AS Balance, 
    CASE 
        WHEN SUM(tp.Cr) - SUM(tp.Dr) > 0 THEN 'Not Paid'
        WHEN SUM(tp.Cr) - SUM(tp.Dr) < 0 THEN 'Paid'
    END AS PaymentStatus,
    tp.CompanyID,
    tp.AccTypeID
FROM Transactions_P AS tp 
LEFT JOIN Acc_Personal AS p ON tp.AccID = p.AccID 
LEFT JOIN AccType AS at ON tp.AccTypeID = at.AccTypeID
WHERE 
    tp.AccID = ?1
    AND tp.hwls IS NOT NULL
    AND tp.hwls != ''
    AND (
        $statusClause
    )
    AND tp.CompanyID = ?2
GROUP BY tp.hwls, tp.AccID, at.AccTypeName
HAVING $havingClause
ORDER BY $orderByClause;
""";

    // --------------------------------------------------
    // 🔍 LOG INPUTS
    // --------------------------------------------------
    debugPrint("📌 getPendingGroups()");
    debugPrint("   accId     = $accId");
    debugPrint("   companyId = $companyId");
    debugPrint("   status    = $statusFilter");

    final result = await db
        .customSelect(
          query,
          variables: [
            Variable.withInt(accId),
            Variable.withInt(companyId),
          ],
          readsFrom: {db.transactionsP, db.accPersonal, db.accType},
        )
        .get();

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

  Future<PendingStatusSummary> getPendingStatusSummary({
    required int accId,
    required int companyId,
    String? currency,
  }) async {
    final hasCurrency = currency != null && currency.trim().isNotEmpty;
    final allStatusClause = _pendingStatusClause('ALL');
    final currencyClause = hasCurrency
        ? "AND UPPER(at.AccTypeName) = UPPER(?3)"
        : "";

    final query = """
WITH grouped AS (
  SELECT
      SUM(tp.Cr) - SUM(tp.Dr) AS netBalance,
      -SUM(tp.Dr) AS paidBalance,
      MAX(tp.Status) AS maxStatus
  FROM Transactions_P AS tp
  LEFT JOIN AccType AS at ON tp.AccTypeID = at.AccTypeID
  WHERE tp.AccID = ?1
    AND tp.CompanyID = ?2
    AND tp.hwls IS NOT NULL
    AND tp.hwls != ''
    AND (
      $allStatusClause
    )
    $currencyClause
  GROUP BY tp.hwls, tp.AccID, at.AccTypeName
  HAVING SUM(tp.Cr) - SUM(tp.Dr) <> 0
)
SELECT
  COALESCE(SUM(ABS(netBalance)), 0) AS allAmount,
  COALESCE(SUM(CASE WHEN netBalance > 0 THEN netBalance ELSE 0 END), 0) AS notPaidAmount,
  COALESCE(
    SUM(
      CASE
        WHEN netBalance < 0 OR (netBalance > 0 AND maxStatus = 'Paid ( - )')
        THEN ABS(paidBalance)
        ELSE 0
      END
    ),
    0
  ) AS paidAmount,
  COUNT(*) AS allCount,
  COALESCE(SUM(CASE WHEN netBalance > 0 THEN 1 ELSE 0 END), 0) AS notPaidCount,
  COALESCE(
    SUM(
      CASE
        WHEN netBalance < 0 OR (netBalance > 0 AND maxStatus = 'Paid ( - )')
        THEN 1
        ELSE 0
      END
    ),
    0
  ) AS paidCount
FROM grouped;
""";

    final vars = <Variable>[
      Variable.withInt(accId),
      Variable.withInt(companyId),
      if (hasCurrency) Variable.withString(currency.trim()),
    ];

    final result = await db
        .customSelect(
          query,
          variables: vars,
          readsFrom: {db.transactionsP, db.accType},
        )
        .getSingleOrNull();

    if (result == null) return PendingStatusSummary.empty;

    final d = result.data;
    double toDouble(dynamic v) => (v is num) ? v.toDouble() : 0.0;
    int toInt(dynamic v) => (v is num) ? v.toInt() : 0;

    return PendingStatusSummary(
      allAmount: toDouble(d['allAmount']),
      paidAmount: toDouble(d['paidAmount']),
      notPaidAmount: toDouble(d['notPaidAmount']),
      allCount: toInt(d['allCount']),
      paidCount: toInt(d['paidCount']),
      notPaidCount: toInt(d['notPaidCount']),
    );
  }

  Future<List<PendingCurrencySummary>> getPendingStatusSummaryByCurrency({
    required int accId,
    required int companyId,
  }) async {
    final allStatusClause = _pendingStatusClause('ALL');

    final query = """
WITH grouped AS (
  SELECT
      COALESCE(NULLIF(TRIM(at.AccTypeName), ''), 'Unknown') AS currency,
      SUM(tp.Cr) - SUM(tp.Dr) AS netBalance,
      -SUM(tp.Dr) AS paidBalance,
      MAX(tp.Status) AS maxStatus
  FROM Transactions_P AS tp
  LEFT JOIN AccType AS at ON tp.AccTypeID = at.AccTypeID
  WHERE tp.AccID = ?1
    AND tp.CompanyID = ?2
    AND tp.hwls IS NOT NULL
    AND tp.hwls != ''
    AND (
      $allStatusClause
    )
  GROUP BY tp.hwls, tp.AccID, at.AccTypeName
  HAVING SUM(tp.Cr) - SUM(tp.Dr) <> 0
)
SELECT
  currency,
  COALESCE(SUM(CASE WHEN netBalance > 0 THEN netBalance ELSE 0 END), 0) AS notPaidAmount,
  COALESCE(
    SUM(
      CASE
        WHEN netBalance < 0 OR (netBalance > 0 AND maxStatus = 'Paid ( - )')
        THEN ABS(paidBalance)
        ELSE 0
      END
    ),
    0
  ) AS paidAmount
FROM grouped
GROUP BY currency
ORDER BY currency COLLATE NOCASE ASC;
""";

    final result = await db
        .customSelect(
          query,
          variables: [
            Variable.withInt(accId),
            Variable.withInt(companyId),
          ],
          readsFrom: {db.transactionsP, db.accType},
        )
        .get();

    double toDouble(dynamic v) => (v is num) ? v.toDouble() : 0.0;

    return result
        .map(
          (r) => PendingCurrencySummary(
            currency: (r.data['currency'] as String?) ?? 'Unknown',
            notPaidAmount: toDouble(r.data['notPaidAmount']),
            paidAmount: toDouble(r.data['paidAmount']),
          ),
        )
        .toList();
  }

  // =========================================================
  // SUBGROUP BALANCE (Trial Balance by Subgroup)
  // =========================================================
  Future<List<SubgroupBalanceRow>> getSubgroupBalances({
    required int companyId,
  }) async {
    const query = r"""
SELECT 
    ap.statusg AS Subgroup,
    ap.Name AS Name,
    at.AccTypeName AS Currency,
    SUM(tp.Cr - tp.Dr) AS Balance
FROM Acc_Personal AS ap
INNER JOIN Transactions_P AS tp 
    ON ap.AccID = tp.AccID
INNER JOIN AccType AS at 
    ON tp.AccTypeID = at.AccTypeID
INNER JOIN Company AS c 
    ON ap.CompanyID = c.CompanyID
WHERE  tp.CompanyID = ?1
   AND ap.AccID NOT IN (1003, 1004, 1006)
GROUP BY 
    ap.statusg,
    ap.Name,
    at.AccTypeName
ORDER BY 
    ap.statusg,
    ap.Name;
""";

    final result = await db
        .customSelect(
          query,
          variables: [Variable.withInt(companyId)],
          readsFrom: {
            db.transactionsP,
            db.accPersonal,
            db.accType,
            db.companyTable,
          },
        )
        .get();

    return result.map((row) {
      final data = row.data;
      final rawBalance = data['Balance'];
      final balance = rawBalance is num ? rawBalance.toDouble() : 0.0;
      return SubgroupBalanceRow(
        subgroup: (data['Subgroup'] as String?) ?? '',
        name: (data['Name'] as String?) ?? '',
        currency: (data['Currency'] as String?) ?? '',
        balance: balance,
      );
    }).toList();
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
    String? endDate, // yyyy-MM-dd
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

    return db
        .customSelect(
          sql,
          variables: [
            Variable.withInt(companyId),
            (name == null || name.trim().isEmpty)
                ? const Variable(null)
                : Variable.withString(name.trim()),
            Variable.withString(only),
            startDate == null
                ? const Variable(null)
                : Variable.withString(startDate),
            endDate == null
                ? const Variable(null)
                : Variable.withString(endDate),
            Variable.withInt(limit),
          ],
          readsFrom: {db.transactionsP, db.accPersonal, db.accType},
        )
        .watch()
        .map((rows) {
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
    final rows = await db
        .customSelect(
          '''
    SELECT AccID AS accId
    FROM Acc_Personal
    WHERE CompanyID = ?1
      AND REPLACE(TRIM(Name), '  ', ' ')
          = REPLACE(TRIM(?2), '  ', ' ') COLLATE NOCASE
    LIMIT 1
    ''',
          variables: [Variable.withInt(companyId), Variable.withString(name)],
          readsFrom: {db.accPersonal},
        )
        .get();

    if (rows.isEmpty) return null;
    return rows.first.data['accId'] as int?;
  }

  Future<List<String>> getAccountNameSuggestions({
    required int companyId,
    int limit = 500,
  }) async {
    final rows = await db
        .customSelect(
          '''
    SELECT DISTINCT TRIM(Name) AS name
    FROM Acc_Personal
    WHERE CompanyID = ?1
      AND TRIM(Name) <> ''
    ORDER BY Name COLLATE NOCASE
    LIMIT ?2
    ''',
          variables: [
            Variable.withInt(companyId),
            Variable.withInt(limit),
          ],
          readsFrom: {db.accPersonal},
        )
        .get();

    return rows
        .map((r) => (r.data['name'] as String?)?.trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<String>> getCompanyCurrencies({
    required int companyId,
  }) async {
    // Kept for API compatibility with callers; currencies are loaded from AccType.
    final _ = companyId;
    final rows = await db
        .customSelect(
          '''
    SELECT DISTINCT TRIM(AccTypeName) AS currency
    FROM AccType
    WHERE TRIM(AccTypeName) <> ''
    ORDER BY AccTypeName COLLATE NOCASE
    ''',
          readsFrom: {db.accType},
        )
        .get();

    return rows
        .map((r) => (r.data['currency'] as String?)?.trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
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
            startDate == null
                ? const Variable(null)
                : Variable.withString(startDate),
            endDate == null
                ? const Variable(null)
                : Variable.withString(endDate),
          ]
        : [
            Variable.withInt(companyId),
            Variable.withInt(accId),
            startDate == null
                ? const Variable(null)
                : Variable.withString(startDate),
            endDate == null
                ? const Variable(null)
                : Variable.withString(endDate),
          ];

    double _fixZero(double v) => v.abs() < 0.005 ? 0.0 : v;

    return db
        .customSelect(
          sql,
          variables: vars,
          readsFrom: {db.transactionsP, db.accType},
        )
        .watch()
        .map((rows) {
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
    final rows = await db
        .customSelect(
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
        )
        .get();

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
        WHERE tp.AccID NOT IN (1003, 1004, 1006)
        GROUP BY at.AccTypeName
        HAVING 
          IFNULL(SUM(CAST(tp.Cr AS REAL)),0.0) <> 0
          OR IFNULL(SUM(CAST(tp.Dr AS REAL)),0.0) <> 0
        ORDER BY at.AccTypeName COLLATE NOCASE
      '''
        : r'''
        SELECT at.AccTypeName AS cur
        FROM AccType at
        JOIN Transactions_P tp ON at.AccTypeID = tp.AccTypeID
        WHERE tp.CompanyID = ?1
          AND tp.AccID NOT IN (1003, 1004, 1006)
        GROUP BY at.AccTypeName
        HAVING 
          IFNULL(SUM(CAST(tp.Cr AS REAL)),0.0) <> 0
          OR IFNULL(SUM(CAST(tp.Dr AS REAL)),0.0) <> 0
        ORDER BY at.AccTypeName COLLATE NOCASE
      ''';

    final curRows = await db
        .customSelect(
          curSql,
          variables: companyId == null
              ? const []
              : [Variable.withInt(companyId)],
        )
        .get();

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
         AND tp.AccID NOT IN (1003, 1004, 1006)
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
         AND tp.AccID NOT IN (1003, 1004, 1006)
         AND tp.CompanyID = ?1
        LEFT JOIN AccType at ON tp.AccTypeID = at.AccTypeID
        GROUP BY ap.Name, at.AccTypeName
        ORDER BY ap.Name COLLATE NOCASE, at.AccTypeName COLLATE NOCASE
      ''';

    final rawRows = await db
        .customSelect(
          rawSql,
          variables: companyId == null
              ? const []
              : [Variable.withInt(companyId)],
        )
        .get();

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
    final rows =
        pivot.entries
            .map(
              (e) => BalanceRow(
                name: e.key,
                byCurrency: Map<String, double>.from(e.value),
              ),
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    return BalanceMatrixResult(currencies: currencies, rows: rows);
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

    final curRows = await db
        .customSelect(
          curSql,
          variables: companyId == null
              ? const []
              : [Variable.withInt(companyId)],
        )
        .get();

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

    final rawRows = await db
        .customSelect(
          rawSql,
          variables: companyId == null
              ? const []
              : [Variable.withInt(companyId)],
        )
        .get();

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

    var rows =
        pivot.entries
            .map(
              (e) => BalanceRow(
                name: e.key,
                byCurrency: Map<String, double>.from(e.value),
              ),
            )
            .where((r) => r.byCurrency.values.any((v) => v > 0))
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

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
    final rows = await db
        .customSelect(
          '''
      SELECT AccID AS accId
      FROM Acc_Personal
      WHERE TRIM(Name) = TRIM(?1) COLLATE NOCASE
      LIMIT 1;
      ''',
          variables: [Variable.withString(name)],
        )
        .get();

    if (rows.isEmpty) return null;
    return rows.first.data['accId'] as int?;
  }

  Future<int?> resolveAccIdLoose(String name) async {
    final rows = await db
        .customSelect(
          '''
      SELECT AccID AS accId
      FROM Acc_Personal
      WHERE REPLACE(TRIM(Name), '  ', ' ')
            = REPLACE(TRIM(?1), '  ', ' ') COLLATE NOCASE
      LIMIT 1;
      ''',
          variables: [Variable.withString(name)],
        )
        .get();

    if (rows.isEmpty) return null;
    return rows.first.data['accId'] as int?;
  }

  Future<int?> findAccTypeIdByName(String currency) async {
    final rows = await db
        .customSelect(
          '''
      SELECT AccTypeID AS id
      FROM AccType
      WHERE TRIM(AccTypeName) = TRIM(?1) COLLATE NOCASE
      LIMIT 1;
      ''',
          variables: [Variable.withString(currency)],
        )
        .get();

    if (rows.isEmpty) return null;
    return rows.first.data['id'] as int?;
  }

  Future<double> ledgerOpeningBalance({
    int? companyId,
    required int accId,
    required int accTypeId,
    required String fromDate,
  }) async {
    final sw = Stopwatch()..start();
    debugPrint(
      "[LedgerPerf][Repo] opening:start companyId=$companyId accId=$accId "
      "accTypeId=$accTypeId fromDate=$fromDate",
    );

    final sql = (companyId == null)
        ? r'''
        SELECT IFNULL(SUM(Cr),0.0) - IFNULL(SUM(Dr),0.0) AS opening
        FROM Transactions_P
        WHERE AccID = ?1
          AND AccTypeID = ?2
          AND TDate < ?3
      '''
        : r'''
        SELECT IFNULL(SUM(Cr),0.0) - IFNULL(SUM(Dr),0.0) AS opening
        FROM Transactions_P
        WHERE CompanyID = ?1
          AND AccID = ?2
          AND AccTypeID = ?3
          AND TDate < ?4
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

    if (rows.isEmpty) {
      sw.stop();
      debugPrint(
        "[LedgerPerf][Repo] opening:done empty elapsedMs=${sw.elapsedMilliseconds}",
      );
      return 0.0;
    }

    final raw = (rows.first.data['opening'] as num?)?.toDouble() ?? 0.0;
    sw.stop();
    debugPrint(
      "[LedgerPerf][Repo] opening:done value=$raw elapsedMs=${sw.elapsedMilliseconds}",
    );

    // 🔒 kill -0.00 noise
    return raw.abs() < 0.005 ? 0.0 : raw;
  }

  Future<List<Map<String, dynamic>>> fetchLedgerRowsRaw({
    int? companyId,
    required int accId,
    required int accTypeId,
    required String fromDate,
    required String toDateExclusive,
  }) async {
    final sw = Stopwatch()..start();
    debugPrint(
      "[LedgerPerf][Repo] rows:start companyId=$companyId accId=$accId "
      "accTypeId=$accTypeId from=$fromDate toExclusive=$toDateExclusive",
    );

    final sql = (companyId == null)
        ? r'''
          SELECT
              t.VoucherNo            AS voucherNo,
              t.TDate                AS tDate,
              t.Description          AS description,
              IFNULL(t.Dr,0)         AS dr,
              IFNULL(t.Cr,0)         AS cr
          FROM Transactions_P t
          WHERE t.AccID = ?1
            AND t.AccTypeID = ?2
            AND t.TDate IS NOT NULL
            AND t.TDate >= ?3
            AND t.TDate < ?4
          ORDER BY t.TDate ASC, t.VoucherNo ASC
        '''
        : r'''
          SELECT
              t.VoucherNo            AS voucherNo,
              t.TDate                AS tDate,
              t.Description          AS description,
              IFNULL(t.Dr,0)         AS dr,
              IFNULL(t.Cr,0)         AS cr
          FROM Transactions_P t
          WHERE t.CompanyID = ?1
            AND t.AccID = ?2
            AND t.AccTypeID = ?3
            AND t.TDate IS NOT NULL
            AND t.TDate >= ?4
            AND t.TDate < ?5
          ORDER BY t.TDate ASC, t.VoucherNo ASC
        ''';

    final vars = (companyId == null)
        ? [
            Variable.withInt(accId),
            Variable.withInt(accTypeId),
            Variable.withString(fromDate),
            Variable.withString(toDateExclusive),
          ]
        : [
            Variable.withInt(companyId),
            Variable.withInt(accId),
            Variable.withInt(accTypeId),
            Variable.withString(fromDate),
            Variable.withString(toDateExclusive),
          ];

    final out = await db
        .customSelect(sql, variables: vars)
        .get()
        .then((rows) => rows.map((r) => r.data).toList());
    sw.stop();
    debugPrint(
      "[LedgerPerf][Repo] rows:done count=${out.length} elapsedMs=${sw.elapsedMilliseconds}",
    );
    return out;
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

    final result = await db
        .customSelect(
          sql,
          variables: vars,
          readsFrom: {db.transactionsP, db.accPersonal, db.accType},
        )
        .get();

    return result.map((row) => LastCreditRow.fromRow(row.data)).toList();
  }
}
