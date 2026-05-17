import 'package:drift/drift.dart';
import 'package:flutter/cupertino.dart';
import '../data/local/app_database.dart';
import '../model/account_head_option.dart';
import '../model/balance_currency_ui.dart';
import '../model/balance_matrix_result.dart';
import '../model/balance_row.dart';
import '../model/last_credit_row.dart';
import '../model/pending_currency_summary.dart';
import '../model/pending_group_row.dart';
import '../model/pending_status_summary.dart';
import '../model/subgroup_balance_row.dart';
import '../model/tx_filter.dart';
import '../model/tx_item_ui.dart';
import '../services/device_identity_service.dart';
import '../services/local_storage.dart';
import '../utils/ulid.dart';

class _ActorMeta {
  final int? userId;
  final String? userEmail;
  final bool isAdminOrOwner;

  const _ActorMeta({this.userId, this.userEmail, this.isAdminOrOwner = false});
}

class TransactionEditData {
  final int sourceVoucherNo;
  final int mainVoucherNo;
  final bool isCash;
  final int accId;
  final int accTypeId;
  final int? cashAccId;
  final DateTime txDate;
  final String description;
  final String entryReference;
  final double debit;
  final double credit;
  final String? quality;
  final double? rate;
  final double? weight;

  const TransactionEditData({
    required this.sourceVoucherNo,
    required this.mainVoucherNo,
    required this.isCash,
    required this.accId,
    required this.accTypeId,
    required this.cashAccId,
    required this.txDate,
    required this.description,
    required this.entryReference,
    required this.debit,
    required this.credit,
    required this.quality,
    required this.rate,
    required this.weight,
  });
}

class TransactionsRepository {
  final AppDatabase db;
  static const String _cashPairLinkPrefix = 'cash_pair:';
  static const int _maxSafeVoucherNo = 2147483640;
  String? _cachedDeviceId;

