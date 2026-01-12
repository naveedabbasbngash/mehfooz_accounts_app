// lib/repository/sync_repository.dart
import 'package:drift/drift.dart';
import 'package:logger/logger.dart';

import '../../data/local/app_database.dart';
import '../../model/SyncResult.dart';
import '../../services/sync/sync_service.dart';

class SyncRepository {
  final AppDatabase db;
  final Logger _log = Logger();

  SyncRepository(this.db);

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
        final r1 = await _applyAccTypes(batch.accTypes);
        final r2 = await _applyAccPersonal(batch.accPersonal);
        final r3 = await _applyTransactions(batch.transactions);

        inserted += r1.inserted + r2.inserted + r3.inserted;
        updated  += r1.updated  + r2.updated  + r3.updated;
        deleted  += r1.deleted  + r2.deleted  + r3.deleted;
      });

      _log.i(
        "✅ [SyncRepository] Batch applied "
            "(+$inserted added, $updated updated, $deleted deleted)",
      );

      return SyncResult(
        inserted: inserted,
        updated: updated,
        deleted: deleted,
      );
    } catch (e, st) {
      _log.e("❌ [SyncRepository] Failed batch", error: e, stackTrace: st);
      rethrow;
    }
  }

  // ------------------------------------------------------------
  // SMALL HELPERS
  // ------------------------------------------------------------

  /// Safe String? converter
  String? _txt(dynamic v) => v == null ? null : v.toString();

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
      final id = row['AccTypeID'];
      if (id == null) continue;

      final isDeleted = _toInt(row['IsDeleted']) == 1;
      final isSynced = _toInt(row['IsSynced']);

      if (isDeleted) {
        final count = await (db.delete(db.accType)
          ..where((t) => t.accTypeId.equals(id)))
            .go();
        if (count > 0) deleted++;
        continue;
      }

      await db.into(db.accType).insertOnConflictUpdate(
        AccTypeCompanion(
          accTypeId: Value(id),
          accTypeName: Value(_txt(row['AccTypeName'])),
          accTypeNameU: Value(_txt(row['AccTypeNameu'])),
          flag: Value(_txt(row['FLAG'])),
          isSynced: Value(isSynced),
          updatedAt: Value(_txt(row['UpdatedAt'])),
        ),
      );

      updated++; // treat upsert as update
    }

    return SyncResult(
      inserted: inserted,
      updated: updated,
      deleted: deleted,
    );
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
      final id = row['AccID'];
      if (id == null) continue;

      final isDeleted = _toInt(row['IsDeleted']) == 1;

      if (isDeleted) {
        final count = await (db.delete(db.accPersonal)
          ..where((p) => p.accId.equals(id)))
            .go();
        if (count > 0) deleted++;
        continue;
      }

      await db.into(db.accPersonal).insertOnConflictUpdate(
        AccPersonalCompanion(
          accId: Value(id),
          rDate: Value(_txt(row['RDate'])),
          name: Value(_txt(row['Name'])),
          phone: Value(_txt(row['Phone'])),
          fax: Value(_txt(row['Fax'])),
          address: Value(_txt(row['Address'])),
          description: Value(_txt(row['Description'])),
          uAccName: Value(_txt(row['UAccName'])),
          statusg: Value(_txt(row['statusg'])),
          userId: Value(_toIntOrNull(row['UserID'])),
          companyId: Value(_toIntOrNull(row['CompanyID'])),
          wName: Value(_txt(row['WName'])),
          isSynced: Value(_toInt(row['IsSynced'])),
          updatedAt: Value(_txt(row['UpdatedAt'])),
          isDeleted: Value(_toInt(row['IsDeleted'])),
        ),
      );

      updated++;
    }

    return SyncResult(
      inserted: inserted,
      updated: updated,
      deleted: deleted,
    );
  }

  // ============================================================
  // TRANSACTIONS_P (NO PRIMARY KEY!)
  // ============================================================
  Future<SyncResult> _applyTransactions(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return const SyncResult();

    _log.d("⚡ Applying Transactions rows: ${rows.length}");

    int inserted = 0;
    int deleted = 0;

    for (final row in rows) {
      final rawVoucher = row['VoucherNo'];
      if (rawVoucher == null) continue;

      final voucher = _toInt(rawVoucher);
      final isDeleted = _toInt(row['IsDeleted']) == 1;
      final isSynced = _toInt(row['IsSynced']);

      if (isDeleted) {
        final count = await (db.delete(db.transactionsP)
          ..where((t) => t.voucherNo.equals(voucher)))
            .go();
        if (count > 0) deleted++;
        continue;
      }

      await db.into(db.transactionsP).insert(
        TransactionsPCompanion(
          voucherNo: Value(voucher),
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
          isSynced: Value(isSynced),
          updatedAt: Value(_txt(row['UpdatedAt'])),
          isDeleted: Value(_toInt(row['IsDeleted'])),
        ),
        mode: InsertMode.insertOrReplace,
      );

      inserted++;
    }

    return SyncResult(
      inserted: inserted,
      updated: 0,
      deleted: deleted,
    );
  }
}