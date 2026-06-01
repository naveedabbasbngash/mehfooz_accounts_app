// lib/repository/sync_repository.dart
import 'package:drift/drift.dart';
import 'package:logger/logger.dart';

import '../../data/local/app_database.dart';
import '../../model/SyncResult.dart';
import '../../services/company_tombstone_store.dart';
import '../../services/sync/sync_service.dart';

class PendingSyncChange {
  final int companyId;
  final int voucherNo;
  final String txGuid;
  final Map<String, dynamic> payload;

  const PendingSyncChange({
    required this.companyId,
    required this.voucherNo,
    required this.txGuid,
    required this.payload,
  });
}

class PendingMasterChange {
  final int companyId;
  final int rowId;
  final Map<String, dynamic> payload;

  const PendingMasterChange({
    required this.companyId,
    required this.rowId,
    required this.payload,
  });
}

class SyncRepository {
  final AppDatabase db;
  final Logger _log = Logger();

  SyncRepository(this.db);

  Future<bool> hasUnsyncedLocalChanges() async {
    Future<bool> existsUnsyncedInTable(String tableName) async {
      final rows = await db.customSelect('''
        SELECT 1
        FROM $tableName
        WHERE COALESCE(IsSynced, 0) = 0
        LIMIT 1
        ''').get();
      return rows.isNotEmpty;
    }

    if (await existsUnsyncedInTable('Transactions_P')) return true;
    if (await existsUnsyncedInTable('Acc_Personal')) return true;
    if (await existsUnsyncedInTable('AccType')) return true;
    if (await existsUnsyncedInTable('Account_PCurrencyAssignment')) return true;
    if (await existsUnsyncedInTable('AccountHeads')) return true;
    if (await existsUnsyncedInTable('AccountSubHeads')) return true;
    if (await existsUnsyncedInTable('ChartOfAccounts')) return true;
    return false;
  }

