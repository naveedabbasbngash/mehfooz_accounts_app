import 'package:drift/drift.dart';
import '../data/local/app_database.dart';
import '../model/cash_in_hand_row.dart';
import '../model/cash_summary_row.dart';
import '../model/pending_amount_row.dart';

class AccountRepository {
  final AppDatabase db;

  AccountRepository(this.db);

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
  /// GET PENDING AMOUNT SUMMARY (currency wise)
  /// ============================================================
  Future<List<PendingAmountRow>> getPendingAmountSummary({
    required int selectedCompanyId,
  }) async {
    const query = """
    SELECT 
      tp.AccID,
      ap.Name AS Name,
      tp.AccTypeID,
      at.AccTypeName AS currency,
      SUM(tp.Cr) AS totalCr,
      SUM(tp.Dr) AS totalDr,
      (SUM(tp.Cr) - SUM(tp.Dr)) AS pendingUnits
    FROM Transactions_P tp
    INNER JOIN AccType at 
        ON tp.AccTypeID = at.AccTypeID
    LEFT JOIN Acc_Personal ap 
        ON ap.AccID = tp.AccID
    WHERE 
        tp.CompanyID = ? 
        AND tp.AccID = ?
    GROUP BY 
        tp.AccID,
        ap.Name,
        tp.AccTypeID,
        at.AccTypeName
    HAVING 
        (SUM(tp.Cr) - SUM(tp.Dr)) <> 0
    ORDER BY 
        pendingUnits DESC;
  """;

    final result = await db.customSelect(
      query,
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
  /// CASH IN HAND SUMMARY
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
  /// ACCID = 1 CASH SUMMARY
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
}