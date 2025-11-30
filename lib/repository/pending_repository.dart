// lib/repository/pending_repository.dart
import 'package:drift/drift.dart';
import '../data/local/app_database.dart';
import '../model/pending_row.dart';

class PendingRepository {
  final AppDatabase db;
  PendingRepository(this.db);

  Future<List<PendingRow>> getPendingRows({
    required int accId,
    required int companyId,
  }) async {
    const sql = '''
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
        msgno,
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
        SUM(CASE WHEN currencystatus LIKE '%p%' THEN Dr ELSE 0 END)
        - SUM(CASE WHEN currencystatus LIKE '%np%' THEN Cr ELSE 0 END) < 0
    ORDER BY accTypeName COLLATE NOCASE ASC, beginDate ASC, voucherNo ASC;
    ''';

    final rows = await db.customSelect(
      sql,
      variables: [
        Variable.withInt(accId),
        Variable.withInt(companyId),
      ],
    ).get();

    return rows.map((e) => PendingRow.fromMap(e.data)).toList();
  }
}