  // ============================================================
  // APPLY FULL BATCH
  // ============================================================
  Future<SyncResult> applyBatch(SyncBatch batch) async {
    _log.i("🔄 [SyncRepository] Applying batch ${batch.batchId}");

    int inserted = 0;
    int updated = 0;
    int deleted = 0;

    try {
      await db.transaction(() async {
        final r0 = await _applyCompanies(batch.companies);
        final r1 = await _applyAccTypes(batch.accTypes);
        final r2 = await _applyAccPersonal(batch.accPersonal);
        final r3 = await _applyAssignments(batch.assignments);
        final r4 = await _applyTransactions(batch.transactions);
        final r5 = await _dedupeCompaniesByName();

        inserted +=
            r0.inserted +
            r1.inserted +
            r2.inserted +
            r3.inserted +
            r4.inserted +
            r5.inserted;
        updated +=
            r0.updated +
            r1.updated +
            r2.updated +
            r3.updated +
            r4.updated +
            r5.updated;
        deleted +=
            r0.deleted +
            r1.deleted +
            r2.deleted +
            r3.deleted +
            r4.deleted +
            r5.deleted;
      });

      _log.i(
        "✅ [SyncRepository] Batch applied "
        "(+$inserted added, $updated updated, $deleted deleted)",
      );

      return SyncResult(inserted: inserted, updated: updated, deleted: deleted);
    } catch (e, st) {
      _log.e("❌ [SyncRepository] Failed batch", error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<PendingSyncChange>> collectUnsyncedTransactionChanges({
    int limit = 500,
  }) async {
    final rows = await db
        .customSelect(
          '''
          SELECT
            VoucherNo, TxGuid, TDate, AccID, AccTypeID, Description, Quality, Rate, Weight,
            Dr, Cr, Status, st, updatestatus, currencystatus, cashstatus,
            UserID, CompanyID, WName, msgno, hwls1, hwls, advancemess,
            cbal, cbal1, TTIME, PD, msgno2, OTHERS, IsSynced, UpdatedAt, IsDeleted
          FROM Transactions_P
          WHERE COALESCE(IsSynced, 0) = 0
            AND CompanyID IS NOT NULL
          ORDER BY COALESCE(UpdatedAt, TDate, '') ASC, VoucherNo ASC
          LIMIT ?1
          ''',
          variables: [Variable.withInt(limit)],
          readsFrom: {db.transactionsP},
        )
        .get();

    final output = <PendingSyncChange>[];
    for (final row in rows) {
      final voucherNo = _toInt(row.data['VoucherNo']);
      final companyId = _toInt(row.data['CompanyID']);
      if (voucherNo <= 0 || companyId <= 0) continue;
      var txGuid = _cleanGuid(row.data['TxGuid']);
      if (txGuid.isEmpty) {
        txGuid = _legacyTxGuid(companyId, voucherNo);
        await db.customStatement(
          '''
          UPDATE Transactions_P
          SET TxGuid = ?1
          WHERE VoucherNo = ?2
            AND CompanyID = ?3
            AND COALESCE(TRIM(TxGuid), '') = ''
          ''',
          [txGuid, voucherNo, companyId],
        );
      }

      final isDeleted = _toInt(row.data['IsDeleted']) == 1;

      final payload = <String, dynamic>{
        'table': 'Transactions_P',
        'operation': isDeleted ? 'DELETE' : 'UPSERT',
        'pkName': 'TxGuid',
        'pkValue': txGuid,
        'data': <String, dynamic>{
          'TxGuid': txGuid,
          'VoucherNo': voucherNo,
          'TDate': _txt(row.data['TDate']),
          'AccID': _toIntOrNull(row.data['AccID']),
          'AccTypeID': _toIntOrNull(row.data['AccTypeID']),
          'Description': _txt(row.data['Description']),
          'Quality': _txt(row.data['Quality']),
          'Rate': _toDoubleOrNull(row.data['Rate']),
          'Weight': _toDoubleOrNull(row.data['Weight']),
          'Dr': _toDoubleOrNull(row.data['Dr']),
          'Cr': _toDoubleOrNull(row.data['Cr']),
          'Status': _txt(row.data['Status']),
          'st': _txt(row.data['st']),
          'updatestatus': _txt(row.data['updatestatus']),
          'currencystatus': _txt(row.data['currencystatus']),
          'cashstatus': _txt(row.data['cashstatus']),
          'UserID': _toIntOrNull(row.data['UserID']),
          'CompanyID': companyId,
          'WName': _txt(row.data['WName']),
          'msgno': _txt(row.data['msgno']),
          'hwls1': _txt(row.data['hwls1']),
          'hwls': _txt(row.data['hwls']),
          'advancemess': _txt(row.data['advancemess']),
          'cbal': _toIntOrNull(row.data['cbal']),
          'cbal1': _toIntOrNull(row.data['cbal1']),
          'TTIME': _txt(row.data['TTIME']),
          'PD': _txt(row.data['PD']),
          'msgno2': _txt(row.data['msgno2']),
          'OTHERS': _txt(row.data['OTHERS']),
          'IsSynced': _toInt(row.data['IsSynced']),
          'UpdatedAt': _txt(row.data['UpdatedAt']),
          'IsDeleted': _toInt(row.data['IsDeleted']),
        },
      };

      output.add(
        PendingSyncChange(
          companyId: companyId,
          voucherNo: voucherNo,
          txGuid: txGuid,
          payload: payload,
        ),
      );
    }

    return output;
  }

  Future<int> markTransactionsSynced({
    required int companyId,
    required List<String> txGuids,
  }) async {
    final cleaned = txGuids
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (cleaned.isEmpty) return 0;

    return (db.update(
          db.transactionsP,
        )..where((t) => t.companyId.equals(companyId) & t.txGuid.isIn(cleaned)))
        .write(const TransactionsPCompanion(isSynced: Value(1)));
  }

  Future<int> countUnsyncedTransactions() async {
    final row = await db
        .customSelect(
          '''
          SELECT COUNT(*) AS c
          FROM Transactions_P
          WHERE COALESCE(IsSynced, 0) = 0
          ''',
          readsFrom: {db.transactionsP},
        )
        .getSingle();
    return _toInt(row.data['c']);
  }

  Future<int> countUnsyncedCoreChanges() async {
    final tx = await countUnsyncedTransactions();

    final rowAccounts = await db
        .customSelect(
          '''
          SELECT COUNT(*) AS c
          FROM Acc_Personal
          WHERE COALESCE(IsSynced, 0) = 0
          ''',
          readsFrom: {db.accPersonal},
        )
        .getSingle();
    final accounts = _toInt(rowAccounts.data['c']);

    final rowCurrencies = await db
        .customSelect(
          '''
          SELECT COUNT(*) AS c
          FROM AccType
          WHERE COALESCE(IsSynced, 0) = 0
          ''',
          readsFrom: {db.accType},
        )
        .getSingle();
    final currencies = _toInt(rowCurrencies.data['c']);

    return tx + accounts + currencies;
  }

  Future<int> resolveDefaultCompanyId() async {
    final fromCompany = await db
        .customSelect(
          '''
          SELECT CompanyID
          FROM Company
          WHERE CompanyID IS NOT NULL
          ORDER BY CompanyID ASC
          LIMIT 1
          ''',
          readsFrom: {db.companyTable},
        )
        .get();
    if (fromCompany.isNotEmpty) {
      final id = _toInt(fromCompany.first.data['CompanyID']);
      if (id > 0) return id;
    }

    final fromAcc = await db
        .customSelect(
          '''
          SELECT CompanyID
          FROM Acc_Personal
          WHERE CompanyID IS NOT NULL
          ORDER BY CompanyID ASC
          LIMIT 1
          ''',
          readsFrom: {db.accPersonal},
        )
        .get();
    if (fromAcc.isNotEmpty) {
      final id = _toInt(fromAcc.first.data['CompanyID']);
      if (id > 0) return id;
    }

    final fromTx = await db
        .customSelect(
          '''
          SELECT CompanyID
          FROM Transactions_P
          WHERE CompanyID IS NOT NULL
          ORDER BY CompanyID ASC
          LIMIT 1
          ''',
          readsFrom: {db.transactionsP},
        )
        .get();
    if (fromTx.isNotEmpty) {
      final id = _toInt(fromTx.first.data['CompanyID']);
      if (id > 0) return id;
    }

    return 1;
  }

  Future<List<PendingMasterChange>> collectUnsyncedAccTypeChanges({
    required int fallbackCompanyId,
    int limit = 300,
  }) async {
    final rows = await db
        .customSelect(
          '''
          SELECT AccTypeID, AccTypeName, AccTypeNameu, FLAG, IsDeleted, IsSynced, UpdatedAt
          FROM AccType
          WHERE COALESCE(IsSynced, 0) = 0
          ORDER BY COALESCE(UpdatedAt, '') ASC, AccTypeID ASC
          LIMIT ?1
          ''',
          variables: [Variable.withInt(limit)],
          readsFrom: {db.accType},
        )
        .get();

    final output = <PendingMasterChange>[];
    for (final row in rows) {
      final accTypeId = _toInt(row.data['AccTypeID']);
      if (accTypeId <= 0) continue;
      final isDeleted = _toInt(row.data['IsDeleted']) == 1;

      output.add(
        PendingMasterChange(
          companyId: fallbackCompanyId,
          rowId: accTypeId,
          payload: <String, dynamic>{
            'table': 'AccType',
            'operation': isDeleted ? 'DELETE' : 'UPSERT',
            'pkName': 'AccTypeID',
            'pkValue': accTypeId,
            'data': <String, dynamic>{
              'AccTypeID': accTypeId,
              'AccTypeName': _txt(row.data['AccTypeName']),
              'AccTypeNameu': _txt(row.data['AccTypeNameu']),
              'FLAG': _txt(row.data['FLAG']),
              'IsDeleted': _toInt(row.data['IsDeleted']),
              'IsSynced': _toInt(row.data['IsSynced']),
              'UpdatedAt': _txt(row.data['UpdatedAt']),
            },
          },
        ),
      );
    }

    return output;
  }

  Future<List<PendingMasterChange>> collectAccTypeSnapshotByIds({
    required int fallbackCompanyId,
    required List<int> accTypeIds,
    int limit = 600,
  }) async {
    final ids = accTypeIds
        .where((id) => id > 0)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) return const <PendingMasterChange>[];

    final rows = await db
        .customSelect(
          '''
          SELECT AccTypeID, AccTypeName, AccTypeNameu, FLAG, IsDeleted, IsSynced, UpdatedAt
          FROM AccType
          WHERE AccTypeID IN (${List.filled(ids.length, '?').join(',')})
          ORDER BY AccTypeID ASC
          LIMIT ?${ids.length + 1}
          ''',
          variables: [...ids.map(Variable.withInt), Variable.withInt(limit)],
          readsFrom: {db.accType},
        )
        .get();

    final output = <PendingMasterChange>[];
    for (final row in rows) {
      final accTypeId = _toInt(row.data['AccTypeID']);
      if (accTypeId <= 0) continue;
      final isDeleted = _toInt(row.data['IsDeleted']) == 1;

      output.add(
        PendingMasterChange(
          companyId: fallbackCompanyId,
          rowId: accTypeId,
          payload: <String, dynamic>{
            'table': 'AccType',
            'operation': isDeleted ? 'DELETE' : 'UPSERT',
            'pkName': 'AccTypeID',
            'pkValue': accTypeId,
            'data': <String, dynamic>{
              'AccTypeID': accTypeId,
              'AccTypeName': _txt(row.data['AccTypeName']),
              'AccTypeNameu': _txt(row.data['AccTypeNameu']),
              'FLAG': _txt(row.data['FLAG']),
              'IsDeleted': _toInt(row.data['IsDeleted']),
              'IsSynced': _toInt(row.data['IsSynced']),
              'UpdatedAt': _txt(row.data['UpdatedAt']),
            },
          },
        ),
      );
    }

    return output;
  }

  Future<List<PendingMasterChange>> collectUnsyncedAccPersonalChanges({
    int limit = 600,
  }) async {
    final rows = await db
        .customSelect(
          '''
          SELECT
            AccID, RDate, Name, Phone, Fax, Address, Description, UAccName, statusg,
            UserID, CompanyID, ChartOfAccountID, WName, IsSynced, UpdatedAt, IsDeleted
          FROM Acc_Personal
          WHERE COALESCE(IsSynced, 0) = 0
            AND CompanyID IS NOT NULL
          ORDER BY COALESCE(UpdatedAt, RDate, '') ASC, AccID ASC
          LIMIT ?1
          ''',
          variables: [Variable.withInt(limit)],
          readsFrom: {db.accPersonal},
        )
        .get();

    final output = <PendingMasterChange>[];
    for (final row in rows) {
      final accId = _toInt(row.data['AccID']);
      final companyId = _toInt(row.data['CompanyID']);
      if (accId <= 0 || companyId <= 0) continue;
      final isDeleted = _toInt(row.data['IsDeleted']) == 1;

      output.add(
        PendingMasterChange(
          companyId: companyId,
          rowId: accId,
          payload: <String, dynamic>{
            'table': 'Acc_Personal',
            'operation': isDeleted ? 'DELETE' : 'UPSERT',
            'pkName': 'AccID',
            'pkValue': accId,
            'data': <String, dynamic>{
              'AccID': accId,
              'RDate': _txt(row.data['RDate']),
              'Name': _txt(row.data['Name']),
              'Phone': _txt(row.data['Phone']),
              'Fax': _txt(row.data['Fax']),
              'Address': _txt(row.data['Address']),
              'Description': _txt(row.data['Description']),
              'UAccName': _txt(row.data['UAccName']),
              'statusg': _txt(row.data['statusg']),
              'UserID': _toIntOrNull(row.data['UserID']),
              'CompanyID': companyId,
              'ChartOfAccountID': _toIntOrNull(row.data['ChartOfAccountID']),
              'WName': _txt(row.data['WName']),
              'IsSynced': _toInt(row.data['IsSynced']),
              'UpdatedAt': _txt(row.data['UpdatedAt']),
              'IsDeleted': _toInt(row.data['IsDeleted']),
            },
          },
        ),
      );
    }

    return output;
  }

  Future<List<PendingMasterChange>> collectAccPersonalSnapshotByIds({
    required List<int> accIds,
    int limit = 900,
  }) async {
    final ids = accIds.where((id) => id > 0).toSet().toList(growable: false);
    if (ids.isEmpty) return const <PendingMasterChange>[];

    final rows = await db
        .customSelect(
          '''
          SELECT
            AccID, RDate, Name, Phone, Fax, Address, Description, UAccName, statusg,
            UserID, CompanyID, ChartOfAccountID, WName, IsSynced, UpdatedAt, IsDeleted
          FROM Acc_Personal
          WHERE AccID IN (${List.filled(ids.length, '?').join(',')})
          ORDER BY COALESCE(UpdatedAt, RDate, '') ASC, AccID ASC
          LIMIT ?${ids.length + 1}
          ''',
          variables: [...ids.map(Variable.withInt), Variable.withInt(limit)],
          readsFrom: {db.accPersonal},
        )
        .get();

    final output = <PendingMasterChange>[];
    for (final row in rows) {
      final accId = _toInt(row.data['AccID']);
      final companyId = _toInt(row.data['CompanyID']);
      if (accId <= 0 || companyId <= 0) continue;
      final isDeleted = _toInt(row.data['IsDeleted']) == 1;

      output.add(
        PendingMasterChange(
          companyId: companyId,
          rowId: accId,
          payload: <String, dynamic>{
            'table': 'Acc_Personal',
            'operation': isDeleted ? 'DELETE' : 'UPSERT',
            'pkName': 'AccID',
            'pkValue': accId,
            'data': <String, dynamic>{
              'AccID': accId,
              'RDate': _txt(row.data['RDate']),
              'Name': _txt(row.data['Name']),
              'Phone': _txt(row.data['Phone']),
              'Fax': _txt(row.data['Fax']),
              'Address': _txt(row.data['Address']),
              'Description': _txt(row.data['Description']),
              'UAccName': _txt(row.data['UAccName']),
              'statusg': _txt(row.data['statusg']),
              'UserID': _toIntOrNull(row.data['UserID']),
              'CompanyID': companyId,
              'ChartOfAccountID': _toIntOrNull(row.data['ChartOfAccountID']),
              'WName': _txt(row.data['WName']),
              'IsSynced': _toInt(row.data['IsSynced']),
              'UpdatedAt': _txt(row.data['UpdatedAt']),
              'IsDeleted': _toInt(row.data['IsDeleted']),
            },
          },
        ),
      );
    }

    return output;
  }

  Future<List<PendingMasterChange>> collectHeadSnapshotChanges({
    required int companyId,
    int limit = 300,
    bool unsyncedOnly = false,
  }) async {
    if (companyId <= 0) return const <PendingMasterChange>[];

    final unsyncedClause = unsyncedOnly ? 'AND COALESCE(IsSynced, 0) = 0' : '';
    final output = <PendingMasterChange>[];

    final headRows = await db
        .customSelect(
          '''
          SELECT
            AccountHeadID,
            AccountHeadName,
            NormalBalance,
            IsDeleted,
            UpdatedAt
          FROM AccountHeads
          WHERE AccountHeadID IS NOT NULL
            $unsyncedClause
          ORDER BY AccountHeadID ASC
          LIMIT ?1
          ''',
          variables: [Variable.withInt(limit)],
          readsFrom: {db.accountHeads},
        )
        .get();

    for (final row in headRows) {
      final id = _toInt(row.data['AccountHeadID']);
      if (id <= 0) continue;
      final isDeleted = _toInt(row.data['IsDeleted']) == 1;
      output.add(
        PendingMasterChange(
          companyId: companyId,
          rowId: id,
          payload: <String, dynamic>{
            'table': 'AccountHeads',
            'operation': isDeleted ? 'DELETE' : 'UPSERT',
            'pkName': 'AccountHeadID',
            'pkValue': id,
            'data': <String, dynamic>{
              'AccountHeadID': id,
              'AccountHeadName': _txt(row.data['AccountHeadName']),
              'NormalBalance': _txt(row.data['NormalBalance']),
              'IsDeleted': _toInt(row.data['IsDeleted']),
              'UpdatedAt': _txt(row.data['UpdatedAt']),
            },
          },
        ),
      );
    }

    final subHeadRows = await db
        .customSelect(
          '''
          SELECT
            AccountSubHeadID,
            AccountHeadID,
            Code,
            AccountSubHeadName,
            IsDeleted,
            UpdatedAt
          FROM AccountSubHeads
          WHERE AccountSubHeadID IS NOT NULL
            $unsyncedClause
          ORDER BY AccountHeadID ASC, AccountSubHeadID ASC
          LIMIT ?1
          ''',
          variables: [Variable.withInt(limit)],
          readsFrom: {db.accountSubHeads},
        )
        .get();

    for (final row in subHeadRows) {
      final id = _toInt(row.data['AccountSubHeadID']);
      if (id <= 0) continue;
      final isDeleted = _toInt(row.data['IsDeleted']) == 1;
      output.add(
        PendingMasterChange(
          companyId: companyId,
          rowId: id,
          payload: <String, dynamic>{
            'table': 'AccountSubHeads',
            'operation': isDeleted ? 'DELETE' : 'UPSERT',
            'pkName': 'AccountSubHeadID',
            'pkValue': id,
            'data': <String, dynamic>{
              'AccountSubHeadID': id,
              'AccountHeadID': _toInt(row.data['AccountHeadID']),
              'Code': _txt(row.data['Code']),
              'AccountSubHeadName': _txt(row.data['AccountSubHeadName']),
              'IsDeleted': _toInt(row.data['IsDeleted']),
              'UpdatedAt': _txt(row.data['UpdatedAt']),
            },
          },
        ),
      );
    }

    final chartRows = await db
        .customSelect(
          '''
          SELECT
            ChartOfAccountID,
            AccountHeadID,
            AccountSubHeadID,
            ChartOfAccountName,
            Code,
            IsDeleted,
            UpdatedAt
          FROM ChartOfAccounts
          WHERE ChartOfAccountID IS NOT NULL
            $unsyncedClause
          ORDER BY ChartOfAccountID ASC
          LIMIT ?1
          ''',
          variables: [Variable.withInt(limit)],
          readsFrom: {db.chartOfAccounts},
        )
        .get();

    for (final row in chartRows) {
      final id = _toInt(row.data['ChartOfAccountID']);
      if (id <= 0) continue;
      final isDeleted = _toInt(row.data['IsDeleted']) == 1;
      output.add(
        PendingMasterChange(
          companyId: companyId,
          rowId: id,
          payload: <String, dynamic>{
            'table': 'ChartOfAccounts',
            'operation': isDeleted ? 'DELETE' : 'UPSERT',
            'pkName': 'ChartOfAccountID',
            'pkValue': id,
            'data': <String, dynamic>{
              'ChartOfAccountID': id,
              'AccountHeadID': _toInt(row.data['AccountHeadID']),
              'AccountSubHeadID': _toInt(row.data['AccountSubHeadID']),
              'ChartOfAccountName': _txt(row.data['ChartOfAccountName']),
              'Code': _txt(row.data['Code']),
              'IsDeleted': _toInt(row.data['IsDeleted']),
              'UpdatedAt': _txt(row.data['UpdatedAt']),
            },
          },
        ),
      );
    }

    return output;
  }

  Future<List<PendingMasterChange>> collectCompanySnapshotChanges({
    required List<int> companyIds,
  }) async {
    final ids = companyIds
        .where((id) => id > 0)
        .toSet()
        .toList(growable: false);
    final rows =
        await (ids.isEmpty
                ? db.customSelect(
                    '''
          SELECT CompanyID, CompanyName, Remarks
          FROM Company
          ORDER BY CompanyID ASC
          ''',
                    readsFrom: {db.companyTable},
                  )
                : db.customSelect(
                    '''
          SELECT CompanyID, CompanyName, Remarks
          FROM Company
          WHERE CompanyID IN (${List.filled(ids.length, '?').join(',')})
          ORDER BY CompanyID ASC
          ''',
                    variables: ids
                        .map(Variable.withInt)
                        .toList(growable: false),
                    readsFrom: {db.companyTable},
                  ))
            .get();

    final output = <PendingMasterChange>[];
    for (final row in rows) {
      final companyId = _toInt(row.data['CompanyID']);
      if (companyId <= 0) continue;
      output.add(
        PendingMasterChange(
          companyId: companyId,
          rowId: companyId,
          payload: <String, dynamic>{
            'table': 'Company',
            'operation': 'UPSERT',
            'pkName': 'CompanyID',
            'pkValue': companyId,
            'data': <String, dynamic>{
              'CompanyID': companyId,
              'CompanyName': _txt(row.data['CompanyName']),
              'Remarks': _txt(row.data['Remarks']),
            },
          },
        ),
      );
    }

    return output;
  }

  Future<List<PendingMasterChange>> collectAssignmentChangesForAccounts({
    required int companyId,
    required List<int> accIds,
    int limit = 2000,
  }) async {
    final cleanIds = accIds
        .where((id) => id > 0)
        .toSet()
        .toList(growable: false);
    if (cleanIds.isEmpty) return const <PendingMasterChange>[];

    final rows = await db
        .customSelect(
          '''
          SELECT apca.RegID, apca.AccID, apca.AccountTypeID,
                 COALESCE(apca.IsDeleted, 0) AS IsDeleted,
                 apca.UpdatedAt AS UpdatedAt
          FROM Account_PCurrencyAssignment apca
          INNER JOIN Acc_Personal ap ON ap.AccID = apca.AccID
          WHERE ap.CompanyID = ?1
            AND COALESCE(ap.IsDeleted, 0) = 0
            AND COALESCE(apca.IsSynced, 0) = 0
            AND apca.AccID IN (${List.filled(cleanIds.length, '?').join(',')})
          ORDER BY COALESCE(apca.UpdatedAt, '') ASC, apca.RegID ASC
          LIMIT ?${cleanIds.length + 2}
          ''',
          variables: [
            Variable.withInt(companyId),
            ...cleanIds.map(Variable.withInt),
            Variable.withInt(limit),
          ],
          readsFrom: {db.accountPCurrencyAssignment, db.accPersonal},
        )
        .get();

    final output = <PendingMasterChange>[];
    for (final row in rows) {
      final regId = _toInt(row.data['RegID']);
      final accId = _toInt(row.data['AccID']);
      final accTypeId = _toInt(row.data['AccountTypeID']);
      final isDeleted = _toInt(row.data['IsDeleted']);
      final updatedAt = _txt(row.data['UpdatedAt']);
      if (regId <= 0 || accId <= 0 || accTypeId <= 0) continue;

      output.add(
        PendingMasterChange(
          companyId: companyId,
          rowId: regId,
          payload: <String, dynamic>{
            'table': 'Account_PCurrencyAssignment',
            'operation': 'UPSERT',
            'pkName': 'RegID',
            'pkValue': regId,
            'data': <String, dynamic>{
              'RegID': regId,
              'AccID': accId,
              'AccountTypeID': accTypeId,
              'CompanyID': companyId,
              'IsDeleted': isDeleted,
              'UpdatedAt': updatedAt,
            },
          },
        ),
      );
    }

    return output;
  }

  Future<List<PendingMasterChange>> collectUnsyncedAssignmentChanges({
    int limit = 4000,
  }) async {
    // Legacy/mobile flows can write only AccountCurrencyMap.
    // Backfill missing assignment rows first so they become syncable.
    await _backfillLegacyAssignmentsForAllCompanies();
    await db.customStatement('''
      DELETE FROM Account_PCurrencyAssignment
      WHERE COALESCE(AccID, 0) <= 0
         OR NOT EXISTS (
           SELECT 1
           FROM Acc_Personal ap
           WHERE ap.AccID = Account_PCurrencyAssignment.AccID
         )
      ''');

    final rows = await db
        .customSelect(
          '''
          SELECT apca.RegID, apca.AccID, apca.AccountTypeID,
                 COALESCE(apca.IsDeleted, 0) AS IsDeleted,
                 apca.UpdatedAt AS UpdatedAt,
                 COALESCE(apca.CompanyID, ap.CompanyID) AS CompanyID
          FROM Account_PCurrencyAssignment apca
          INNER JOIN Acc_Personal ap ON ap.AccID = apca.AccID
          WHERE COALESCE(apca.IsSynced, 0) = 0
            AND COALESCE(apca.AccID, 0) > 0
            AND COALESCE(apca.AccountTypeID, 0) > 0
            AND COALESCE(ap.IsSynced, 0) = 1
            AND COALESCE(apca.CompanyID, ap.CompanyID, 0) > 0
          ORDER BY COALESCE(apca.UpdatedAt, '') ASC, apca.RegID ASC
          LIMIT ?1
          ''',
          variables: [Variable.withInt(limit)],
          readsFrom: {db.accountPCurrencyAssignment, db.accPersonal},
        )
        .get();

    final output = <PendingMasterChange>[];
    for (final row in rows) {
      final regId = _toInt(row.data['RegID']);
      final accId = _toInt(row.data['AccID']);
      final accTypeId = _toInt(row.data['AccountTypeID']);
      final companyId = _toInt(row.data['CompanyID']);
      final isDeleted = _toInt(row.data['IsDeleted']);
      final updatedAt = _txt(row.data['UpdatedAt']);
      if (regId <= 0 || accId <= 0 || accTypeId <= 0 || companyId <= 0) {
        continue;
      }

      output.add(
        PendingMasterChange(
          companyId: companyId,
          rowId: regId,
          payload: <String, dynamic>{
            'table': 'Account_PCurrencyAssignment',
            'operation': 'UPSERT',
            'pkName': 'RegID',
            'pkValue': regId,
            'data': <String, dynamic>{
              'RegID': regId,
              'AccID': accId,
              'AccountTypeID': accTypeId,
              'CompanyID': companyId,
              'IsDeleted': isDeleted,
              'UpdatedAt': updatedAt,
            },
          },
        ),
      );
    }

    return output;
  }

  Future<void> _backfillLegacyAssignmentsForAllCompanies() async {
    final rows = await db
        .customSelect(
          '''
          SELECT DISTINCT COALESCE(acm.CompanyID, ap.CompanyID) AS CompanyID
          FROM AccountCurrencyMap acm
          LEFT JOIN Acc_Personal ap ON ap.AccID = acm.AccID
          WHERE COALESCE(acm.IsEnabled, 1) = 1
            AND COALESCE(acm.CompanyID, ap.CompanyID, 0) > 0
          ''',
          readsFrom: {db.accPersonal},
        )
        .get();

    final companyIds = rows
        .map((r) => _toInt(r.data['CompanyID']))
        .where((id) => id > 0)
        .toSet()
        .toList(growable: false);
    for (final companyId in companyIds) {
      await _backfillLegacyAssignmentsFromMap(companyId: companyId);
    }
  }

  Future<List<PendingMasterChange>> collectAssignmentSnapshotByCompany({
    required int companyId,
    int limit = 4000,
  }) async {
    if (companyId <= 0) return const <PendingMasterChange>[];

    await _backfillLegacyAssignmentsFromMap(companyId: companyId);

    final rows = await db
        .customSelect(
          '''
          SELECT apca.RegID, apca.AccID, apca.AccountTypeID,
                 COALESCE(apca.IsDeleted, 0) AS IsDeleted,
                 apca.UpdatedAt AS UpdatedAt
          FROM Account_PCurrencyAssignment apca
          INNER JOIN Acc_Personal ap ON ap.AccID = apca.AccID
          WHERE ap.CompanyID = ?1
            AND (
              COALESCE(ap.IsDeleted, 0) = 0
              OR COALESCE(apca.IsDeleted, 0) = 1
            )
          ORDER BY apca.AccID ASC, apca.AccountTypeID ASC, apca.RegID ASC
          LIMIT ?2
          ''',
          variables: [Variable.withInt(companyId), Variable.withInt(limit)],
          readsFrom: {db.accountPCurrencyAssignment, db.accPersonal},
        )
        .get();

    final output = <PendingMasterChange>[];
    for (final row in rows) {
      final regId = _toInt(row.data['RegID']);
      final accId = _toInt(row.data['AccID']);
      final accTypeId = _toInt(row.data['AccountTypeID']);
      final isDeleted = _toInt(row.data['IsDeleted']);
      final updatedAt = _txt(row.data['UpdatedAt']);
      if (regId <= 0 || accId <= 0 || accTypeId <= 0) continue;

      output.add(
        PendingMasterChange(
          companyId: companyId,
          rowId: regId,
          payload: <String, dynamic>{
            'table': 'Account_PCurrencyAssignment',
            'operation': 'UPSERT',
            'pkName': 'RegID',
            'pkValue': regId,
            'data': <String, dynamic>{
              'RegID': regId,
              'AccID': accId,
              'AccountTypeID': accTypeId,
              'CompanyID': companyId,
              'IsDeleted': isDeleted,
              'UpdatedAt': updatedAt,
            },
          },
        ),
      );
    }

    return output;
  }

  Future<void> _backfillLegacyAssignmentsFromMap({
    required int companyId,
  }) async {
    final mapRows = await db
        .customSelect(
          '''
          SELECT acm.AccID, acm.AccTypeID
          FROM AccountCurrencyMap acm
          INNER JOIN Acc_Personal ap ON ap.AccID = acm.AccID
          WHERE acm.CompanyID = ?1
            AND ap.CompanyID = ?1
            AND COALESCE(acm.IsEnabled, 1) = 1
            AND COALESCE(ap.IsDeleted, 0) = 0
          ORDER BY acm.AccID ASC, acm.AccTypeID ASC
          ''',
          variables: [Variable.withInt(companyId)],
          readsFrom: {db.accPersonal},
        )
        .get();
    if (mapRows.isEmpty) return;

    final legacyRows = await db
        .customSelect(
          '''
          SELECT apca.AccID, apca.AccountTypeID
          FROM Account_PCurrencyAssignment apca
          INNER JOIN Acc_Personal ap ON ap.AccID = apca.AccID
          WHERE ap.CompanyID = ?1
            AND COALESCE(ap.IsDeleted, 0) = 0
            AND COALESCE(apca.IsDeleted, 0) = 0
          ''',
          variables: [Variable.withInt(companyId)],
          readsFrom: {db.accountPCurrencyAssignment, db.accPersonal},
        )
        .get();

    final existingPairs = <String>{};
    for (final row in legacyRows) {
      final accId = _toInt(row.data['AccID']);
      final accTypeId = _toInt(row.data['AccountTypeID']);
      if (accId <= 0 || accTypeId <= 0) continue;
      existingPairs.add('$accId:$accTypeId');
    }

    final missingPairs = <MapEntry<int, int>>[];
    for (final row in mapRows) {
      final accId = _toInt(row.data['AccID']);
      final accTypeId = _toInt(row.data['AccTypeID']);
      if (accId <= 0 || accTypeId <= 0) continue;
      final key = '$accId:$accTypeId';
      if (existingPairs.contains(key)) continue;
      existingPairs.add(key);
      missingPairs.add(MapEntry(accId, accTypeId));
    }
    if (missingPairs.isEmpty) return;

    final nextRow = await db
        .customSelect(
          '''
          SELECT COALESCE(MAX(CAST(RegID AS INTEGER)), 0) + 1 AS nextRegId
          FROM Account_PCurrencyAssignment
          ''',
          readsFrom: {db.accountPCurrencyAssignment},
        )
        .getSingle();

    var nextRegId = _toInt(nextRow.data['nextRegId']);
    if (nextRegId <= 0) nextRegId = 1;

    await db.transaction(() async {
      for (final pair in missingPairs) {
        await db.customStatement(
          '''
          INSERT INTO Account_PCurrencyAssignment
            (RegID, AccID, AccountTypeID, CompanyID, IsDeleted, IsSynced, UpdatedAt)
          VALUES (?1, ?2, ?3, ?4, 0, 0, ?5)
          ''',
          [
            nextRegId++,
            pair.key,
            pair.value,
            companyId,
            DateTime.now().toUtc().toIso8601String(),
          ],
        );
      }
    });
  }

  Future<int> markAccTypesSynced(List<int> accTypeIds) async {
    final cleaned = accTypeIds
        .where((v) => v > 0)
        .toSet()
        .toList(growable: false);
    if (cleaned.isEmpty) return 0;

    return (db.update(db.accType)..where((t) => t.accTypeId.isIn(cleaned)))
        .write(const AccTypeCompanion(isSynced: Value(1)));
  }

  Future<int> markAccPersonalSynced({
    required int companyId,
    required List<int> accIds,
  }) async {
    final cleaned = accIds.where((v) => v > 0).toSet().toList(growable: false);
    if (cleaned.isEmpty) return 0;

    return (db.update(db.accPersonal)
          ..where((t) => t.companyId.equals(companyId) & t.accId.isIn(cleaned)))
        .write(const AccPersonalCompanion(isSynced: Value(1)));
  }

  Future<int> markAssignmentsSynced(List<int> regIds) async {
    final cleaned = regIds.where((v) => v > 0).toSet().toList(growable: false);
    if (cleaned.isEmpty) return 0;

    await db.customStatement('''
      UPDATE Account_PCurrencyAssignment
      SET IsSynced = 1
      WHERE RegID IN (${List.filled(cleaned.length, '?').join(',')})
      ''', cleaned);
    return cleaned.length;
  }

  Future<int> markHeadSnapshotsSynced(List<PendingMasterChange> rows) async {
    final headIds = <int>{};
    final subHeadIds = <int>{};
    final chartIds = <int>{};

    for (final row in rows) {
      final table = (row.payload['table'] ?? '').toString();
      switch (table) {
        case 'AccountHeads':
          if (row.rowId > 0) headIds.add(row.rowId);
          break;
        case 'AccountSubHeads':
          if (row.rowId > 0) subHeadIds.add(row.rowId);
          break;
        case 'ChartOfAccounts':
          if (row.rowId > 0) chartIds.add(row.rowId);
          break;
      }
    }

    var updated = 0;
    if (headIds.isNotEmpty) {
      updated +=
          await (db.update(db.accountHeads)
                ..where((t) => t.accountHeadId.isIn(headIds.toList())))
              .write(const AccountHeadsCompanion(isSynced: Value(1)));
    }
    if (subHeadIds.isNotEmpty) {
      updated +=
          await (db.update(db.accountSubHeads)
                ..where((t) => t.accountSubHeadId.isIn(subHeadIds.toList())))
              .write(const AccountSubHeadsCompanion(isSynced: Value(1)));
    }
    if (chartIds.isNotEmpty) {
      updated +=
          await (db.update(db.chartOfAccounts)
                ..where((t) => t.chartOfAccountId.isIn(chartIds.toList())))
              .write(const ChartOfAccountsCompanion(isSynced: Value(1)));
    }
    return updated;
  }

  // ------------------------------------------------------------
  // SMALL HELPERS
  // ------------------------------------------------------------

  /// Safe String? converter
  String? _txt(dynamic v) => v?.toString();

  String _cleanGuid(dynamic v) => (v ?? '').toString().trim();

  String _legacyTxGuid(int companyId, int voucherNo) {
    return 'legacy-$companyId-$voucherNo';
  }

  /// Safe int converter (0 if invalid / null)
  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is bool) return v ? 1 : 0;
    return int.tryParse(v.toString()) ?? 0;
  }

