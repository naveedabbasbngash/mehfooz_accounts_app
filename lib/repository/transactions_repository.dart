import 'package:drift/drift.dart';
import '../data/local/app_database.dart';
import '../model/balance_currency_ui.dart';
import '../model/balance_matrix_result.dart';
import '../model/balance_row.dart';
import '../model/pending_group_row.dart';
import '../model/simple_currency_summary.dart';
import '../model/tx_filter.dart';
import '../model/tx_item_ui.dart';

class TransactionsRepository {
  final AppDatabase db;

  TransactionsRepository(this.db);

  // =========================================================
  // PENDING GROUPS (NotPaidGroupedScreen)
  // =========================================================
  Future<List<PendingGroupRow>> getPendingGroups({
    required int accId,
    required int companyId,
    required bool showAll,
  }) async {
    const query = """
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
            CAST(tp.Cr AS INTEGER) AS Cr,
            CAST(tp.Dr AS INTEGER) AS Dr
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
                SUM(CASE WHEN currencystatus LIKE '%p%' THEN Dr ELSE 0 END)
                - SUM(CASE WHEN currencystatus LIKE '%np%' THEN Cr ELSE 0 END)
            ) < 0
        END
    ORDER BY accTypeName COLLATE NOCASE ASC, beginDate ASC, voucherNo ASC;
    """;

    // Debug logging (optional)
    // ignore: avoid_print
    print("⚡ getPendingGroups accId=$accId companyId=$companyId showAll=$showAll");

    final result = await db
        .customSelect(
      query,
      variables: [
        Variable.withInt(accId),              // ?1
        Variable.withInt(companyId),          // ?2
        Variable.withInt(showAll ? 1 : 0),    // ?3
      ],
    )
        .get();

    // ignore: avoid_print
    print("⚡ RESULT COUNT: ${result.length}");

    return result.map((row) => PendingGroupRow.fromRow(row.data)).toList();
  }

