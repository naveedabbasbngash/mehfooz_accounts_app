import 'package:drift/drift.dart';
import '../data/local/app_database.dart';
import '../model/cash_in_hand_row.dart';
import '../model/cash_summary_row.dart';
import '../model/pending_amount_row.dart';

class AccountRepository {
  final AppDatabase db;

  AccountRepository(this.db);

  static const String _pendingAmountSummaryQuery = """
    SELECT
      currency,
      SUM(totalCr) AS totalCr,
      SUM(totalDr) AS totalDr,
      SUM(pendingUnits) AS pendingUnits
    FROM (
      SELECT
        tp.AccTypeID,
        at.AccTypeName AS currency,
        SUM(CAST(IFNULL(tp.Cr, 0) AS REAL)) AS totalCr,
        SUM(CAST(IFNULL(tp.Dr, 0) AS REAL)) AS totalDr,
        SUM(
          CAST(IFNULL(tp.Cr, 0) AS REAL) - CAST(IFNULL(tp.Dr, 0) AS REAL)
        ) AS pendingUnits,
        tp.CompanyID
      FROM Transactions_P tp
      INNER JOIN AccType at ON tp.AccTypeID = at.AccTypeID
      WHERE tp.CompanyID = ?1
        AND tp.AccID = ?2
      GROUP BY
        tp.AccTypeID,
        at.AccTypeName,
        tp.CompanyID
      HAVING
        SUM(
          CAST(IFNULL(tp.Cr, 0) AS REAL) - CAST(IFNULL(tp.Dr, 0) AS REAL)
        ) <> 0
    ) grouped
    GROUP BY currency
    ORDER BY pendingUnits DESC;
  """;

  /// ============================================================
  /// SEARCH ACCOUNTS BY NAME (Urdu / Arabic / English supported)
  /// ============================================================
  Future<List<AccPersonalData>> searchAccountsByName(String keyword) async {
    return (db.select(db.accPersonal)
      ..where((tbl) => tbl.name.like('%$keyword%')))
        .get();
  }

  /// ============================================================
  /// GET ACCOUNTS BY COMPANY ID
  /// ============================================================
  Future<List<AccPersonalData>> getAccountsByCompany(int companyId) async {
    return (db.select(db.accPersonal)
      ..where((tbl) => tbl.companyId.equals(companyId)))
        .get();
  }

  /// ============================================================
  /// SEARCH USING NAME + COMPANY ID
  /// ============================================================
  Future<List<AccPersonalData>> searchByNameAndCompany(
      String keyword, int companyId) async {
    return (db.select(db.accPersonal)
      ..where(
            (tbl) =>
        tbl.name.like('%$keyword%') &
        tbl.companyId.equals(companyId),
      ))
        .get();
  }