  /// Safe int? converter (null if invalid / null)
  int? _toIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is bool) return v ? 1 : 0;
    return int.tryParse(v.toString());
  }

  /// Safe double? converter (null if invalid / null)
  double? _toDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  int _accountHeadIdForChartName(String name) {
    final upper = name.trim().toUpperCase();
    if (upper.contains('EXPENSE')) return 4;
    if (upper.contains('PAYABLE') ||
        upper.contains('SUPPLIER') ||
        upper.contains('LIABILITY')) {
      return 2;
    }
    if (upper.contains('EQUITY') ||
        upper.contains('CAPITAL') ||
        upper.contains('DRAWING')) {
      return 3;
    }
    if (upper.contains('SALE') ||
        upper.contains('INCOME') ||
        upper.contains('REVENUE')) {
      return 5;
    }
    return 1;
  }

  int _accountSubHeadIdForChartName(String name, int accountHeadId) {
    final upper = name.trim().toUpperCase();
    switch (accountHeadId) {
      case 2:
        return 201;
      case 3:
        return 301;
      case 4:
        return 402;
      case 5:
        return 501;
      case 1:
      default:
        return upper.contains('FIXED') ? 102 : 101;
    }
  }

  Future<void> _ensureDefaultAccountTaxonomy() async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    const heads = <List<Object>>[
      [1, 'Assets', 'Debit'],
      [2, 'Liabilities', 'Credit'],
      [3, 'Capital', 'Credit'],
      [4, 'Expenses', 'Debit'],
      [5, 'Revenue', 'Credit'],
    ];
    const subHeads = <List<Object>>[
      [101, 1, '01-01', 'Current Assets'],
      [102, 1, '01-02', 'Fixed Assets'],
      [201, 2, '02-01', 'Other Liabilities'],
      [301, 3, '03-01', 'Owner Equity'],
      [402, 4, '04-02', 'Other Expenses'],
      [501, 5, '05-01', 'Other Revenue'],
    ];

    for (final head in heads) {
      await db.customStatement(
        '''
        INSERT OR IGNORE INTO AccountHeads
          (AccountHeadID, AccountHeadName, NormalBalance, IsDeleted, IsSynced, UpdatedAt)
        VALUES (?1, ?2, ?3, 0, 1, ?4)
        ''',
        [head[0], head[1], head[2], nowIso],
      );
      await db.customStatement(
        '''
        UPDATE AccountHeads
        SET AccountHeadName = ?2,
            NormalBalance = ?3,
            IsDeleted = 0,
            IsSynced = 1,
            UpdatedAt = ?4
        WHERE AccountHeadID = ?1
        ''',
        [head[0], head[1], head[2], nowIso],
      );
    }

    for (final subHead in subHeads) {
      await db.customStatement(
        '''
        INSERT OR IGNORE INTO AccountSubHeads
          (AccountSubHeadID, AccountHeadID, Code, AccountSubHeadName, IsDeleted, IsSynced, UpdatedAt)
        VALUES (?1, ?2, ?3, ?4, 0, 1, ?5)
        ''',
        [subHead[0], subHead[1], subHead[2], subHead[3], nowIso],
      );
      await db.customStatement(
        '''
        UPDATE AccountSubHeads
        SET AccountHeadID = ?2,
            Code = ?3,
            AccountSubHeadName = ?4,
            IsDeleted = 0,
            IsSynced = 1,
            UpdatedAt = ?5
        WHERE AccountSubHeadID = ?1
        ''',
        [subHead[0], subHead[1], subHead[2], subHead[3], nowIso],
      );
    }

    await db.customStatement(
      '''
      UPDATE AccountSubHeads
      SET IsDeleted = 1,
          IsSynced = 1,
          UpdatedAt = ?1
      WHERE AccountSubHeadID IN (202, 401)
        AND AccountSubHeadName IN ('Long Term Liability', 'Operating Revenue')
      ''',
      [nowIso],
    );
  }

  Future<int?> _ensureChartOfAccountForName(String? name) async {
    final normalized = (name ?? '').trim();
    if (normalized.isEmpty) return null;

    final existing = await db
        .customSelect(
          '''
          SELECT ChartOfAccountID
          FROM ChartOfAccounts
          WHERE LOWER(TRIM(COALESCE(ChartOfAccountName, ''))) = LOWER(TRIM(?1))
            AND COALESCE(IsDeleted, 0) = 0
          ORDER BY ChartOfAccountID ASC
          LIMIT 1
          ''',
          variables: [Variable.withString(normalized)],
          readsFrom: {db.chartOfAccounts},
        )
        .get();
    if (existing.isNotEmpty) {
      final id = _toInt(existing.first.data['ChartOfAccountID']);
      return id > 0 ? id : null;
    }

    await _ensureDefaultAccountTaxonomy();
    final nextRow = await db
        .customSelect(
          '''
          SELECT COALESCE(MAX(ChartOfAccountID), 0) + 1 AS next_id
          FROM ChartOfAccounts
          ''',
          readsFrom: {db.chartOfAccounts},
        )
        .getSingle();
    final chartId = _toInt(nextRow.data['next_id']);
    final accountHeadId = _accountHeadIdForChartName(normalized);
    final accountSubHeadId = _accountSubHeadIdForChartName(
      normalized,
      accountHeadId,
    );

    await db.customStatement(
      '''
      INSERT INTO ChartOfAccounts
        (ChartOfAccountID, AccountHeadID, AccountSubHeadID, ChartOfAccountName,
         IsDeleted, IsSynced, UpdatedAt)
      VALUES (?1, ?2, ?3, ?4, 0, 1, ?5)
      ''',
      [
        chartId > 0 ? chartId : 1,
        accountHeadId,
        accountSubHeadId,
        normalized,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );

    return chartId > 0 ? chartId : 1;
  }

  Future<bool> _voucherExists(int voucherNo) async {
    final rows = await db
        .customSelect(
          '''
          SELECT 1
          FROM Transactions_P
          WHERE VoucherNo = ?1
          LIMIT 1
          ''',
          variables: [Variable.withInt(voucherNo)],
          readsFrom: {db.transactionsP},
        )
        .get();
    return rows.isNotEmpty;
  }

  Future<int> _nextAvailableVoucherNo() async {
    final row = await db
        .customSelect(
          '''
          SELECT COALESCE(MAX(CAST(VoucherNo AS INTEGER)), 0) + 1 AS nextVoucher
          FROM Transactions_P
          ''',
          readsFrom: {db.transactionsP},
        )
        .getSingle();

    var voucher = _toInt(row.data['nextVoucher']);
    if (voucher <= 0) voucher = 1;

    while (await _voucherExists(voucher)) {
      voucher += 1;
    }

    return voucher;
  }

  // ============================================================
  // COMPANY
  // ============================================================
  Future<SyncResult> _applyCompanies(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return const SyncResult();

    _log.d("⚡ Applying Company rows: ${rows.length}");
    final tombstones = await CompanyTombstoneStore.load();

    var inserted = 0;
    var updated = 0;
    var skipped = 0;

    for (final row in rows) {
      final companyId = _toInt(row['CompanyID']);
      if (companyId <= 0) continue;
      final companyName = _txt(row['CompanyName']);
      if (CompanyTombstoneStore.isBlocked(
        tombstones,
        companyId: companyId,
        companyName: companyName,
      )) {
        skipped++;
        continue;
      }

      final existing = await db
          .customSelect(
            '''
        SELECT CompanyID
        FROM Company
        WHERE CompanyID = ?1
        LIMIT 1
        ''',
            variables: [Variable.withInt(companyId)],
            readsFrom: {db.companyTable},
          )
          .getSingleOrNull();

      await db.customStatement(
        '''
        INSERT OR REPLACE INTO Company
          (CompanyID, CompanyName, Remarks)
        VALUES (?1, ?2, ?3)
        ''',
        [companyId, companyName, _txt(row['Remarks'])],
      );

      if (existing == null) {
        inserted++;
      } else {
        updated++;
      }
    }

    if (skipped > 0) {
      _log.w("⚠️ Skipped tombstoned Company rows: $skipped");
    }

    return SyncResult(inserted: inserted, updated: updated, deleted: 0);
  }

  Future<SyncResult> _dedupeCompaniesByName() async {
    final rows = await db
        .customSelect(
          '''
      SELECT CompanyID, CompanyName
      FROM Company
      ORDER BY CompanyID ASC
    ''',
          readsFrom: {db.companyTable},
        )
        .get();
    if (rows.length < 2) return const SyncResult();

    final canonicalToKeepId = <String, int>{};
    final duplicates = <({int oldId, int keepId})>[];

    for (final row in rows) {
      final companyId = _toInt(row.data['CompanyID']);
      if (companyId <= 0) continue;
      final canonical = CompanyTombstoneStore.normalizeName(
        row.data['CompanyName']?.toString(),
      );
      if (canonical.isEmpty) continue;

      final keepId = canonicalToKeepId[canonical];
      if (keepId == null) {
        canonicalToKeepId[canonical] = companyId;
        continue;
      }
      if (keepId == companyId) continue;
      duplicates.add((oldId: companyId, keepId: keepId));
    }

    if (duplicates.isEmpty) return const SyncResult();

    var mergedCount = 0;
    for (final dup in duplicates) {
      await db.customStatement(
        'UPDATE Acc_Personal SET CompanyID = ?1 WHERE CompanyID = ?2;',
        [dup.keepId, dup.oldId],
      );
      await db.customStatement(
        'UPDATE Transactions_P SET CompanyID = ?1 WHERE CompanyID = ?2;',
        [dup.keepId, dup.oldId],
      );
      await db.customStatement(
        'UPDATE Account_PCurrencyAssignment SET CompanyID = ?1 WHERE CompanyID = ?2;',
        [dup.keepId, dup.oldId],
      );
      await db.customStatement(
        'UPDATE tblCashTrans SET CompanyID = ?1 WHERE CompanyID = ?2;',
        [dup.keepId, dup.oldId],
      );
      await db.customStatement(
        'UPDATE PeriodLocks SET CompanyID = ?1 WHERE CompanyID = ?2;',
        [dup.keepId, dup.oldId],
      );
      await db.customStatement(
        'UPDATE AuditTrail SET CompanyID = ?1 WHERE CompanyID = ?2;',
        [dup.keepId, dup.oldId],
      );

      await db.customStatement(
        '''
        INSERT OR IGNORE INTO AccountCurrencyMap
          (AccID, AccTypeID, CompanyID, IsEnabled, UpdatedAt)
        SELECT
          AccID,
          AccTypeID,
          ?1 AS CompanyID,
          COALESCE(IsEnabled, 1),
          UpdatedAt
        FROM AccountCurrencyMap
        WHERE CompanyID = ?2
        ''',
        [dup.keepId, dup.oldId],
      );
      await db.customStatement(
        'DELETE FROM AccountCurrencyMap WHERE CompanyID = ?1;',
        [dup.oldId],
      );

      await db.customStatement('DELETE FROM Company WHERE CompanyID = ?1;', [
        dup.oldId,
      ]);
      mergedCount++;
    }

    if (mergedCount > 0) {
      _log.w("⚠️ Merged duplicate Company names: $mergedCount");
    }

    return SyncResult(inserted: 0, updated: mergedCount, deleted: mergedCount);
  }

  // ============================================================
  // ACC TYPE
  // ============================================================
  Future<SyncResult> _applyAccTypes(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return const SyncResult();

    _log.d("⚡ Applying AccType rows: ${rows.length}");

    int inserted = 0;
    int updated = 0;
    int deleted = 0;

    for (final row in rows) {
      final id = _toInt(row['AccTypeID']);
      if (id <= 0) continue;

      final isDeleted = _toInt(row['IsDeleted']) == 1;

      if (isDeleted) {
        final count = await (db.delete(
          db.accType,
        )..where((t) => t.accTypeId.equals(id))).go();
        if (count > 0) deleted++;
        continue;
      }

      await db
          .into(db.accType)
          .insertOnConflictUpdate(
            AccTypeCompanion(
              accTypeId: Value(id),
              accTypeName: Value(_txt(row['AccTypeName'])),
              accTypeNameU: Value(_txt(row['AccTypeNameu'])),
              flag: Value(_txt(row['FLAG'])),
              isSynced: const Value(1),
              updatedAt: Value(_txt(row['UpdatedAt'])),
            ),
          );

      updated++; // treat upsert as update
    }

    return SyncResult(inserted: inserted, updated: updated, deleted: deleted);
  }

  // ============================================================
  // ACC PERSONAL
  // ============================================================
  Future<SyncResult> _applyAccPersonal(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return const SyncResult();

    _log.d("⚡ Applying AccPersonal rows: ${rows.length}");

    int inserted = 0;
    int updated = 0;
    int deleted = 0;

    for (final row in rows) {
      final id = _toInt(row['AccID']);
      if (id <= 0) continue;

      final isDeleted = _toInt(row['IsDeleted']) == 1;

      if (isDeleted) {
        final count = await (db.delete(
          db.accPersonal,
        )..where((p) => p.accId.equals(id))).go();
        if (count > 0) deleted++;
        continue;
      }

      final statusg = _txt(row['statusg']);
      final incomingChartId = _toIntOrNull(row['ChartOfAccountID']);
      final chartOfAccountId = incomingChartId != null && incomingChartId > 0
          ? incomingChartId
          : await _ensureChartOfAccountForName(statusg);

      await db
          .into(db.accPersonal)
          .insertOnConflictUpdate(
            AccPersonalCompanion(
              accId: Value(id),
              rDate: Value(_txt(row['RDate'])),
              name: Value(_txt(row['Name'])),
              phone: Value(_txt(row['Phone'])),
              fax: Value(_txt(row['Fax'])),
              address: Value(_txt(row['Address'])),
              description: Value(_txt(row['Description'])),
              uAccName: Value(_txt(row['UAccName'])),
              statusg: Value(statusg),
              userId: Value(_toIntOrNull(row['UserID'])),
              companyId: Value(_toIntOrNull(row['CompanyID'])),
              chartOfAccountId: Value(chartOfAccountId),
              wName: Value(_txt(row['WName'])),
              isSynced: const Value(1),
              updatedAt: Value(_txt(row['UpdatedAt'])),
              isDeleted: Value(_toInt(row['IsDeleted'])),
            ),
          );

      updated++;
    }

    return SyncResult(inserted: inserted, updated: updated, deleted: deleted);
  }

  // ============================================================
  // TRANSACTIONS_P (NO PRIMARY KEY!)
  // ============================================================
  Future<SyncResult> _applyTransactions(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return const SyncResult();

    _log.d("⚡ Applying Transactions rows: ${rows.length}");

    int inserted = 0;
    int updated = 0;
    int deleted = 0;

    for (final row in rows) {
      final rawVoucher = row['VoucherNo'];
      final incomingVoucher = _toInt(rawVoucher);
      final companyId = _toIntOrNull(row['CompanyID']);
      var txGuid = _cleanGuid(row['TxGuid']);
      if (txGuid.isEmpty) txGuid = _cleanGuid(row['txGuid']);
      if (txGuid.isEmpty) txGuid = _cleanGuid(row['tx_guid']);
      if (txGuid.isEmpty && incomingVoucher > 0) {
        txGuid = _legacyTxGuid(companyId ?? 0, incomingVoucher);
      }

      final isDeleted = _toInt(row['IsDeleted']) == 1;

      if (incomingVoucher <= 0 && txGuid.isEmpty) {
        continue;
      }

      final existingByGuid = txGuid.isEmpty
          ? null
          : await (db.select(
              db.transactionsP,
            )..where((t) => t.txGuid.equals(txGuid))).getSingleOrNull();

      var targetVoucher = incomingVoucher;
      if (existingByGuid != null) {
        targetVoucher = existingByGuid.voucherNo;
      }

      if (targetVoucher <= 0) {
        targetVoucher = await _nextAvailableVoucherNo();
      }

      if (existingByGuid == null && incomingVoucher > 0) {
        final conflicting = await (db.select(
          db.transactionsP,
        )..where((t) => t.voucherNo.equals(incomingVoucher))).getSingleOrNull();
        if (conflicting != null) {
          final conflictingGuid = _cleanGuid(conflicting.txGuid);
          if (txGuid.isNotEmpty &&
              (conflictingGuid.isEmpty || conflictingGuid != txGuid)) {
            targetVoucher = await _nextAvailableVoucherNo();
          }
        }
      }

      await db
          .into(db.transactionsP)
          .insertOnConflictUpdate(
            TransactionsPCompanion(
              voucherNo: Value(targetVoucher),
              txGuid: Value(txGuid.isEmpty ? null : txGuid),
              tDate: Value(_txt(row['TDate'])),
              accId: Value(_toIntOrNull(row['AccID'])),
              accTypeId: Value(_toIntOrNull(row['AccTypeID'])),
              description: Value(_txt(row['Description'])),
              dr: Value(_toDoubleOrNull(row['Dr'])),
              cr: Value(_toDoubleOrNull(row['Cr'])),
              status: Value(_txt(row['Status'])),
              st: Value(_txt(row['st'])),
              updateStatus: Value(_txt(row['updatestatus'])),
              currencyStatus: Value(_txt(row['currencystatus'])),
              cashStatus: Value(_txt(row['cashstatus'])),
              userId: Value(_toIntOrNull(row['UserID'])),
              companyId: Value(_toIntOrNull(row['CompanyID'])),
              wName: Value(_txt(row['WName'])),
              msgNo: Value(_txt(row['msgno'])),
              hwls1: Value(_txt(row['hwls1'])),
              hwls: Value(_txt(row['hwls'])),
              advanceMess: Value(_txt(row['advancemess'])),
              cbal: Value(_toIntOrNull(row['cbal'])),
              cbal1: Value(_toIntOrNull(row['cbal1'])),
              tTime: Value(_txt(row['TTIME'])),
              pd: Value(_txt(row['PD'])),
              msgNo2: Value(_txt(row['msgno2'])),
              others: Value(_txt(row['OTHERS'])),
              isSynced: const Value(1),
              updatedAt: Value(_txt(row['UpdatedAt'])),
              isDeleted: Value(_toInt(row['IsDeleted'])),
            ),
          );

      if (isDeleted) {
        deleted++;
      } else if (existingByGuid == null) {
        inserted++;
      } else {
        updated++;
      }
    }

    return SyncResult(inserted: inserted, updated: updated, deleted: deleted);
  }

  Future<SyncResult> _applyAssignments(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return const SyncResult();

    _log.d("⚡ Applying Assignment rows: ${rows.length}");

    var inserted = 0;
    var updated = 0;
    var deleted = 0;

    for (final row in rows) {
      final regId = _toInt(row['RegID']);
      if (regId <= 0) continue;
      final accId = _toIntOrNull(row['AccID']);
      final accountTypeId =
          _toIntOrNull(row['AccountTypeID']) ?? _toIntOrNull(row['AccTypeID']);
      if (accId == null ||
          accId <= 0 ||
          accountTypeId == null ||
          accountTypeId <= 0) {
        continue;
      }

      var companyId = _toIntOrNull(row['CompanyID']);
      companyId ??= await _resolveCompanyIdForAccount(accId);

      final isDeleted = _toInt(row['IsDeleted']) == 1;
      if (isDeleted) {
        final count = await (db.delete(
          db.accountPCurrencyAssignment,
        )..where((t) => t.regId.equals(regId))).go();
        if (companyId != null && companyId > 0) {
          await db.customStatement(
            '''
            DELETE FROM AccountCurrencyMap
            WHERE AccID = ?1
              AND AccTypeID = ?2
              AND CompanyID = ?3
            ''',
            [accId, accountTypeId, companyId],
          );
        }
        if (count > 0) deleted++;
        continue;
      }

      await db
          .into(db.accountPCurrencyAssignment)
          .insertOnConflictUpdate(
            AccountPCurrencyAssignmentCompanion(
              regId: Value(regId),
              accId: Value(accId),
              accountTypeId: Value(accountTypeId),
            ),
          );

      await db.customStatement(
        '''
        UPDATE Account_PCurrencyAssignment
        SET CompanyID = ?1,
            IsDeleted = 0,
            IsSynced = 1,
            UpdatedAt = ?2
        WHERE RegID = ?3
        ''',
        [companyId, DateTime.now().toUtc().toIso8601String(), regId],
      );

      if (companyId != null && companyId > 0) {
        await db.customStatement(
          '''
          INSERT OR REPLACE INTO AccountCurrencyMap
            (AccID, AccTypeID, CompanyID, IsEnabled, UpdatedAt)
          VALUES (?1, ?2, ?3, 1, ?4)
          ''',
          [
            accId,
            accountTypeId,
            companyId,
            DateTime.now().toUtc().toIso8601String(),
          ],
        );
      }

      updated++;
    }

    return SyncResult(inserted: inserted, updated: updated, deleted: deleted);
  }

  Future<int?> _resolveCompanyIdForAccount(int accId) async {
    final rows = await db
        .customSelect(
          '''
          SELECT CompanyID
          FROM Acc_Personal
          WHERE AccID = ?1
          LIMIT 1
          ''',
          variables: [Variable.withInt(accId)],
          readsFrom: {db.accPersonal},
        )
        .get();
    if (rows.isEmpty) return null;
    final companyId = _toInt(rows.first.data['CompanyID']);
    return companyId > 0 ? companyId : null;
  }
}