  // =========================================================
  // TRANSACTIONS LIST (for TransactionScreen)
  // =========================================================
  Stream<List<TxItemUi>> watchLastTransactions({
    int limit = 100,
    String? name,
    TxFilter filter = TxFilter.all,
    String? startDate, // yyyy-MM-dd
    String? endDate,   // yyyy-MM-dd
  }) {
    final only = filter.asOnlyParam; // "ALL" | "DEBIT" | "CREDIT"

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
      WHERE (?1 IS NULL OR ?1 = '' OR p.Name LIKE '%' || ?1 || '%')
        AND (
              UPPER(?2) = 'ALL'
           OR (UPPER(?2) = 'DEBIT'  AND COALESCE(t.Dr, 0) > 0)
           OR (UPPER(?2) = 'CREDIT' AND COALESCE(t.Cr, 0) > 0)
        )
        AND (?3 IS NULL OR substr(t.TDate,1,10) >= ?3)
        AND (?4 IS NULL OR substr(t.TDate,1,10) <= ?4)
      ORDER BY t.VoucherNo DESC
      LIMIT ?5;
    ''';

    // ignore: avoid_print
    print(
      '⚡ lastTransactions only=$only name="$name" start=$startDate end=$endDate limit=$limit',
    );

    return db
        .customSelect(
      sql,
      variables: [
        // ?1 name (nullable)
        (name == null || name.trim().isEmpty)
            ? const Variable(null)
            : Variable.withString(name.trim()),

        // ?2 filter param (ALWAYS non-null)
        Variable.withString(only),

        // ?3 startDate (nullable)
        startDate == null
            ? const Variable(null)
            : Variable.withString(startDate),

        // ?4 endDate (nullable)
        endDate == null
            ? const Variable(null)
            : Variable.withString(endDate),

        // ?5 limit
        Variable.withInt(limit),
      ],
      readsFrom: {
        db.transactionsP,
        db.accPersonal,
        db.accType,
      },
    )
        .watch()
        .map((rows) {
      final list = rows.map((r) => TxItemUi.fromRow(r.data)).toList();
      // ignore: avoid_print
      print('⚡ lastTransactions → rows=${list.length}');
      return list;
    });
  }

  // =========================================================
  // FIND ACCID BY EXACT NAME (loose)
  // =========================================================
  Future<int?> findAccIdByExactNameLoose(String name) async {
    final rows = await db.customSelect(
      '''
      SELECT AccID AS accId
      FROM Acc_Personal
      WHERE REPLACE(TRIM(Name), '  ', ' ')
            = REPLACE(TRIM(?1), '  ', ' ') COLLATE NOCASE
      LIMIT 1
      ''',
      variables: [
        Variable.withString(name),
      ],
      readsFrom: {db.accPersonal},
    ).get();

    if (rows.isEmpty) return null;
    final value = rows.first.data['accId'];
    if (value == null) return null;
    return value as int;
  }

  // =========================================================
  // BALANCE BY CURRENCY FOR AccID (Balance chip)
  // =========================================================
  Stream<List<BalanceCurrencyUi>> watchBalanceByCurrencyForAccId({
    required int accId,
    String? startDate, // yyyy-MM-dd
    String? endDate,   // yyyy-MM-dd
  }) {
    const sql = r'''
      SELECT 
        at.AccTypeName AS currency,
        IFNULL(SUM(CAST(t.Cr AS INTEGER)), 0) AS crCents,
        IFNULL(SUM(CAST(t.Dr AS INTEGER)), 0) AS drCents
      FROM Transactions_P t
      INNER JOIN AccType at ON at.AccTypeID = t.AccTypeID
      WHERE t.AccID = ?1
        AND (?2 IS NULL OR substr(t.TDate,1,10) >= ?2)
        AND (?3 IS NULL OR substr(t.TDate,1,10) <= ?3)
      GROUP BY at.AccTypeName
      ORDER BY at.AccTypeName COLLATE NOCASE ASC
    ''';

    return db
        .customSelect(
      sql,
      variables: [
        // ?1
        Variable.withInt(accId),

        // ?2 startDate (nullable)
        startDate == null
            ? const Variable(null)
            : Variable.withString(startDate),

        // ?3 endDate (nullable)
        endDate == null
            ? const Variable(null)
            : Variable.withString(endDate),
      ],
      readsFrom: {db.transactionsP, db.accType},
    )
        .watch()
        .map(
          (rows) => rows
          .map(
            (row) => BalanceCurrencyUi(
          currency: (row.data['currency'] as String?) ?? '',
          creditCents: (row.data['crCents'] as int?) ?? 0,
          debitCents: (row.data['drCents'] as int?) ?? 0,
        ),
      )
          .toList(),
    );
  }




  /// Flutter equivalent of Kotlin `queryBalancePivot()`
  Future<BalanceMatrixResult> getBalanceMatrix() async {
    // ---------------------------------------------------------
    // STEP 1 — fetch currencies with non-zero global net balance
    // ---------------------------------------------------------
    final curRows = await db.customSelect(
      '''
        SELECT at.AccTypeName AS cur
        FROM AccType at
        JOIN Transactions_P tp ON at.AccTypeID = tp.AccTypeID
        GROUP BY at.AccTypeName
        HAVING IFNULL(SUM(CAST(tp.Cr AS INTEGER)),0)
             - IFNULL(SUM(CAST(tp.Dr AS INTEGER)),0) <> 0
        ORDER BY at.AccTypeName COLLATE NOCASE
      ''',
    ).get();

    final currencies = curRows
        .map((r) => r.data['cur'] as String)
        .where((s) => s.trim().isNotEmpty)
        .toList();

    if (currencies.isEmpty) {
      return BalanceMatrixResult(currencies: [], rows: []);
    }

    // ---------------------------------------------------------
    // STEP 2 — fetch (name, currency, net = SUM(Cr - Dr))
    // ---------------------------------------------------------
    final rawRows = await db.customSelect(
      '''
        SELECT 
          ap.Name AS name,
          at.AccTypeName AS cur,
          IFNULL(SUM(CAST(tp.Cr AS INTEGER)),0)
          - IFNULL(SUM(CAST(tp.Dr AS INTEGER)),0) AS netCents
        FROM Acc_Personal ap
        LEFT JOIN Transactions_P tp ON ap.AccID = tp.AccID
        LEFT JOIN AccType at ON tp.AccTypeID = at.AccTypeID
        GROUP BY ap.Name, at.AccTypeName
        ORDER BY ap.Name COLLATE NOCASE, at.AccTypeName COLLATE NOCASE
      ''',
    ).get();

    // Map<String, Map<String, int>>
    //     name        currency  value
    final Map<String, Map<String, int>> pivot = {};

    for (final row in rawRows) {
      final name = (row.data['name'] as String?)?.trim() ?? "Unknown";
      final cur = row.data['cur'] as String?;
      final net = row.data['netCents'] as int?;

      if (cur == null || net == null || net == 0) continue;

      pivot.putIfAbsent(name, () => {});
      pivot[name]![cur] = (pivot[name]![cur] ?? 0) + net;
    }

    // Convert to BalanceRow list
    final rows = pivot.entries
        .map((e) => BalanceRow(
      name: e.key,
      byCurrency: Map<String, int>.from(e.value),
    ))
        .where((r) => r.byCurrency.values.any((v) => v != 0))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return BalanceMatrixResult(
      currencies: currencies,
      rows: rows,
    );
  }
}