  /// ============================================================
  /// GET ALL ACCOUNTS (with optional sorting)
  /// ============================================================
  Future<List<AccPersonalData>> getAllAccounts() async {
    return (db.select(db.accPersonal)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
        .get();
  }

  /// ============================================================
  /// GET ACCOUNT BY ID
  /// ============================================================
  Future<AccPersonalData?> getAccountById(int id) {
    return (db.select(db.accPersonal)
      ..where((tbl) => tbl.accId.equals(id)))
        .getSingleOrNull();
  }

  /// ============================================================
  /// GET PENDING AMOUNT SUMMARY (SNAPSHOT)
  /// ============================================================
  Future<List<PendingAmountRow>> getPendingAmountSummary({
    required int selectedCompanyId,
  }) async {
    final result = await db.customSelect(
      _pendingAmountSummaryQuery,
      variables: [
        Variable.withInt(selectedCompanyId),
        Variable.withInt(3),
      ],
    ).get();

    return result.map((row) {
      return PendingAmountRow(
        currency: row.read<String?>('currency') ?? '',
        totalCr: row.read<double?>('totalCr') ?? 0.0,
        totalDr: row.read<double?>('totalDr') ?? 0.0,
        balance: row.read<double?>('pendingUnits') ?? 0.0,
      );
    }).toList();
  }

  /// ============================================================
  /// 🔴 WATCH PENDING AMOUNT SUMMARY (NEW)
  /// ============================================================
  Stream<List<PendingAmountRow>> watchPendingAmountSummary(
      int selectedCompanyId,
      ) {
    return db.customSelect(
      _pendingAmountSummaryQuery,
      variables: [
        Variable.withInt(selectedCompanyId),
        Variable.withInt(3),
      ],
      // 🔴 THIS IS THE FIX
      readsFrom: {
        db.transactionsP,
        db.accType,
        db.accPersonal,
      },
    ).watch().map((rows) {
      return rows.map((row) {
        return PendingAmountRow(
          currency: row.read<String?>('currency') ?? '',
          totalCr: row.read<double?>('totalCr') ?? 0.0,
          totalDr: row.read<double?>('totalDr') ?? 0.0,
          balance: row.read<double?>('pendingUnits') ?? 0.0,
        );
      }).toList();
    });
  }
  /// ============================================================
  /// CASH IN HAND SUMMARY (SNAPSHOT)
  /// ============================================================
  Future<List<CashInHandRow>> getCashInHandSummary({
    required int selectedCompanyId,
  }) async {
    const query = """
    SELECT 
        T.AccTypeID,
        AT.AccTypeName AS Currency,
        SUM(T.Cr) - SUM(T.Dr) AS CashInHand,
        T.CompanyID
    FROM Transactions_P T
    INNER JOIN AccType AT 
            ON T.AccTypeID = AT.AccTypeID
    INNER JOIN Acc_Personal AP 
            ON T.AccID = AP.AccID
    WHERE
          T.AccID NOT IN (1, 1003, 1004)
          AND AP.statusg <> 'SOLAR TRANS'
          AND T.CompanyID = ?
    GROUP BY 
          T.AccTypeID,
          AT.AccTypeName,
          T.CompanyID;
  """;

    final result = await db.customSelect(
      query,
      variables: [Variable.withInt(selectedCompanyId)],
    ).get();

    return result.map((row) {
      return CashInHandRow(
        currency: row.read<String>('Currency'),
        amount: row.read<double?>('CashInHand') ?? 0.0,
      );
    }).toList();
  }

  /// ============================================================
  /// 🔴 WATCH CASH IN HAND SUMMARY (NEW)
  /// ============================================================
  Stream<List<CashInHandRow>> watchCashInHandSummary(int companyId) {
    const query = """
  SELECT 
      T.AccTypeID,
      AT.AccTypeName AS Currency,
      SUM(T.Cr) - SUM(T.Dr) AS CashInHand,
      T.CompanyID
  FROM Transactions_P T
  INNER JOIN AccType AT 
          ON T.AccTypeID = AT.AccTypeID
  INNER JOIN Acc_Personal AP 
          ON T.AccID = AP.AccID
  WHERE
        T.AccID NOT IN (1, 1003, 1004)
        AND AP.statusg <> 'SOLAR TRANS'
        AND T.CompanyID = ?
  GROUP BY 
        T.AccTypeID,
        AT.AccTypeName,
        T.CompanyID;
  """;

    return db.customSelect(
      query,
      variables: [Variable.withInt(companyId)],
      // 🔴 THIS IS THE FIX
      readsFrom: {
        db.transactionsP,
        db.accType,
        db.accPersonal,
      },
    ).watch().map((rows) {
      return rows.map((row) {
        return CashInHandRow(
          currency: row.read<String>('Currency'),
          amount: row.read<double?>('CashInHand') ?? 0.0,
        );
      }).toList();
    });
  }
  /// ============================================================
  /// ACCID = 1 CASH SUMMARY (SNAPSHOT)
  /// ============================================================
  Future<List<CashSummaryRow>> getAcc1CashSummary(int companyId) async {
    const query = """
    SELECT 
      T.AccTypeID,
      AT.AccTypeName AS Currency,
      SUM(T.Cr) - SUM(T.Dr) AS CashInHand,
      T.CompanyID
    FROM Transactions_P T
    INNER JOIN AccType AT ON T.AccTypeID = AT.AccTypeID
    INNER JOIN Acc_Personal AP ON T.AccID = AP.AccID
    WHERE
        T.AccID = 1
        AND T.CompanyID = ?
    GROUP BY 
        T.AccTypeID,
        AT.AccTypeName,
        T.CompanyID;
  """;

    final result = await db.customSelect(
      query,
      variables: [Variable.withInt(companyId)],
    ).get();

    return result.map((row) {
      return CashSummaryRow(
        currency: row.read<String>('Currency'),
        amount: row.read<double>('CashInHand'),
      );
    }).toList();
  }

  /// ============================================================
  /// 🔴 WATCH ACCID = 1 CASH SUMMARY (NEW)
  /// ============================================================
  Stream<List<CashSummaryRow>> watchAcc1CashSummary(int companyId) {
    const query = """
  SELECT 
    T.AccTypeID,
    AT.AccTypeName AS Currency,
    SUM(T.Cr) - SUM(T.Dr) AS CashInHand,
    T.CompanyID
  FROM Transactions_P T
  INNER JOIN AccType AT ON T.AccTypeID = AT.AccTypeID
  INNER JOIN Acc_Personal AP ON T.AccID = AP.AccID
  WHERE
      T.AccID = 1
      AND T.CompanyID = ?
  GROUP BY 
      T.AccTypeID,
      AT.AccTypeName,
      T.CompanyID;
  """;

    return db.customSelect(
      query,
      variables: [Variable.withInt(companyId)],
      // 🔴 THIS IS THE FIX
      readsFrom: {
        db.transactionsP,
        db.accType,
        db.accPersonal,
      },
    ).watch().map((rows) {
      return rows.map((row) {
        return CashSummaryRow(
          currency: row.read<String>('Currency'),
          amount: row.read<double>('CashInHand'),
        );
      }).toList();
    });
  }}
