// lib/repository/pending_repository.dart
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
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
    SELECT
        MIN(tp.VoucherNo) AS voucherNo,
        MIN(substr(tp.TDate,1,10)) AS beginDate,
        tp.msgno AS msgno,
        MAX(tp.hwls1) AS sender,
        MAX(tp.advancemess) AS receiver,
        tp.AccTypeID AS accTypeId,
        at.AccTypeName AS accTypeName,
        tp.AccID AS accId,
        SUM(COALESCE(tp.Cr,0)) AS notPaidAmount,
        SUM(COALESCE(tp.Dr,0)) AS paidAmount,
        SUM(COALESCE(tp.Cr,0) - COALESCE(tp.Dr,0)) AS balance,
        MAX(tp.PD) AS pd,
        MAX(ap.Name) AS name
    FROM Transactions_P tp
    INNER JOIN Acc_Personal ap
        ON tp.AccID = ap.AccID
    INNER JOIN AccType at
        ON tp.AccTypeID = at.AccTypeID
    WHERE tp.AccID = ?1
      AND tp.CompanyID = ?2
    GROUP BY tp.msgno, tp.AccTypeID, tp.AccID, tp.CompanyID, at.AccTypeName
    HAVING SUM(COALESCE(tp.Cr,0) - COALESCE(tp.Dr,0)) <> 0
    ORDER BY beginDate DESC, voucherNo DESC;
    ''';

    debugPrint("📌 getPendingRows() accId=$accId companyId=$companyId");

    final rows = await db.customSelect(
      sql,
      variables: [
        Variable.withInt(accId),
        Variable.withInt(companyId),
      ],
      readsFrom: {db.transactionsP, db.accPersonal, db.accType},
    ).get();

    debugPrint("✅ getPendingRows() returned ${rows.length} rows");
    for (int i = 0; i < rows.length && i < 3; i++) {
      debugPrint("🔎 pendingRow[$i] ${rows[i].data}");
    }

    return rows.map((e) => PendingRow.fromMap(e.data)).toList();
  }
}