  TransactionsRepository(this.db);

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is BigInt) return value.toInt();
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _toText(dynamic value) => (value ?? '').toString().trim();

  int _stableHash(String value) {
    var hash = 2166136261;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash & 0x7fffffff;
  }

  String _generateTxGuid() {
    return Ulid.generate();
  }

  Future<String?> _getCachedDeviceId() async {
    if (_cachedDeviceId != null && _cachedDeviceId!.trim().isNotEmpty) {
      return _cachedDeviceId;
    }
    try {
      final id = await DeviceIdentityService.getDeviceId();
      final trimmed = id.trim();
      if (trimmed.isNotEmpty) {
        _cachedDeviceId = trimmed;
      }
    } catch (_) {
      // Best-effort only.
    }
    return _cachedDeviceId;
  }

  Future<bool> _intIdExists({
    required String table,
    required String column,
    required int value,
  }) async {
    if (value <= 0) return false;
    final rows = await db
        .customSelect(
          '''
          SELECT 1
          FROM $table
          WHERE $column = ?1
          LIMIT 1
          ''',
          variables: [Variable.withInt(value)],
        )
        .get();
    return rows.isNotEmpty;
  }

  Future<int> _nextDistributedIntId({
    required String table,
    required String column,
    required int localNext,
  }) async {
    final safeLocalNext = localNext > 0 ? localNext : 1;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final deviceId = (await _getCachedDeviceId()) ?? '';
    final jitterSeed = '$table|$column|$deviceId';
    final jitter = (_stableHash(jitterSeed) % 997) + 3;

    var candidate = nowSeconds + jitter;
    if (candidate < safeLocalNext) {
      candidate = safeLocalNext;
    }
    if (candidate > _maxSafeVoucherNo) {
      candidate = safeLocalNext;
    }

    while (await _intIdExists(table: table, column: column, value: candidate)) {
      candidate += 1;
      if (candidate > _maxSafeVoucherNo) {
        candidate = safeLocalNext;
      }
    }

    return candidate;
  }

  bool _isCashLikeAccountName(String accountName) {
    final compact = accountName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    if (compact.isEmpty) return false;
    return compact.contains('cash');
  }

  String? normalizeHeadNameForAccount({
    required String accountName,
    String? requestedHeadName,
  }) {
    if (_isCashLikeAccountName(accountName)) {
      return 'CASH';
    }
    final cleanHead = requestedHeadName?.trim();
    if (cleanHead == null || cleanHead.isEmpty) return null;
    return cleanHead;
  }

  Iterable<List<T>> _chunked<T>(List<T> items, {int size = 250}) sync* {
    if (items.isEmpty) return;
    for (var i = 0; i < items.length; i += size) {
      final end = (i + size < items.length) ? i + size : items.length;
      yield items.sublist(i, end);
    }
  }

  int? _mainVoucherFromPairLink(String pairLink) {
    if (!pairLink.startsWith(_cashPairLinkPrefix)) return null;
    final payload = pairLink.substring(_cashPairLinkPrefix.length);
    if (payload.isEmpty) return null;
    final parts = payload.split(':');
    if (parts.isEmpty) return null;
    return int.tryParse(parts.first.trim());
  }

  int? _reverseVoucherFromPairLink(String pairLink) {
    if (!pairLink.startsWith(_cashPairLinkPrefix)) return null;
    final payload = pairLink.substring(_cashPairLinkPrefix.length);
    if (payload.isEmpty) return null;
    final parts = payload.split(':');
    if (parts.length < 2) return null;
    return int.tryParse(parts[1].trim());
  }

  Future<_ActorMeta> _resolveCurrentActor() async {
    try {
      final user = await LocalStorageService.loadLastUsedUser();
      if (user == null) return const _ActorMeta();

      final parsedId = int.tryParse(user.id.trim());
      final cleanEmail = user.email.trim();
      return _ActorMeta(
        userId: parsedId,
        userEmail: cleanEmail.isEmpty ? null : cleanEmail,
        isAdminOrOwner: user.isAdminOrOwner,
      );
    } catch (_) {
      return const _ActorMeta();
    }
  }

  bool _canMutateTransactionRow(TransactionsPData row, _ActorMeta actor) {
    if (actor.isAdminOrOwner) return true;
    final actorId = actor.userId;
    if (actorId == null || actorId <= 0) return false;
    final ownerId = row.userId;
    if (ownerId == null || ownerId <= 0) return false;
    return ownerId == actorId;
  }

  void _assertCanMutateTransactionRows(
    Iterable<TransactionsPData> rows,
    _ActorMeta actor,
    String action,
  ) {
    for (final row in rows) {
      if (_canMutateTransactionRow(row, actor)) continue;
      throw Exception(
        'Only ADMIN/OWNER can $action other users\' transactions.',
      );
    }
  }

  Future<List<TransactionsPData>> _loadLinkedTransactionRowsForVoucher({
    required int companyId,
    required int voucherNo,
    required bool includeDeleted,
  }) async {
    final target =
        await (db.select(db.transactionsP)..where(
              (t) =>
                  t.companyId.equals(companyId) &
                  t.voucherNo.equals(voucherNo) &
                  (includeDeleted
                      ? t.isDeleted.equals(1)
                      : (t.isDeleted.isNull() | t.isDeleted.equals(0))),
            ))
            .getSingleOrNull();
    if (target == null) return const <TransactionsPData>[];

    final pairLink = (target.others ?? '').trim();
    if (!pairLink.startsWith(_cashPairLinkPrefix)) {
      return <TransactionsPData>[target];
    }

    final rows =
        await (db.select(db.transactionsP)..where(
              (t) =>
                  t.companyId.equals(companyId) &
                  t.others.equals(pairLink) &
                  (includeDeleted
                      ? t.isDeleted.equals(1)
                      : (t.isDeleted.isNull() | t.isDeleted.equals(0))),
            ))
            .get();
    if (rows.isEmpty) return <TransactionsPData>[target];
    return rows;
  }

  // =========================================================
  // ACCOUNT HEADS
  // =========================================================
  Future<List<AccountHeadOption>> getAllAccountHeads() async {
    final rows = await db
        .customSelect(
          '''
          SELECT acc_head_id, acc_head_name
          FROM Accounts_Heads
          ORDER BY acc_head_name COLLATE NOCASE ASC, acc_head_id ASC
          ''',
          readsFrom: {db.accountsHeads},
        )
        .get();

    return rows
        .map((r) {
          final id = _toInt(r.data['acc_head_id']);
          final name = _toText(r.data['acc_head_name']);
          if (id <= 0 || name.isEmpty) return null;
          return AccountHeadOption(accHeadId: id, accHeadName: name);
        })
        .whereType<AccountHeadOption>()
        .toList(growable: false);
  }

  Future<int> getNextAccountHeadId() async {
    final row = await db
        .customSelect(
          '''
          SELECT COALESCE(MAX(CAST(acc_head_id AS INTEGER)), 0) + 1 AS next_id
          FROM Accounts_Heads
          ''',
          readsFrom: {db.accountsHeads},
        )
        .getSingle();
    final localNext = _toInt(row.data['next_id']);
    return _nextDistributedIntId(
      table: 'Accounts_Heads',
      column: 'acc_head_id',
      localNext: localNext,
    );
  }

  Future<int?> findAccountHeadIdByNameLoose(String accHeadName) async {
    final normalized = accHeadName.trim();
    if (normalized.isEmpty) return null;

    final rows = await db
        .customSelect(
          '''
          SELECT acc_head_id
          FROM Accounts_Heads
          WHERE LOWER(TRIM(COALESCE(acc_head_name, ''))) = LOWER(TRIM(?1))
          LIMIT 1
          ''',
          variables: [Variable.withString(normalized)],
          readsFrom: {db.accountsHeads},
        )
        .get();

    if (rows.isEmpty) return null;
    final id = _toInt(rows.first.data['acc_head_id']);
    return id > 0 ? id : null;
  }

  Future<int> createAccountHead({required String accHeadName}) async {
    final normalized = accHeadName.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('Head name cannot be empty.');
    }

    final existingId = await findAccountHeadIdByNameLoose(normalized);
    if (existingId != null) return existingId;

    final newId = await getNextAccountHeadId();
    await db.customStatement(
      '''
      INSERT INTO Accounts_Heads (acc_head_id, acc_head_name)
      VALUES (?1, ?2)
      ''',
      [newId, normalized],
    );
    return newId;
  }

  Future<void> updateAccountHead({
    required int accHeadId,
    required String accHeadName,
  }) async {
    final normalized = accHeadName.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('Head name cannot be empty.');
    }

    await db.customStatement(
      '''
      UPDATE Accounts_Heads
      SET acc_head_name = ?1
      WHERE acc_head_id = ?2
      ''',
      [normalized, accHeadId],
    );
  }

  Future<void> deleteAccountHead({required int accHeadId}) async {
    await db.customStatement(
      '''
      DELETE FROM Accounts_Heads
      WHERE acc_head_id = ?1
      ''',
      [accHeadId],
    );
  }

  // =========================================================
  // TRANSACTION ENTRY HELPERS
  // =========================================================
  Future<List<AccPersonalData>> getAccountsForCompany({
    required int companyId,
  }) {
    return (db.select(db.accPersonal)
          ..where(
            (tbl) =>
                tbl.companyId.equals(companyId) &
                (tbl.isDeleted.isNull() | tbl.isDeleted.equals(0)),
          )
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
        .get();
  }

  Future<List<AccPersonalData>> searchAccountsForCompany({
    required int companyId,
    required String query,
    int limit = 100,
  }) {
    final q = query.trim();
    final select = db.select(db.accPersonal)
      ..where(
        (tbl) =>
            tbl.companyId.equals(companyId) &
            (tbl.isDeleted.isNull() | tbl.isDeleted.equals(0)),
      );

    if (q.isNotEmpty) {
      select.where((tbl) => tbl.name.like('%$q%'));
    }

    select
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)])
      ..limit(limit);

    return select.get();
  }

  Future<List<AccTypeData>> getAssignedAccTypesForAccount({
    required int accId,
    int? companyId,
  }) async {
    AccTypeData mapRowToAccType(Map<String, dynamic> data) {
      return AccTypeData(
        accTypeId: _toInt(data['AccTypeID']),
        accTypeName: data['AccTypeName'] as String?,
        accTypeNameU: data['AccTypeNameu'] as String?,
        flag: data['FLAG'] as String?,
        isSynced: data['IsSynced'] as int?,
        updatedAt: data['UpdatedAt'] as String?,
      );
    }

    final rowsFromMap = await db
        .customSelect(
          companyId == null
              ? '''
      SELECT at.*
      FROM AccountCurrencyMap acm
      INNER JOIN AccType at ON at.AccTypeID = acm.AccTypeID
      WHERE acm.AccID = ?1
        AND COALESCE(acm.IsEnabled, 1) = 1
      GROUP BY at.AccTypeID
      ORDER BY at.AccTypeName COLLATE NOCASE ASC
      '''
              : '''
      SELECT at.*
      FROM AccountCurrencyMap acm
      INNER JOIN AccType at ON at.AccTypeID = acm.AccTypeID
      WHERE acm.AccID = ?1
        AND acm.CompanyID = ?2
        AND COALESCE(acm.IsEnabled, 1) = 1
      GROUP BY at.AccTypeID
      ORDER BY at.AccTypeName COLLATE NOCASE ASC
      ''',
          variables: [
            Variable.withInt(accId),
            if (companyId != null) Variable.withInt(companyId),
          ],
          readsFrom: {db.accType},
        )
        .get();

    // Fallback to legacy assignment table for older databases.
    final rowsFromLegacy = await db
        .customSelect(
          companyId == null
              ? '''
      SELECT at.*
      FROM Account_PCurrencyAssignment apca
      INNER JOIN AccType at ON at.AccTypeID = apca.AccountTypeID
      WHERE apca.AccID = ?1
        AND COALESCE(apca.IsDeleted, 0) = 0
      GROUP BY at.AccTypeID
      ORDER BY at.AccTypeName COLLATE NOCASE ASC
      '''
              : '''
      SELECT at.*
      FROM Account_PCurrencyAssignment apca
      INNER JOIN AccType at ON at.AccTypeID = apca.AccountTypeID
      WHERE apca.AccID = ?1
        AND COALESCE(apca.IsDeleted, 0) = 0
        AND COALESCE(apca.CompanyID, ?2) = ?2
      GROUP BY at.AccTypeID
      ORDER BY at.AccTypeName COLLATE NOCASE ASC
      ''',
          variables: [
            Variable.withInt(accId),
            if (companyId != null) Variable.withInt(companyId),
          ],
          readsFrom: {db.accountPCurrencyAssignment, db.accType},
        )
        .get();
    final mergedById = <int, AccTypeData>{};
    for (final row in rowsFromMap) {
      final item = mapRowToAccType(row.data);
      if (item.accTypeId > 0) mergedById[item.accTypeId] = item;
    }
    for (final row in rowsFromLegacy) {
      final item = mapRowToAccType(row.data);
      if (item.accTypeId <= 0) continue;
      mergedById.putIfAbsent(item.accTypeId, () => item);
    }

    final result = mergedById.values.toList(growable: false);
    result.sort(
      (a, b) => (a.accTypeName ?? '').toLowerCase().compareTo(
        (b.accTypeName ?? '').toLowerCase(),
      ),
    );
    return result;
  }

  Future<List<AccTypeData>> getAllAccTypes() {
    return (db.select(
      db.accType,
    )..orderBy([(tbl) => OrderingTerm.asc(tbl.accTypeName)])).get();
  }

  Future<int> getNextAccTypeId() async {
    final row = await db
        .customSelect(
          '''
      SELECT COALESCE(MAX(CAST(AccTypeID AS INTEGER)), 0) + 1 AS nextAccTypeId
      FROM AccType
      ''',
          readsFrom: {db.accType},
        )
        .getSingle();
    final localNext = _toInt(row.data['nextAccTypeId']);
    return _nextDistributedIntId(
      table: 'AccType',
      column: 'AccTypeID',
      localNext: localNext,
    );
  }

  Future<int> getNextCurrencyAssignmentRegId() async {
    final row = await db
        .customSelect(
          '''
      SELECT COALESCE(MAX(CAST(RegID AS INTEGER)), 0) + 1 AS nextRegId
      FROM Account_PCurrencyAssignment
      ''',
          readsFrom: {db.accountPCurrencyAssignment},
        )
        .getSingle();
    final localNext = _toInt(row.data['nextRegId']);
    return _nextDistributedIntId(
      table: 'Account_PCurrencyAssignment',
      column: 'RegID',
      localNext: localNext,
    );
  }

  Future<int?> findAccTypeIdByNameLoose(String currencyName) async {
    final rows = await db
        .customSelect(
          '''
      SELECT AccTypeID AS id
      FROM AccType
      WHERE LOWER(TRIM(COALESCE(AccTypeName, ''))) = LOWER(TRIM(?1))
      LIMIT 1
      ''',
          variables: [Variable.withString(currencyName)],
          readsFrom: {db.accType},
        )
        .get();

    if (rows.isEmpty) return null;
    final id = _toInt(rows.first.data['id']);
    return id > 0 ? id : null;
  }

  Future<int> createCurrencyType({
    required String currencyName,
    String? flag,
  }) async {
    final cleanName = currencyName.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('Currency name cannot be empty');
    }

    final existingId = await findAccTypeIdByNameLoose(cleanName);
    if (existingId != null) return existingId;

    final accTypeId = await getNextAccTypeId();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final cleanFlag = (flag ?? '').trim();

    await db
        .into(db.accType)
        .insert(
          AccTypeCompanion(
            accTypeId: Value(accTypeId),
            accTypeName: Value(cleanName),
            accTypeNameU: Value(cleanName),
            flag: Value(cleanFlag.isEmpty ? cleanName : cleanFlag),
            isSynced: const Value(0),
            updatedAt: Value(nowIso),
          ),
        );

    return accTypeId;
  }

  Future<void> assignCurrencyToAccount({
    required int accId,
    required int accTypeId,
  }) async {
    final resolvedCompanyId = await _resolveCompanyIdForAccount(accId);
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final existing = await db
        .customSelect(
          '''
      SELECT RegID
      FROM Account_PCurrencyAssignment
      WHERE AccID = ?1 AND AccountTypeID = ?2
      ORDER BY RegID DESC
      LIMIT 1
      ''',
          variables: [Variable.withInt(accId), Variable.withInt(accTypeId)],
          readsFrom: {db.accountPCurrencyAssignment},
        )
        .get();

    if (existing.isNotEmpty) {
      final regId =
          int.tryParse((existing.first.data['RegID'] ?? '0').toString()) ?? 0;
      if (regId > 0) {
        await db.customStatement(
          '''
          UPDATE Account_PCurrencyAssignment
          SET IsDeleted = 0,
              IsSynced = 0,
              UpdatedAt = ?1,
              CompanyID = COALESCE(CompanyID, ?2),
              AccID = ?3,
              AccountTypeID = ?4
          WHERE RegID = ?5
          ''',
          [nowIso, resolvedCompanyId, accId, accTypeId, regId],
        );
      }
      if (resolvedCompanyId != null && resolvedCompanyId > 0) {
        await db.customStatement(
          '''
          INSERT OR REPLACE INTO AccountCurrencyMap
            (AccID, AccTypeID, CompanyID, IsEnabled, UpdatedAt)
          VALUES (?1, ?2, ?3, 1, ?4)
          ''',
          [accId, accTypeId, resolvedCompanyId, nowIso],
        );
      }
      return;
    }

    final nextRegId = await getNextCurrencyAssignmentRegId();
    await db.customStatement(
      '''
      INSERT INTO Account_PCurrencyAssignment
        (RegID, AccID, AccountTypeID, CompanyID, IsDeleted, IsSynced, UpdatedAt)
      VALUES (?1, ?2, ?3, ?4, 0, 0, ?5)
      ''',
      [nextRegId, accId, accTypeId, resolvedCompanyId, nowIso],
    );

    if (resolvedCompanyId != null && resolvedCompanyId > 0) {
      await db.customStatement(
        '''
        INSERT OR REPLACE INTO AccountCurrencyMap
          (AccID, AccTypeID, CompanyID, IsEnabled, UpdatedAt)
        VALUES (?1, ?2, ?3, 1, ?4)
        ''',
        [accId, accTypeId, resolvedCompanyId, nowIso],
      );
    }
  }

  Future<int> createCurrencyAndAssignToAccount({
    required int accId,
    required String currencyName,
    String? flag,
  }) async {
    final accTypeId = await createCurrencyType(
      currencyName: currencyName,
      flag: flag,
    );

    await assignCurrencyToAccount(accId: accId, accTypeId: accTypeId);
    return accTypeId;
  }

  Future<double> getBalanceForAccountAndType({
    required int companyId,
    required int accId,
    required int accTypeId,
  }) async {
    final row = await db
        .customSelect(
          '''
      SELECT IFNULL(SUM(Cr), 0.0) - IFNULL(SUM(Dr), 0.0) AS balance
      FROM Transactions_P
      WHERE CompanyID = ?1 AND AccID = ?2 AND AccTypeID = ?3
        AND COALESCE(IsDeleted, 0) = 0
      ''',
          variables: [
            Variable.withInt(companyId),
            Variable.withInt(accId),
            Variable.withInt(accTypeId),
          ],
          readsFrom: {db.transactionsP},
        )
        .getSingle();

    final value = row.data['balance'];
    return value is num ? value.toDouble() : 0.0;
  }

  Future<int> getNextVoucherNo() async {
    final row = await db
        .customSelect(
          '''
      SELECT COALESCE(MAX(CAST(VoucherNo AS INTEGER)), 0) + 1 AS nextVoucher
      FROM Transactions_P
      ''',
          readsFrom: {db.transactionsP},
        )
        .getSingle();

    return _toInt(row.data['nextVoucher']);
  }

  Future<bool> _voucherExists(int voucherNo) async {
    final row = await db
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
    return row.isNotEmpty;
  }

  Future<int> _reserveUniqueVoucherNo({int minValue = 0, int? userId}) async {
    final localNext = await getNextVoucherNo();
    final now = DateTime.now();
    final deviceId = await _getCachedDeviceId();
    final guid = _generateTxGuid();
    final epochSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final guidJitter = _stableHash(guid) % 7919; // 0..7918
    final actorJitter = ((userId ?? 0).abs() % 97) * 97; // 0..9312
    final deviceJitter = deviceId == null
        ? 0
        : (_stableHash(deviceId) % 9973) * 11; // 0..109692

    var candidate = epochSeconds + guidJitter + actorJitter + deviceJitter;

    if (candidate < localNext) candidate = localNext;
    if (candidate <= minValue) candidate = minValue + 1;

    if (candidate > _maxSafeVoucherNo) {
      candidate = localNext > minValue ? localNext : (minValue + 1);
    }

    while (await _voucherExists(candidate)) {
      candidate += 1;
      if (candidate > _maxSafeVoucherNo) {
        final refreshedNext = await getNextVoucherNo();
        candidate = refreshedNext > minValue ? refreshedNext : (minValue + 1);
      }
    }

    return candidate;
  }

  Future<int> getNextAccId() async {
    final row = await db
        .customSelect(
          '''
      SELECT COALESCE(MAX(CAST(AccID AS INTEGER)), 0) + 1 AS nextAccId
      FROM Acc_Personal
      ''',
          readsFrom: {db.accPersonal},
        )
        .getSingle();
    final localNext = _toInt(row.data['nextAccId']);
    return _nextDistributedIntId(
      table: 'Acc_Personal',
      column: 'AccID',
      localNext: localNext,
    );
  }

  Future<int> createAccountForCompany({
    required int companyId,
    required String name,
    String? phone,
    String? address,
    String? statusg,
  }) async {
    final nextAccId = await getNextAccId();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final normalizedHead = normalizeHeadNameForAccount(
      accountName: name,
      requestedHeadName: statusg,
    );

    await db
        .into(db.accPersonal)
        .insert(
          AccPersonalCompanion(
            accId: Value(nextAccId),
            rDate: Value(nowIso),
            name: Value(name.trim()),
            phone: Value(phone?.trim().isEmpty == true ? null : phone?.trim()),
            address: Value(
              address?.trim().isEmpty == true ? null : address?.trim(),
            ),
            statusg: Value(normalizedHead),
            companyId: Value(companyId),
            isSynced: const Value(0),
            updatedAt: Value(nowIso),
            isDeleted: const Value(0),
          ),
        );

    return nextAccId;
  }

  Future<void> updateAccountBasic({
    required int accId,
    required String name,
    String? phone,
    String? address,
    String? statusg,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final normalizedHead = normalizeHeadNameForAccount(
      accountName: name,
      requestedHeadName: statusg,
    );

    await (db.update(
      db.accPersonal,
    )..where((tbl) => tbl.accId.equals(accId))).write(
      AccPersonalCompanion(
        name: Value(name.trim()),
        phone: Value(phone?.trim().isEmpty == true ? null : phone?.trim()),
        address: Value(
          address?.trim().isEmpty == true ? null : address?.trim(),
        ),
        statusg: Value(normalizedHead),
        isSynced: const Value(0),
        updatedAt: Value(nowIso),
      ),
    );
  }

  Future<void> replaceAccountCurrencies({
    required int accId,
    required List<int> accTypeIds,
    int? companyId,
  }) async {
    final uniqueIds = <int>{...accTypeIds.where((id) => id > 0)};
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final resolvedCompanyId = companyId == null || companyId <= 0
        ? await _resolveCompanyIdForAccount(accId)
        : companyId;

    final allCurrencyRows = await db
        .customSelect(
          '''
          SELECT AccTypeID
          FROM AccType
          ORDER BY AccTypeID
          ''',
          readsFrom: {db.accType},
        )
        .get();
    final allCurrencyIds =
        allCurrencyRows
            .map((r) => _toInt(r.data['AccTypeID']))
            .where((v) => v > 0)
            .toSet()
          ..addAll(uniqueIds);

    await db.transaction(() async {
      // Soft-delete all current assignments first so removals are synced.
      await db.customStatement(
        '''
        UPDATE Account_PCurrencyAssignment
        SET IsDeleted = 1,
            IsSynced = 0,
            UpdatedAt = ?1,
            CompanyID = COALESCE(CompanyID, ?2)
        WHERE AccID = ?3
        ''',
        [nowIso, resolvedCompanyId, accId],
      );

      for (final accTypeId in uniqueIds) {
        final existing = await db
            .customSelect(
              '''
              SELECT RegID
              FROM Account_PCurrencyAssignment
              WHERE AccID = ?1
                AND AccountTypeID = ?2
              ORDER BY RegID DESC
              LIMIT 1
              ''',
              variables: [Variable.withInt(accId), Variable.withInt(accTypeId)],
              readsFrom: {db.accountPCurrencyAssignment},
            )
            .get();

        if (existing.isNotEmpty) {
          final regId =
              int.tryParse((existing.first.data['RegID'] ?? '0').toString()) ??
              0;
          if (regId > 0) {
            await db.customStatement(
              '''
              UPDATE Account_PCurrencyAssignment
              SET IsDeleted = 0,
                  IsSynced = 0,
                  UpdatedAt = ?1,
                  CompanyID = ?2,
                  AccID = ?3,
                  AccountTypeID = ?4
              WHERE RegID = ?5
              ''',
              [nowIso, resolvedCompanyId, accId, accTypeId, regId],
            );
            continue;
          }
        }

        final regId = await getNextCurrencyAssignmentRegId();
        await db.customStatement(
          '''
          INSERT INTO Account_PCurrencyAssignment
            (RegID, AccID, AccountTypeID, CompanyID, IsDeleted, IsSynced, UpdatedAt)
          VALUES (?1, ?2, ?3, ?4, 0, 0, ?5)
          ''',
          [regId, accId, accTypeId, resolvedCompanyId, nowIso],
        );
      }

      if (resolvedCompanyId != null && resolvedCompanyId > 0) {
        for (final accTypeId in allCurrencyIds) {
          final enabled = uniqueIds.contains(accTypeId) ? 1 : 0;
          await db.customStatement(
            '''
            INSERT OR REPLACE INTO AccountCurrencyMap
              (AccID, AccTypeID, CompanyID, IsEnabled, UpdatedAt)
            VALUES (?1, ?2, ?3, ?4, ?5)
            ''',
            [accId, accTypeId, resolvedCompanyId, enabled, nowIso],
          );
        }
      }
    });
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

  Future<List<String>> searchQualitySuggestions({
    required int companyId,
    required String query,
    int limit = 12,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const <String>[];

    final rows = await db
        .customSelect(
          '''
          SELECT DISTINCT TRIM(COALESCE(Quality, '')) AS quality
          FROM Transactions_P
          WHERE CompanyID = ?1
            AND COALESCE(IsDeleted, 0) = 0
            AND TRIM(COALESCE(Quality, '')) <> ''
            AND LOWER(TRIM(COALESCE(Quality, ''))) LIKE '%' || LOWER(?2) || '%'
          ORDER BY quality COLLATE NOCASE ASC
          LIMIT ?3
          ''',
          variables: [
            Variable.withInt(companyId),
            Variable.withString(normalized),
            Variable.withInt(limit),
          ],
          readsFrom: {db.transactionsP},
        )
        .get();

    return rows
        .map((r) => (r.data['quality'] as String?)?.trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> insertTransactionEntry({
    required int companyId,
    required int accId,
    required int accTypeId,
    required DateTime txDate,
    required String description,
    required String entryReference,
    required double debit,
    required double credit,
    required bool isCash,
    int? cashAccId,
    String? quality,
    double? rate,
    double? weight,
  }) async {
    final actor = await _resolveCurrentActor();
    final cleanDescription = description.trim();
    final cleanReference = entryReference.trim();
    final cleanQuality = quality?.trim();

    if (isCash && cashAccId == null) {
      throw Exception('Cash account is required for cash transaction');
    }

    if (isCash && cashAccId == accId) {
      throw Exception('Cash account must be different from selected account');
    }

    final hasDebit = debit > 0;
    final hasCredit = credit > 0;
    final normalizedWeight = weight == null
        ? null
        : (hasCredit ? -weight.abs() : weight.abs());

    if (hasDebit == hasCredit) {
      throw Exception('Exactly one side must be greater than zero');
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final txDateIso =
        '${txDate.year.toString().padLeft(4, '0')}-${txDate.month.toString().padLeft(2, '0')}-${txDate.day.toString().padLeft(2, '0')}';
    final mainTxGuid = _generateTxGuid();

    var mainVoucher = 0;
    int? reverseVoucher;
    String? reverseTxGuid;

    await db.transaction(() async {
      final nextVoucher = await _reserveUniqueVoucherNo(userId: actor.userId);
      mainVoucher = nextVoucher;
      final voucherReference = mainVoucher.toString();

      String? pairLink;
      if (isCash && cashAccId != null) {
        reverseVoucher = await _reserveUniqueVoucherNo(
          minValue: mainVoucher,
          userId: actor.userId,
        );
        reverseTxGuid = _generateTxGuid();
        pairLink = '$_cashPairLinkPrefix$mainVoucher:${reverseVoucher!}';
      }

      final isCredit = credit > 0;
      await db
          .into(db.transactionsP)
          .insert(
            TransactionsPCompanion(
              voucherNo: Value(mainVoucher),
              txGuid: Value(mainTxGuid),
              tDate: Value(txDateIso),
              accId: Value(accId),
              accTypeId: Value(accTypeId),
              description: Value(cleanDescription),
              quality: Value(
                cleanQuality == null || cleanQuality.isEmpty
                    ? null
                    : cleanQuality,
              ),
              rate: Value(rate),
              weight: Value(normalizedWeight),
              dr: Value(debit),
              cr: Value(credit),
              status: Value(isCredit ? 'jama' : 'banam'),
              st: Value(isCredit ? 'jamakatha' : 'banamkatha'),
              currencyStatus: const Value('csave'),
              cashStatus: Value(isCash ? 'cash' : 'trans'),
              companyId: Value(companyId),
              userId: Value(actor.userId),
              wName: Value(actor.userEmail),
              msgNo: Value(cleanReference.isEmpty ? null : cleanReference),
              msgNo2: Value(cleanReference.isEmpty ? null : cleanReference),
              hwls: Value(voucherReference),
              others: Value(pairLink),
              isSynced: const Value(0),
              updatedAt: Value(nowIso),
              isDeleted: const Value(0),
            ),
            mode: InsertMode.insertOrReplace,
          );

      if (isCash && cashAccId != null && reverseVoucher != null) {
        final reverseDebit = hasCredit ? credit : 0.0;
        final reverseCredit = hasDebit ? debit : 0.0;
        final reverseIsCredit = reverseCredit > 0;

        await db
            .into(db.transactionsP)
            .insert(
              TransactionsPCompanion(
                voucherNo: Value(reverseVoucher!),
                txGuid: Value(reverseTxGuid),
                tDate: Value(txDateIso),
                accId: Value(cashAccId),
                accTypeId: Value(accTypeId),
                description: Value(cleanDescription),
                quality: Value(
                  cleanQuality == null || cleanQuality.isEmpty
                      ? null
                      : cleanQuality,
                ),
                rate: Value(rate),
                weight: Value(normalizedWeight),
                dr: Value(reverseDebit),
                cr: Value(reverseCredit),
                status: Value(reverseIsCredit ? 'jama' : 'banam'),
                st: Value(reverseIsCredit ? 'jamakatha' : 'banamkatha'),
                currencyStatus: const Value('csave'),
                cashStatus: const Value('cash'),
                companyId: Value(companyId),
                userId: Value(actor.userId),
                wName: Value(actor.userEmail),
                msgNo: Value(cleanReference.isEmpty ? null : cleanReference),
                msgNo2: Value(cleanReference.isEmpty ? null : cleanReference),
                hwls: Value(voucherReference),
                others: Value(pairLink),
                isSynced: const Value(0),
                updatedAt: Value(nowIso),
                isDeleted: const Value(0),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    });
  }

  Future<TransactionEditData?> getTransactionForEditing({
    required int companyId,
    required int voucherNo,
  }) async {
    final target =
        await (db.select(db.transactionsP)..where(
              (t) =>
                  t.companyId.equals(companyId) &
                  t.voucherNo.equals(voucherNo) &
                  (t.isDeleted.isNull() | t.isDeleted.equals(0)),
            ))
            .getSingleOrNull();
    if (target == null) return null;

    final pairLink = (target.others ?? '').trim();
    final isPair = pairLink.startsWith(_cashPairLinkPrefix);
    final groupRows = isPair
        ? await (db.select(db.transactionsP)..where(
                (t) =>
                    t.companyId.equals(companyId) &
                    t.others.equals(pairLink) &
                    (t.isDeleted.isNull() | t.isDeleted.equals(0)),
              ))
              .get()
        : <TransactionsPData>[target];

    if (groupRows.isEmpty) return null;

    final parsedMain = _mainVoucherFromPairLink(pairLink);
    final sortedRows = [...groupRows]
      ..sort((a, b) => a.voucherNo - b.voucherNo);
    final mainRow = sortedRows.firstWhere(
      (row) => parsedMain != null && row.voucherNo == parsedMain,
      orElse: () => sortedRows.first,
    );
    final cashRow = sortedRows.where(
      (row) => row.voucherNo != mainRow.voucherNo,
    );
    final cashAccId = cashRow.isEmpty ? null : cashRow.first.accId;

    final dateText = (mainRow.tDate ?? '').trim();
    final txDate = DateTime.tryParse(dateText);
    final fallback = DateTime.now();

    return TransactionEditData(
      sourceVoucherNo: voucherNo,
      mainVoucherNo: mainRow.voucherNo,
      isCash: isPair,
      accId: mainRow.accId ?? 0,
      accTypeId: mainRow.accTypeId ?? 0,
      cashAccId: cashAccId,
      txDate: txDate ?? fallback,
      description: (mainRow.description ?? '').trim(),
      entryReference: (mainRow.msgNo ?? mainRow.msgNo2 ?? '').trim(),
      debit: mainRow.dr ?? 0.0,
      credit: mainRow.cr ?? 0.0,
      quality: (mainRow.quality ?? '').trim().isEmpty ? null : mainRow.quality,
      rate: mainRow.rate,
      weight: mainRow.weight,
    );
  }

  Future<int> updateTransactionWithLinkedEntries({
    required int companyId,
    required int voucherNo,
    required int accId,
    required int accTypeId,
    required DateTime txDate,
    required String description,
    required String entryReference,
    required double debit,
    required double credit,
    required bool isCash,
    int? cashAccId,
    String? quality,
    double? rate,
    double? weight,
  }) async {
    final actor = await _resolveCurrentActor();
    final cleanDescription = description.trim();
    final cleanReference = entryReference.trim();
    final cleanQuality = quality?.trim();
    final hasDebit = debit > 0;
    final hasCredit = credit > 0;
    final normalizedWeight = weight == null
        ? null
        : (hasCredit ? -weight.abs() : weight.abs());

    if (hasDebit == hasCredit) {
      throw Exception('Exactly one side must be greater than zero');
    }
    if (isCash && cashAccId == null) {
      throw Exception('Cash account is required for cash transaction');
    }
    if (isCash && cashAccId == accId) {
      throw Exception('Cash account must be different from selected account');
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final txDateIso =
        '${txDate.year.toString().padLeft(4, '0')}-${txDate.month.toString().padLeft(2, '0')}-${txDate.day.toString().padLeft(2, '0')}';

    final target =
        await (db.select(db.transactionsP)..where(
              (t) =>
                  t.companyId.equals(companyId) &
                  t.voucherNo.equals(voucherNo) &
                  (t.isDeleted.isNull() | t.isDeleted.equals(0)),
            ))
            .getSingleOrNull();
    if (target == null) {
      throw Exception('Transaction not found');
    }

    final existingPairLink = (target.others ?? '').trim();
    final existingIsPair = existingPairLink.startsWith(_cashPairLinkPrefix);
    final existingRows = existingIsPair
        ? await (db.select(db.transactionsP)..where(
                (t) =>
                    t.companyId.equals(companyId) &
                    t.others.equals(existingPairLink) &
                    (t.isDeleted.isNull() | t.isDeleted.equals(0)),
              ))
              .get()
        : <TransactionsPData>[target];

    _assertCanMutateTransactionRows(existingRows, actor, 'update');

    var mainVoucher =
        _mainVoucherFromPairLink(existingPairLink) ?? target.voucherNo;
    final existingReverse = _reverseVoucherFromPairLink(existingPairLink);

    final existingVoucherNos = existingRows.map((row) => row.voucherNo).toSet();
    if (!existingVoucherNos.contains(mainVoucher) &&
        existingVoucherNos.isNotEmpty) {
      mainVoucher = existingVoucherNos.reduce((a, b) => a < b ? a : b);
    }
    final mainExisting = existingRows.firstWhere(
      (row) => row.voucherNo == mainVoucher,
      orElse: () => target,
    );
    var mainTxGuid = (mainExisting.txGuid ?? '').trim();
    if (mainTxGuid.isEmpty) {
      mainTxGuid = 'legacy-$companyId-$mainVoucher';
    }

    var affected = 0;
    await db.transaction(() async {
      if (!isCash) {
        final isCredit = credit > 0;
        affected +=
            await (db.update(db.transactionsP)..where(
                  (t) =>
                      t.companyId.equals(companyId) &
                      t.voucherNo.equals(mainVoucher),
                ))
                .write(
                  TransactionsPCompanion(
                    txGuid: Value(mainTxGuid),
                    tDate: Value(txDateIso),
                    accId: Value(accId),
                    accTypeId: Value(accTypeId),
                    description: Value(cleanDescription),
                    quality: Value(
                      cleanQuality == null || cleanQuality.isEmpty
                          ? null
                          : cleanQuality,
                    ),
                    rate: Value(rate),
                    weight: Value(normalizedWeight),
                    dr: Value(debit),
                    cr: Value(credit),
                    status: Value(isCredit ? 'jama' : 'banam'),
                    st: Value(isCredit ? 'jamakatha' : 'banamkatha'),
                    currencyStatus: const Value('csave'),
                    cashStatus: const Value('trans'),
                    userId: Value(actor.userId),
                    wName: Value(actor.userEmail),
                    msgNo: Value(
                      cleanReference.isEmpty ? null : cleanReference,
                    ),
                    msgNo2: Value(
                      cleanReference.isEmpty ? null : cleanReference,
                    ),
                    hwls: Value(mainVoucher.toString()),
                    others: const Value(null),
                    isSynced: const Value(0),
                    updatedAt: Value(nowIso),
                    isDeleted: const Value(0),
                  ),
                );

        final extraVoucherNos = existingVoucherNos
            .where((v) => v != mainVoucher)
            .toList(growable: false);
        if (extraVoucherNos.isNotEmpty) {
          affected +=
              await (db.delete(db.transactionsP)..where(
                    (t) =>
                        t.companyId.equals(companyId) &
                        t.voucherNo.isIn(extraVoucherNos),
                  ))
                  .go();
        }
        return;
      }

      var reverseVoucher = existingReverse;
      final reverseExisting = existingRows
          .where((r) {
            return existingReverse != null && r.voucherNo == existingReverse;
          })
          .toList(growable: false);
      var reverseTxGuid = reverseExisting.isEmpty
          ? ''
          : (reverseExisting.first.txGuid ?? '').trim();
      if (reverseVoucher == null || reverseVoucher == mainVoucher) {
        reverseVoucher = await _reserveUniqueVoucherNo(
          minValue: mainVoucher,
          userId: actor.userId,
        );
        reverseTxGuid = _generateTxGuid();
      } else if (reverseTxGuid.isEmpty) {
        reverseTxGuid = 'legacy-$companyId-$reverseVoucher';
      }
      final pairLink = '$_cashPairLinkPrefix$mainVoucher:$reverseVoucher';
      final isCredit = credit > 0;

      affected += await db
          .into(db.transactionsP)
          .insert(
            TransactionsPCompanion(
              voucherNo: Value(mainVoucher),
              txGuid: Value(mainTxGuid),
              tDate: Value(txDateIso),
              accId: Value(accId),
              accTypeId: Value(accTypeId),
              description: Value(cleanDescription),
              quality: Value(
                cleanQuality == null || cleanQuality.isEmpty
                    ? null
                    : cleanQuality,
              ),
              rate: Value(rate),
              weight: Value(normalizedWeight),
              dr: Value(debit),
              cr: Value(credit),
              status: Value(isCredit ? 'jama' : 'banam'),
              st: Value(isCredit ? 'jamakatha' : 'banamkatha'),
              currencyStatus: const Value('csave'),
              cashStatus: const Value('cash'),
              companyId: Value(companyId),
              userId: Value(actor.userId),
              wName: Value(actor.userEmail),
              msgNo: Value(cleanReference.isEmpty ? null : cleanReference),
              msgNo2: Value(cleanReference.isEmpty ? null : cleanReference),
              hwls: Value(mainVoucher.toString()),
              others: Value(pairLink),
              isSynced: const Value(0),
              updatedAt: Value(nowIso),
              isDeleted: const Value(0),
            ),
            mode: InsertMode.insertOrReplace,
          );

      final reverseDebit = hasCredit ? credit : 0.0;
      final reverseCredit = hasDebit ? debit : 0.0;
      final reverseIsCredit = reverseCredit > 0;

      affected += await db
          .into(db.transactionsP)
          .insert(
            TransactionsPCompanion(
              voucherNo: Value(reverseVoucher),
              txGuid: Value(reverseTxGuid),
              tDate: Value(txDateIso),
              accId: Value(cashAccId),
              accTypeId: Value(accTypeId),
              description: Value(cleanDescription),
              quality: Value(
                cleanQuality == null || cleanQuality.isEmpty
                    ? null
                    : cleanQuality,
              ),
              rate: Value(rate),
              weight: Value(normalizedWeight),
              dr: Value(reverseDebit),
              cr: Value(reverseCredit),
              status: Value(reverseIsCredit ? 'jama' : 'banam'),
              st: Value(reverseIsCredit ? 'jamakatha' : 'banamkatha'),
              currencyStatus: const Value('csave'),
              cashStatus: const Value('cash'),
              companyId: Value(companyId),
              userId: Value(actor.userId),
              wName: Value(actor.userEmail),
              msgNo: Value(cleanReference.isEmpty ? null : cleanReference),
              msgNo2: Value(cleanReference.isEmpty ? null : cleanReference),
              hwls: Value(mainVoucher.toString()),
              others: Value(pairLink),
              isSynced: const Value(0),
              updatedAt: Value(nowIso),
              isDeleted: const Value(0),
            ),
            mode: InsertMode.insertOrReplace,
          );

      final keep = <int>{mainVoucher, reverseVoucher};
      final extraVoucherNos = existingVoucherNos
          .where((v) => !keep.contains(v))
          .toList(growable: false);
      if (extraVoucherNos.isNotEmpty) {
        affected +=
            await (db.delete(db.transactionsP)..where(
                  (t) =>
                      t.companyId.equals(companyId) &
                      t.voucherNo.isIn(extraVoucherNos),
                ))
                .go();
      }
    });

    return affected;
  }

  Future<int> deleteTransactionWithLinkedEntries({
    required int companyId,
    required int voucherNo,
  }) async {
    final actor = await _resolveCurrentActor();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final rows = await _loadLinkedTransactionRowsForVoucher(
      companyId: companyId,
      voucherNo: voucherNo,
      includeDeleted: false,
    );

    if (rows.isEmpty) return 0;
    _assertCanMutateTransactionRows(rows, actor, 'delete');

    final voucherNos = rows.map((row) => row.voucherNo).toSet().toList();
    return (db.update(db.transactionsP)..where(
          (t) =>
              t.companyId.equals(companyId) & t.voucherNo.isIn(voucherNos),
        ))
        .write(
          TransactionsPCompanion(
            isDeleted: const Value(1),
            isSynced: const Value(0),
            updatedAt: Value(nowIso),
          ),
        );
  }

  Future<int> restoreTransactionWithLinkedEntries({
    required int companyId,
    required int voucherNo,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final rows = await _loadLinkedTransactionRowsForVoucher(
      companyId: companyId,
      voucherNo: voucherNo,
      includeDeleted: true,
    );

    if (rows.isEmpty) return 0;

    final voucherNos = rows.map((row) => row.voucherNo).toSet().toList();
    return (db.update(db.transactionsP)..where(
          (t) =>
              t.companyId.equals(companyId) & t.voucherNo.isIn(voucherNos),
        ))
        .write(
          TransactionsPCompanion(
            isDeleted: const Value(0),
            isSynced: const Value(0),
            updatedAt: Value(nowIso),
          ),
        );
  }

  Future<int> setAccountTransactionsDeletedState({
    required int companyId,
    required List<int> accIds,
    required bool isDeleted,
  }) async {
    final normalizedIds = accIds.where((id) => id > 0).toSet().toList();
    if (normalizedIds.isEmpty) return 0;

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final voucherRefs = <String>{};
    final pairLinks = <String>{};
    final pairVoucherNos = <int>{};

    for (final idChunk in _chunked(normalizedIds)) {
      final seedRows =
          await (db.select(db.transactionsP)..where((t) {
                final base =
                    t.companyId.equals(companyId) & t.accId.isIn(idChunk);
                if (isDeleted) {
                  return base & (t.isDeleted.isNull() | t.isDeleted.equals(0));
                }
                return base & t.isDeleted.equals(1);
              }))
              .get();

      for (final tx in seedRows) {
        voucherRefs.add(tx.voucherNo.toString());
        final hwls = (tx.hwls ?? '').trim();
        if (hwls.isNotEmpty) voucherRefs.add(hwls);

        final others = (tx.others ?? '').trim();
        if (others.startsWith(_cashPairLinkPrefix)) {
          final mainVoucher = _mainVoucherFromPairLink(others);
          final reverseVoucher = _reverseVoucherFromPairLink(others);
          if (mainVoucher != null && mainVoucher > 0) {
            pairVoucherNos.add(mainVoucher);
          }
          if (reverseVoucher != null && reverseVoucher > 0) {
            pairVoucherNos.add(reverseVoucher);
          }
          if (mainVoucher == null && reverseVoucher == null) {
            pairLinks.add(others);
          }
        }
      }
    }

    final companion = TransactionsPCompanion(
      isDeleted: Value(isDeleted ? 1 : 0),
      isSynced: const Value(0),
      updatedAt: Value(nowIso),
    );

    var updatedRows = 0;
    await db.transaction(() async {
      for (final idChunk in _chunked(normalizedIds)) {
        updatedRows +=
            await (db.update(db.transactionsP)..where((t) {
                  final base =
                      t.companyId.equals(companyId) & t.accId.isIn(idChunk);
                  if (isDeleted) {
                    return base &
                        (t.isDeleted.isNull() | t.isDeleted.equals(0));
                  }
                  return base & t.isDeleted.equals(1);
                }))
                .write(companion);
      }

      if (voucherRefs.isNotEmpty) {
        final refs = voucherRefs.toList(growable: false);
        for (final refsChunk in _chunked(refs)) {
          updatedRows +=
              await (db.update(db.transactionsP)..where((t) {
                    final base =
                        t.companyId.equals(companyId) & t.hwls.isIn(refsChunk);
                    if (isDeleted) {
                      return base &
                          (t.isDeleted.isNull() | t.isDeleted.equals(0));
                    }
                    return base & t.isDeleted.equals(1);
                  }))
                  .write(companion);
        }
      }

      if (pairVoucherNos.isNotEmpty) {
        final vouchers = pairVoucherNos.toList(growable: false);
        for (final voucherChunk in _chunked(vouchers)) {
          updatedRows +=
              await (db.update(db.transactionsP)..where((t) {
                    final base =
                        t.companyId.equals(companyId) &
                        t.voucherNo.isIn(voucherChunk);
                    if (isDeleted) {
                      return base &
                          (t.isDeleted.isNull() | t.isDeleted.equals(0));
                    }
                    return base & t.isDeleted.equals(1);
                  }))
                  .write(companion);
        }
      }

      if (pairLinks.isNotEmpty) {
        final links = pairLinks.toList(growable: false);
        for (final linksChunk in _chunked(links)) {
          updatedRows +=
              await (db.update(db.transactionsP)..where((t) {
                    final base =
                        t.companyId.equals(companyId) &
                        t.others.isIn(linksChunk);
                    if (isDeleted) {
                      return base &
                          (t.isDeleted.isNull() | t.isDeleted.equals(0));
                    }
                    return base & t.isDeleted.equals(1);
                  }))
                  .write(companion);
        }
      }
    });

    return updatedRows;
  }

  Stream<List<TxItemUi>> watchDeletedTransactions({
    required int companyId,
    int limit = 200,
    String? name,
  }) {
    const sql = r'''
      SELECT 
          t.VoucherNo                  AS voucherNo,
          substr(t.TDate,1,10)         AS date,
          COALESCE(p.Name, '')         AS name,
          t.Description                AS description,
          t.Quality                    AS quality,
          t.Rate                       AS rate,
          t.Weight                     AS weight,
          COALESCE(t.Dr, 0)            AS drCents,
          COALESCE(t.Cr, 0)            AS crCents,
          COALESCE(t.UserID, p.UserID) AS UserID,
          t.WName                      AS userEmail,
          t.Status                     AS status,
          COALESCE(at.AccTypeName, '') AS currency
      FROM Transactions_P t
      LEFT JOIN Acc_Personal p ON p.AccID = t.AccID
      LEFT JOIN AccType at      ON at.AccTypeID = t.AccTypeID
      WHERE t.CompanyID = ?1
        AND COALESCE(t.IsDeleted, 0) = 1
        AND (?2 IS NULL OR ?2 = '' OR p.Name LIKE '%' || ?2 || '%')
      ORDER BY COALESCE(t.UpdatedAt, '') DESC, t.VoucherNo DESC
      LIMIT ?3;
    ''';

    return db
        .customSelect(
          sql,
          variables: [
            Variable.withInt(companyId),
            (name == null || name.trim().isEmpty)
                ? const Variable(null)
                : Variable.withString(name.trim()),
            Variable.withInt(limit),
          ],
          readsFrom: {db.transactionsP, db.accPersonal, db.accType},
        )
        .watch()
        .map((rows) => rows.map((r) => TxItemUi.fromRow(r.data)).toList());
  }

  Future<int> purgeDeletedTransactionWithLinkedEntries({
    required int companyId,
    required int voucherNo,
  }) async {
    final target =
        await (db.select(db.transactionsP)..where(
              (t) =>
                  t.voucherNo.equals(voucherNo) &
                  t.companyId.equals(companyId) &
                  t.isDeleted.equals(1),
            ))
            .getSingleOrNull();

    if (target == null) return 0;

    final others = target.others?.trim() ?? '';
    if (others.startsWith(_cashPairLinkPrefix)) {
      return (db.delete(db.transactionsP)..where(
            (t) =>
                t.companyId.equals(companyId) &
                t.others.equals(others) &
                t.isDeleted.equals(1),
          ))
          .go();
    }

    return (db.delete(db.transactionsP)..where(
          (t) =>
              t.voucherNo.equals(voucherNo) &
              t.companyId.equals(companyId) &
              t.isDeleted.equals(1),
        ))
        .go();
  }

  Future<int> purgeAllDeletedTransactions({required int companyId}) {
    return (db.delete(db.transactionsP)
          ..where((t) => t.companyId.equals(companyId) & t.isDeleted.equals(1)))
        .go();
  }

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

    final query =
        """
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

    debugPrint("✅ getPendingByCurrencyClick returned rows=${result.length}");
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

    final query =
        """
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
          variables: [Variable.withInt(accId), Variable.withInt(companyId)],
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

    final query =
        """
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

    final query =
        """
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
          variables: [Variable.withInt(accId), Variable.withInt(companyId)],
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
    int? accId,
    int? accTypeId,
    String? fromDate,
    String? toDate,
  }) async {
    final variables = <Variable>[Variable.withInt(companyId)];
    final filters = StringBuffer();
    var index = 2;

    if ((accId ?? 0) > 0) {
      filters.writeln('   AND tp.AccID = ?$index');
      variables.add(Variable.withInt(accId!));
      index += 1;
    }
    if ((accTypeId ?? 0) > 0) {
      filters.writeln('   AND tp.AccTypeID = ?$index');
      variables.add(Variable.withInt(accTypeId!));
      index += 1;
    }
    if ((fromDate ?? '').trim().isNotEmpty) {
      filters.writeln('   AND substr(tp.TDate, 1, 10) >= ?$index');
      variables.add(Variable.withString(fromDate!.trim()));
      index += 1;
    }
    if ((toDate ?? '').trim().isNotEmpty) {
      filters.writeln('   AND substr(tp.TDate, 1, 10) <= ?$index');
      variables.add(Variable.withString(toDate!.trim()));
    }

    final query = """
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
   AND COALESCE(tp.IsDeleted, 0) = 0
   AND ap.AccID NOT IN (1003, 1004, 1006)
${filters.toString()}
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
          variables: variables,
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
          t.Quality                    AS quality,
          t.Rate                       AS rate,
          t.Weight                     AS weight,
          COALESCE(t.Dr, 0)            AS drCents,
          COALESCE(t.Cr, 0)            AS crCents,
          COALESCE(t.UserID, p.UserID) AS UserID,
          t.WName                      AS userEmail,
          t.Status                     AS status,
          COALESCE(at.AccTypeName, '') AS currency
      FROM Transactions_P t
      INNER JOIN Acc_Personal p ON p.AccID = t.AccID
      INNER JOIN AccType at      ON at.AccTypeID = t.AccTypeID
      WHERE t.CompanyID = ?1
        AND COALESCE(t.IsDeleted, 0) = 0
        AND COALESCE(p.IsDeleted, 0) = 0
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
          variables: [Variable.withInt(companyId), Variable.withInt(limit)],
          readsFrom: {db.accPersonal},
        )
        .get();

    return rows
        .map((r) => (r.data['name'] as String?)?.trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<String>> getCompanyCurrencies({required int companyId}) async {
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
          AND COALESCE(t.IsDeleted, 0) = 0
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
          AND COALESCE(t.IsDeleted, 0) = 0
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

    double fixZero(double v) => v.abs() < 0.005 ? 0.0 : v;

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
              credit: fixZero(cr),
              debit: fixZero(dr),
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

    double fixZero(double v) => v.abs() < 0.005 ? 0.0 : v;

    // ===============================
    // STEP 3: PIVOT DATA (KEEP + & −)
    // ===============================
    final Map<String, Map<String, double>> pivot = {};

    for (final row in rawRows) {
      final name = (row.data['name'] as String?)?.trim();
      final cur = (row.data['cur'] as String?)?.trim();
      final net = fixZero((row.data['net'] as num?)?.toDouble() ?? 0.0);

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

    double fixZero(double v) => v.abs() < 0.005 ? 0.0 : v;

    final Map<String, Map<String, double>> pivot = {};

    for (final row in rawRows) {
      final name = (row.data['name'] as String?)?.trim() ?? 'Unknown';
      final cur = (row.data['cur'] as String?)?.trim();
      final cr = (row.data['sumCr'] as num?)?.toDouble() ?? 0.0;
      final dr = (row.data['sumDr'] as num?)?.toDouble() ?? 0.0;

      final net = fixZero(cr - dr);
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
              t.Quality              AS quality,
              t.Rate                 AS rate,
              t.Weight               AS weight,
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
              t.Quality              AS quality,
              t.Rate                 AS rate,
              t.Weight               AS weight,
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
            AND LOWER(TRIM(COALESCE(P.Name, ''))) <> 'cash in hand'
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
            AND LOWER(TRIM(COALESCE(P.Name, ''))) <> 'cash in hand'
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
