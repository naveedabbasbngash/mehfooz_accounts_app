import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/cupertino.dart';
import '../data/local/app_database.dart';
import '../model/account_head_option.dart';
import '../model/audit_trail_row.dart';
import '../model/balance_currency_ui.dart';
import '../model/balance_matrix_result.dart';
import '../model/balance_row.dart';
import '../model/last_credit_row.dart';
import '../model/pending_currency_summary.dart';
import '../model/pending_group_row.dart';
import '../model/period_lock_row.dart';
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

class _PeriodLockMatch {
  final int periodLockId;
  final String startDate;
  final String endDate;
  final String lockMode;
  final String reason;

  const _PeriodLockMatch({
    required this.periodLockId,
    required this.startDate,
    required this.endDate,
    required this.lockMode,
    required this.reason,
  });
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
  String? _lastComplianceNotice;

  TransactionsRepository(this.db);

  String? consumeLastComplianceNotice() {
    final value = _lastComplianceNotice;
    _lastComplianceNotice = null;
    return value;
  }

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

  String _toDateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _normalizeDateText(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.length >= 10) {
      final firstTen = value.substring(0, 10);
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(firstTen)) {
        return firstTen;
      }
    }
    final parsed = DateTime.tryParse(value.replaceFirst(' ', 'T'));
    if (parsed == null) return '';
    return _toDateOnly(parsed);
  }

  String _normalizeLockMode(String rawMode) {
    final upper = rawMode.trim().toUpperCase();
    return upper == 'SOFT' ? 'SOFT' : 'HARD';
  }

  bool _canBypassPeriodLock({
    required _ActorMeta actor,
    required _PeriodLockMatch lock,
  }) {
    return actor.isAdminOrOwner && _normalizeLockMode(lock.lockMode) == 'SOFT';
  }

  Future<_PeriodLockMatch?> _findActivePeriodLockForDate({
    required int companyId,
    required String dateText,
  }) async {
    if (companyId <= 0 || dateText.isEmpty) return null;
    final rows = await db
        .customSelect(
          '''
          SELECT PeriodLockID, StartDate, EndDate, COALESCE(Reason, '') AS Reason
            , COALESCE(NULLIF(TRIM(LockMode), ''), 'HARD') AS LockMode
          FROM PeriodLocks
          WHERE CompanyID = ?1
            AND COALESCE(IsActive, 1) = 1
            AND date(?2) BETWEEN date(StartDate) AND date(EndDate)
          ORDER BY PeriodLockID DESC
          LIMIT 1
          ''',
          variables: [
            Variable.withInt(companyId),
            Variable.withString(dateText),
          ],
        )
        .get();
    if (rows.isEmpty) return null;
    final data = rows.first.data;
    return _PeriodLockMatch(
      periodLockId: _toInt(data['PeriodLockID']),
      startDate: _toText(data['StartDate']),
      endDate: _toText(data['EndDate']),
      lockMode: _normalizeLockMode(_toText(data['LockMode'])),
      reason: _toText(data['Reason']),
    );
  }

  Future<bool> isDateLocked({
    required int companyId,
    required DateTime date,
  }) async {
    final lock = await _findActivePeriodLockForDate(
      companyId: companyId,
      dateText: _toDateOnly(date),
    );
    return lock != null;
  }

  Future<DateTime> _nextOpenDate({
    required int companyId,
    DateTime? preferred,
  }) async {
    var cursor = (preferred ?? DateTime.now()).toUtc();
    for (var i = 0; i < 366; i++) {
      final locked = await isDateLocked(companyId: companyId, date: cursor);
      if (!locked) {
        return DateTime.utc(cursor.year, cursor.month, cursor.day);
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    throw Exception(
      'No open accounting date available for the next 12 months. Unlock a period first.',
    );
  }

  Future<void> _appendAuditTrail({
    required String entityType,
    required String action,
    String entityId = '',
    String message = '',
    int? companyId,
    Map<String, dynamic>? payload,
    _ActorMeta? actor,
  }) async {
    final resolvedActor = actor ?? await _resolveCurrentActor();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await db.customStatement(
      '''
      INSERT INTO AuditTrail
        (CompanyID, EntityType, EntityID, Action, Message, Payload, ActorUserID, ActorEmail, CreatedAt)
      VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)
      ''',
      [
        companyId,
        entityType,
        entityId.isEmpty ? null : entityId,
        action,
        message.isEmpty ? null : message,
        payload == null ? null : jsonEncode(payload),
        resolvedActor.userId,
        resolvedActor.userEmail,
        nowIso,
      ],
    );
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
  Future<List<AccountHeadListRow>> getAccountHeadRows() async {
    final rows = await db
        .customSelect(
          '''
          SELECT
            AccountHeadID,
            AccountHeadName,
            COALESCE(NormalBalance, '') AS NormalBalance
          FROM AccountHeads
          WHERE COALESCE(IsDeleted, 0) = 0
          ORDER BY AccountHeadID ASC
          ''',
          readsFrom: {db.accountHeads},
        )
        .get();

    return rows
        .map((r) {
          final id = _toInt(r.data['AccountHeadID']);
          final name = _toText(r.data['AccountHeadName']);
          if (id <= 0 || name.isEmpty) return null;
          return AccountHeadListRow(
            accountHeadId: id,
            accountHeadName: name,
            normalBalance: _toText(r.data['NormalBalance']),
          );
        })
        .whereType<AccountHeadListRow>()
        .toList(growable: false);
  }

  Future<int> getNextAccountHeadRowId() async {
    final row = await db
        .customSelect(
          '''
          SELECT COALESCE(MAX(CAST(AccountHeadID AS INTEGER)), 0) + 1 AS next_id
          FROM AccountHeads
          ''',
          readsFrom: {db.accountHeads},
        )
        .getSingle();
    return _toInt(row.data['next_id']).clamp(1, _maxSafeVoucherNo).toInt();
  }

  Future<int> createAccountHeadRow({
    required String accountHeadName,
    required String normalBalance,
  }) async {
    throw UnsupportedError(
      'Account heads are locked master data. Add sub heads or chart accounts instead.',
    );
  }

  Future<void> updateAccountHeadRow({
    required int accountHeadId,
    required String accountHeadName,
    required String normalBalance,
  }) async {
    throw UnsupportedError(
      'Account heads are locked master data. Edit sub heads or chart accounts instead.',
    );
  }

  Future<void> deleteAccountHeadRow({required int accountHeadId}) async {
    throw UnsupportedError(
      'Account heads are locked master data and cannot be deleted.',
    );
  }

  Future<List<AccountSubHeadListRow>> getAccountSubHeadRows() async {
    final rows = await db
        .customSelect(
          '''
          SELECT
            ash.AccountSubHeadID,
            ash.AccountHeadID,
            COALESCE(ash.Code, '') AS Code,
            ash.AccountSubHeadName,
            COALESCE(ah.AccountHeadName, '') AS AccountHeadName
          FROM AccountSubHeads ash
          LEFT JOIN AccountHeads ah ON ah.AccountHeadID = ash.AccountHeadID
          WHERE COALESCE(ash.IsDeleted, 0) = 0
          ORDER BY ash.AccountHeadID ASC,
                   ash.Code COLLATE NOCASE ASC,
                   ash.AccountSubHeadID ASC
          ''',
          readsFrom: {db.accountSubHeads, db.accountHeads},
        )
        .get();

    return rows
        .map((r) {
          final id = _toInt(r.data['AccountSubHeadID']);
          final name = _toText(r.data['AccountSubHeadName']);
          if (id <= 0 || name.isEmpty) return null;
          return AccountSubHeadListRow(
            accountSubHeadId: id,
            accountHeadId: _toInt(r.data['AccountHeadID']),
            code: _toText(r.data['Code']),
            accountSubHeadName: name,
            accountHeadName: _toText(r.data['AccountHeadName']),
          );
        })
        .whereType<AccountSubHeadListRow>()
        .toList(growable: false);
  }

  Future<int> getNextAccountSubHeadId() async {
    final row = await db
        .customSelect(
          '''
          SELECT COALESCE(MAX(CAST(AccountSubHeadID AS INTEGER)), 0) + 1 AS next_id
          FROM AccountSubHeads
          ''',
          readsFrom: {db.accountSubHeads},
        )
        .getSingle();
    final localNext = _toInt(row.data['next_id']);
    return _nextDistributedIntId(
      table: 'AccountSubHeads',
      column: 'AccountSubHeadID',
      localNext: localNext,
    );
  }

  String _accountHeadCode(int accountHeadId) =>
      accountHeadId.toString().padLeft(2, '0');

  int _hierarchyCodeSuffix(String code, String prefix) {
    final match = RegExp(
      '^${RegExp.escape(prefix)}-(\\d+)\$',
    ).firstMatch(code.trim());
    if (match == null) return 0;
    return int.tryParse(match.group(1) ?? '') ?? 0;
  }

  Future<String> getNextAccountSubHeadCode({
    required int accountHeadId,
    int? excludingAccountSubHeadId,
  }) async {
    if (accountHeadId <= 0) return '';

    final headCode = _accountHeadCode(accountHeadId);
    final rows = await db
        .customSelect(
          '''
          SELECT COALESCE(Code, '') AS Code
          FROM AccountSubHeads
          WHERE AccountHeadID = ?1
            AND AccountSubHeadID <> ?2
            AND COALESCE(IsDeleted, 0) = 0
          ''',
          variables: [
            Variable.withInt(accountHeadId),
            Variable.withInt(excludingAccountSubHeadId ?? 0),
          ],
          readsFrom: {db.accountSubHeads},
        )
        .get();

    var maxSuffix = 0;
    for (final row in rows) {
      final suffix = _hierarchyCodeSuffix(_toText(row.data['Code']), headCode);
      if (suffix > maxSuffix) maxSuffix = suffix;
    }
    return '$headCode-${(maxSuffix + 1).toString().padLeft(2, '0')}';
  }

  Future<String> getNextChartAccountCode({
    required int accountSubHeadId,
    int? excludingChartOfAccountId,
  }) async {
    if (accountSubHeadId <= 0) return '';

    final subHeadRows = await db
        .customSelect(
          '''
          SELECT COALESCE(Code, '') AS Code
          FROM AccountSubHeads
          WHERE AccountSubHeadID = ?1
            AND COALESCE(IsDeleted, 0) = 0
          LIMIT 1
          ''',
          variables: [Variable.withInt(accountSubHeadId)],
          readsFrom: {db.accountSubHeads},
        )
        .get();
    if (subHeadRows.isEmpty) return '';

    final subHeadCode = _toText(subHeadRows.first.data['Code']);
    if (subHeadCode.isEmpty) return '';

    final rows = await db
        .customSelect(
          '''
          SELECT COALESCE(Code, '') AS Code
          FROM ChartOfAccounts
          WHERE AccountSubHeadID = ?1
            AND ChartOfAccountID <> ?2
            AND COALESCE(IsDeleted, 0) = 0
          ''',
          variables: [
            Variable.withInt(accountSubHeadId),
            Variable.withInt(excludingChartOfAccountId ?? 0),
          ],
          readsFrom: {db.chartOfAccounts},
        )
        .get();

    var maxSuffix = 0;
    for (final row in rows) {
      final suffix = _hierarchyCodeSuffix(
        _toText(row.data['Code']),
        subHeadCode,
      );
      if (suffix > maxSuffix) maxSuffix = suffix;
    }
    return '$subHeadCode-${(maxSuffix + 1).toString().padLeft(3, '0')}';
  }

  Future<void> _assertUniqueSubHead({
    required int accountSubHeadId,
    required int accountHeadId,
    required String code,
    required String name,
  }) async {
    final rows = await db
        .customSelect(
          '''
          SELECT AccountSubHeadID
          FROM AccountSubHeads
          WHERE COALESCE(IsDeleted, 0) = 0
            AND AccountSubHeadID <> ?1
            AND (
              (TRIM(COALESCE(?2, '')) <> '' AND LOWER(TRIM(COALESCE(Code, ''))) = LOWER(TRIM(?2)))
              OR (AccountHeadID = ?3 AND LOWER(TRIM(AccountSubHeadName)) = LOWER(TRIM(?4)))
            )
          LIMIT 1
          ''',
          variables: [
            Variable.withInt(accountSubHeadId),
            Variable.withString(code),
            Variable.withInt(accountHeadId),
            Variable.withString(name),
          ],
          readsFrom: {db.accountSubHeads},
        )
        .get();
    if (rows.isNotEmpty) {
      throw ArgumentError(
        'Sub head already exists with the same code or name.',
      );
    }
  }

  Future<int> createAccountSubHead({
    required int accountHeadId,
    required String accountSubHeadName,
    String code = '',
  }) async {
    final normalized = accountSubHeadName.trim();
    final cleanCode = code.trim();
    if (accountHeadId <= 0) {
      throw ArgumentError('Account head is required.');
    }
    if (normalized.isEmpty) {
      throw ArgumentError('Sub head name cannot be empty.');
    }
    final resolvedCode = cleanCode.isEmpty
        ? await getNextAccountSubHeadCode(accountHeadId: accountHeadId)
        : cleanCode;

    await _assertUniqueSubHead(
      accountSubHeadId: 0,
      accountHeadId: accountHeadId,
      code: resolvedCode,
      name: normalized,
    );

    final newId = await getNextAccountSubHeadId();
    await db.customStatement(
      '''
      INSERT INTO AccountSubHeads
        (AccountSubHeadID, AccountHeadID, Code, AccountSubHeadName,
         IsDeleted, IsSynced, UpdatedAt)
      VALUES (?1, ?2, ?3, ?4, 0, 0, ?5)
      ''',
      [
        newId,
        accountHeadId,
        resolvedCode.isEmpty ? null : resolvedCode,
        normalized,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
    await _appendAuditTrail(
      entityType: 'account_sub_head',
      action: 'create',
      entityId: newId.toString(),
      message: 'Account sub head created',
      payload: {
        'accountSubHeadId': newId,
        'accountHeadId': accountHeadId,
        'name': normalized,
        'code': resolvedCode,
      },
    );
    return newId;
  }

  Future<void> updateAccountSubHead({
    required int accountSubHeadId,
    required int accountHeadId,
    required String accountSubHeadName,
    String code = '',
  }) async {
    final normalized = accountSubHeadName.trim();
    final cleanCode = code.trim();
    if (accountSubHeadId <= 0) {
      throw ArgumentError('Sub head id is required.');
    }
    if (accountHeadId <= 0) {
      throw ArgumentError('Account head is required.');
    }
    if (normalized.isEmpty) {
      throw ArgumentError('Sub head name cannot be empty.');
    }
    final resolvedCode = cleanCode.isEmpty
        ? await getNextAccountSubHeadCode(
            accountHeadId: accountHeadId,
            excludingAccountSubHeadId: accountSubHeadId,
          )
        : cleanCode;

    await _assertUniqueSubHead(
      accountSubHeadId: accountSubHeadId,
      accountHeadId: accountHeadId,
      code: resolvedCode,
      name: normalized,
    );

    await db.customStatement(
      '''
      UPDATE AccountSubHeads
      SET AccountHeadID = ?1,
          Code = ?2,
          AccountSubHeadName = ?3,
          IsSynced = 0,
          UpdatedAt = ?4
      WHERE AccountSubHeadID = ?5
      ''',
      [
        accountHeadId,
        resolvedCode.isEmpty ? null : resolvedCode,
        normalized,
        DateTime.now().toUtc().toIso8601String(),
        accountSubHeadId,
      ],
    );
    await db.customStatement(
      '''
      UPDATE ChartOfAccounts
      SET AccountHeadID = ?1,
          IsSynced = 0,
          UpdatedAt = ?2
      WHERE AccountSubHeadID = ?3
        AND COALESCE(IsDeleted, 0) = 0
      ''',
      [
        accountHeadId,
        DateTime.now().toUtc().toIso8601String(),
        accountSubHeadId,
      ],
    );
    await _appendAuditTrail(
      entityType: 'account_sub_head',
      action: 'update',
      entityId: accountSubHeadId.toString(),
      message: 'Account sub head updated',
      payload: {
        'accountSubHeadId': accountSubHeadId,
        'accountHeadId': accountHeadId,
        'name': normalized,
        'code': resolvedCode,
      },
    );
  }

  Future<void> deleteAccountSubHead({required int accountSubHeadId}) async {
    if (accountSubHeadId <= 0) return;
    final usage = await db
        .customSelect(
          '''
          SELECT COUNT(*) AS total
          FROM ChartOfAccounts
          WHERE AccountSubHeadID = ?1
            AND COALESCE(IsDeleted, 0) = 0
          ''',
          variables: [Variable.withInt(accountSubHeadId)],
          readsFrom: {db.chartOfAccounts},
        )
        .getSingle();
    if (_toInt(usage.data['total']) > 0) {
      throw ArgumentError(
        'Cannot delete sub head because chart accounts are linked to it.',
      );
    }

    await db.customStatement(
      '''
      UPDATE AccountSubHeads
      SET IsDeleted = 1,
          IsSynced = 0,
          UpdatedAt = ?1
      WHERE AccountSubHeadID = ?2
      ''',
      [DateTime.now().toUtc().toIso8601String(), accountSubHeadId],
    );
    await _appendAuditTrail(
      entityType: 'account_sub_head',
      action: 'delete',
      entityId: accountSubHeadId.toString(),
      message: 'Account sub head deleted',
      payload: {'accountSubHeadId': accountSubHeadId},
    );
  }

  Future<List<AccountHeadOption>> getAllAccountHeads() async {
    final rows = await db
        .customSelect(
          '''
          SELECT
            coa.ChartOfAccountID,
            coa.ChartOfAccountName,
            COALESCE(coa.Code, '') AS ChartCode,
            ah.AccountHeadID,
            ah.AccountHeadName,
            ash.AccountSubHeadID,
            ash.Code AS AccountSubHeadCode,
            ash.AccountSubHeadName
          FROM ChartOfAccounts coa
          LEFT JOIN AccountHeads ah ON ah.AccountHeadID = coa.AccountHeadID
          LEFT JOIN AccountSubHeads ash
            ON ash.AccountSubHeadID = coa.AccountSubHeadID
           AND COALESCE(ash.IsDeleted, 0) = 0
          WHERE COALESCE(coa.IsDeleted, 0) = 0
          ORDER BY coa.ChartOfAccountName COLLATE NOCASE ASC,
                   coa.ChartOfAccountID ASC
          ''',
          readsFrom: {db.chartOfAccounts, db.accountHeads, db.accountSubHeads},
        )
        .get();

    return rows
        .map((r) {
          final id = _toInt(r.data['ChartOfAccountID']);
          final name = _toText(r.data['ChartOfAccountName']);
          if (id <= 0 || name.isEmpty) return null;
          return AccountHeadOption(
            accHeadId: id,
            accHeadName: name,
            accountHeadId: _toInt(r.data['AccountHeadID']),
            accountHeadName: _toText(r.data['AccountHeadName']),
            accountSubHeadId: _toInt(r.data['AccountSubHeadID']),
            accountSubHeadCode: _toText(r.data['AccountSubHeadCode']),
            accountSubHeadName: _toText(r.data['AccountSubHeadName']),
            chartCode: _toText(r.data['ChartCode']),
          );
        })
        .whereType<AccountHeadOption>()
        .toList(growable: false);
  }

  Future<int> getNextAccountHeadId() async {
    final row = await db
        .customSelect(
          '''
          SELECT COALESCE(MAX(CAST(ChartOfAccountID AS INTEGER)), 0) + 1 AS next_id
          FROM ChartOfAccounts
          ''',
          readsFrom: {db.chartOfAccounts},
        )
        .getSingle();
    final localNext = _toInt(row.data['next_id']);
    return _nextDistributedIntId(
      table: 'ChartOfAccounts',
      column: 'ChartOfAccountID',
      localNext: localNext,
    );
  }

  Future<void> _assertUniqueChartAccount({
    required int chartOfAccountId,
    required String chartName,
    required String code,
  }) async {
    final rows = await db
        .customSelect(
          '''
          SELECT ChartOfAccountID
          FROM ChartOfAccounts
          WHERE COALESCE(IsDeleted, 0) = 0
            AND ChartOfAccountID <> ?1
            AND (
              LOWER(TRIM(ChartOfAccountName)) = LOWER(TRIM(?2))
              OR (TRIM(COALESCE(?3, '')) <> '' AND LOWER(TRIM(COALESCE(Code, ''))) = LOWER(TRIM(?3)))
            )
          LIMIT 1
          ''',
          variables: [
            Variable.withInt(chartOfAccountId),
            Variable.withString(chartName),
            Variable.withString(code),
          ],
          readsFrom: {db.chartOfAccounts},
        )
        .get();
    if (rows.isNotEmpty) {
      throw ArgumentError(
        'Chart account already exists with the same name or code.',
      );
    }
  }

  Future<int?> findAccountHeadIdByNameLoose(String accHeadName) async {
    final normalized = accHeadName.trim();
    if (normalized.isEmpty) return null;

    final rows = await db
        .customSelect(
          '''
          SELECT ChartOfAccountID
          FROM ChartOfAccounts
          WHERE LOWER(TRIM(COALESCE(ChartOfAccountName, ''))) = LOWER(TRIM(?1))
            AND COALESCE(IsDeleted, 0) = 0
          LIMIT 1
          ''',
          variables: [Variable.withString(normalized)],
          readsFrom: {db.chartOfAccounts},
        )
        .get();

    if (rows.isEmpty) return null;
    final id = _toInt(rows.first.data['ChartOfAccountID']);
    return id > 0 ? id : null;
  }

  Future<int> createAccountHead({required String accHeadName}) async {
    final normalized = accHeadName.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('Head name cannot be empty.');
    }

    final accountHeadId = _accountHeadIdForChartName(normalized);
    final accountSubHeadId = _accountSubHeadIdForChartName(
      normalized,
      accountHeadId,
    );
    return createChartAccount(
      chartAccountName: normalized,
      accountHeadId: accountHeadId,
      accountSubHeadId: accountSubHeadId,
    );
  }

  Future<int> createChartAccount({
    required String chartAccountName,
    required int accountHeadId,
    required int accountSubHeadId,
    String code = '',
  }) async {
    final normalized = chartAccountName.trim();
    final cleanCode = code.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('Chart account name cannot be empty.');
    }
    if (accountHeadId <= 0) {
      throw ArgumentError('Account head is required.');
    }
    if (accountSubHeadId <= 0) {
      throw ArgumentError('Account sub head is required.');
    }
    final validMap = await db
        .customSelect(
          '''
          SELECT 1
          FROM AccountSubHeads
          WHERE AccountSubHeadID = ?1
            AND AccountHeadID = ?2
            AND COALESCE(IsDeleted, 0) = 0
          LIMIT 1
          ''',
          variables: [
            Variable.withInt(accountSubHeadId),
            Variable.withInt(accountHeadId),
          ],
          readsFrom: {db.accountSubHeads},
        )
        .get();
    if (validMap.isEmpty) {
      throw ArgumentError(
        'Selected sub head does not belong to the selected head.',
      );
    }
    final resolvedCode = cleanCode.isEmpty
        ? await getNextChartAccountCode(accountSubHeadId: accountSubHeadId)
        : cleanCode;

    await _assertUniqueChartAccount(
      chartOfAccountId: 0,
      chartName: normalized,
      code: resolvedCode,
    );

    final newId = await getNextAccountHeadId();
    await db.customStatement(
      '''
      INSERT INTO ChartOfAccounts
        (ChartOfAccountID, AccountHeadID, AccountSubHeadID, ChartOfAccountName,
         Code, IsDeleted, IsSynced, UpdatedAt)
      VALUES (?1, ?2, ?3, ?4, ?5, 0, 0, ?6)
      ''',
      [
        newId,
        accountHeadId,
        accountSubHeadId,
        normalized,
        resolvedCode.isEmpty ? null : resolvedCode,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
    await _appendAuditTrail(
      entityType: 'chart_account',
      action: 'create',
      entityId: newId.toString(),
      message: 'Chart account created',
      payload: {
        'chartOfAccountId': newId,
        'name': normalized,
        'accountHeadId': accountHeadId,
        'accountSubHeadId': accountSubHeadId,
        'code': resolvedCode,
      },
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

    final existing = await db
        .customSelect(
          '''
          SELECT AccountHeadID, AccountSubHeadID, COALESCE(Code, '') AS Code
          FROM ChartOfAccounts
          WHERE ChartOfAccountID = ?1
          LIMIT 1
          ''',
          variables: [Variable.withInt(accHeadId)],
          readsFrom: {db.chartOfAccounts},
        )
        .get();
    final row = existing.isEmpty ? null : existing.first.data;
    await updateChartAccount(
      chartOfAccountId: accHeadId,
      chartAccountName: normalized,
      accountHeadId: _toInt(row?['AccountHeadID']) > 0
          ? _toInt(row?['AccountHeadID'])
          : _accountHeadIdForChartName(normalized),
      accountSubHeadId: _toInt(row?['AccountSubHeadID']) > 0
          ? _toInt(row?['AccountSubHeadID'])
          : _accountSubHeadIdForChartName(
              normalized,
              _accountHeadIdForChartName(normalized),
            ),
      code: _toText(row?['Code']),
    );
  }

  Future<void> updateChartAccount({
    required int chartOfAccountId,
    required String chartAccountName,
    required int accountHeadId,
    required int accountSubHeadId,
    String code = '',
  }) async {
    final normalized = chartAccountName.trim();
    final cleanCode = code.trim();
    if (chartOfAccountId <= 0) {
      throw ArgumentError('Chart account id is required.');
    }
    if (normalized.isEmpty) {
      throw ArgumentError('Chart account name cannot be empty.');
    }
    if (accountHeadId <= 0) {
      throw ArgumentError('Account head is required.');
    }
    if (accountSubHeadId <= 0) {
      throw ArgumentError('Account sub head is required.');
    }
    final validMap = await db
        .customSelect(
          '''
          SELECT 1
          FROM AccountSubHeads
          WHERE AccountSubHeadID = ?1
            AND AccountHeadID = ?2
            AND COALESCE(IsDeleted, 0) = 0
          LIMIT 1
          ''',
          variables: [
            Variable.withInt(accountSubHeadId),
            Variable.withInt(accountHeadId),
          ],
          readsFrom: {db.accountSubHeads},
        )
        .get();
    if (validMap.isEmpty) {
      throw ArgumentError(
        'Selected sub head does not belong to the selected head.',
      );
    }
    final resolvedCode = cleanCode.isEmpty
        ? await getNextChartAccountCode(
            accountSubHeadId: accountSubHeadId,
            excludingChartOfAccountId: chartOfAccountId,
          )
        : cleanCode;

    await _assertUniqueChartAccount(
      chartOfAccountId: chartOfAccountId,
      chartName: normalized,
      code: resolvedCode,
    );

    await db.customStatement(
      '''
      UPDATE ChartOfAccounts
      SET AccountHeadID = ?1,
          AccountSubHeadID = ?2,
          ChartOfAccountName = ?3,
          Code = ?4,
          IsSynced = 0,
          UpdatedAt = ?5
      WHERE ChartOfAccountID = ?6
      ''',
      [
        accountHeadId,
        accountSubHeadId,
        normalized,
        resolvedCode.isEmpty ? null : resolvedCode,
        DateTime.now().toUtc().toIso8601String(),
        chartOfAccountId,
      ],
    );
    await _appendAuditTrail(
      entityType: 'chart_account',
      action: 'update',
      entityId: chartOfAccountId.toString(),
      message: 'Chart account updated',
      payload: {
        'chartOfAccountId': chartOfAccountId,
        'name': normalized,
        'accountHeadId': accountHeadId,
        'accountSubHeadId': accountSubHeadId,
        'code': resolvedCode,
      },
    );
  }

  Future<void> deleteAccountHead({required int accHeadId}) async {
    await deleteChartAccount(chartOfAccountId: accHeadId);
  }

  Future<void> deleteChartAccount({required int chartOfAccountId}) async {
    if (chartOfAccountId <= 0) return;
    final usage = await db
        .customSelect(
          '''
          SELECT COUNT(*) AS total
          FROM Acc_Personal
          WHERE ChartOfAccountID = ?1
            AND COALESCE(IsDeleted, 0) = 0
          ''',
          variables: [Variable.withInt(chartOfAccountId)],
          readsFrom: {db.accPersonal},
        )
        .getSingle();
    if (_toInt(usage.data['total']) > 0) {
      throw ArgumentError(
        'Cannot delete chart account because accounts are linked to it.',
      );
    }

    await db.customStatement(
      '''
      UPDATE ChartOfAccounts
      SET IsDeleted = 1,
          IsSynced = 0,
          UpdatedAt = ?1
      WHERE ChartOfAccountID = ?2
      ''',
      [DateTime.now().toUtc().toIso8601String(), chartOfAccountId],
    );
    await _appendAuditTrail(
      entityType: 'chart_account',
      action: 'delete',
      entityId: chartOfAccountId.toString(),
      message: 'Chart of account deleted',
      payload: {'chartOfAccountId': chartOfAccountId},
    );
  }

  // =========================================================
  // COMPLIANCE (Period Locks + Audit Trail)
  // =========================================================
  Future<List<PeriodLockRow>> getPeriodLocks({required int companyId}) async {
    final rows = await db
        .customSelect(
          '''
          SELECT
            PeriodLockID,
            CompanyID,
            StartDate,
            EndDate,
            COALESCE(NULLIF(TRIM(LockMode), ''), 'HARD') AS LockMode,
            COALESCE(Reason, '') AS Reason,
            COALESCE(IsActive, 1) AS IsActive,
            COALESCE(CreatedAt, '') AS CreatedAt,
            CreatedByUserID,
            CreatedByEmail
          FROM PeriodLocks
          WHERE CompanyID = ?1
          ORDER BY COALESCE(IsActive, 1) DESC, PeriodLockID DESC
          ''',
          variables: [Variable.withInt(companyId)],
        )
        .get();

    return rows
        .map(
          (r) => PeriodLockRow(
            periodLockId: _toInt(r.data['PeriodLockID']),
            companyId: _toInt(r.data['CompanyID']),
            startDate: _toText(r.data['StartDate']),
            endDate: _toText(r.data['EndDate']),
            lockMode: _normalizeLockMode(_toText(r.data['LockMode'])),
            reason: _toText(r.data['Reason']),
            isActive: _toInt(r.data['IsActive']) == 1,
            createdAt: _toText(r.data['CreatedAt']),
            createdByUserId: _toInt(r.data['CreatedByUserID']) <= 0
                ? null
                : _toInt(r.data['CreatedByUserID']),
            createdByEmail: _toText(r.data['CreatedByEmail']).isEmpty
                ? null
                : _toText(r.data['CreatedByEmail']),
          ),
        )
        .toList(growable: false);
  }

  Future<int> createPeriodLock({
    required int companyId,
    required DateTime startDate,
    required DateTime endDate,
    String lockMode = 'HARD',
    String reason = '',
  }) async {
    if (companyId <= 0) {
      throw ArgumentError('Company is required for period lock.');
    }
    final from = DateTime.utc(startDate.year, startDate.month, startDate.day);
    final to = DateTime.utc(endDate.year, endDate.month, endDate.day);
    if (from.isAfter(to)) {
      throw ArgumentError('Start date cannot be after end date.');
    }

    final fromText = _toDateOnly(from);
    final toText = _toDateOnly(to);
    final normalizedLockMode = _normalizeLockMode(lockMode);
    final overlap = await db
        .customSelect(
          '''
          SELECT PeriodLockID
          FROM PeriodLocks
          WHERE CompanyID = ?1
            AND COALESCE(IsActive, 1) = 1
            AND date(StartDate) <= date(?2)
            AND date(EndDate) >= date(?3)
          LIMIT 1
          ''',
          variables: [
            Variable.withInt(companyId),
            Variable.withString(toText),
            Variable.withString(fromText),
          ],
        )
        .get();
    if (overlap.isNotEmpty) {
      throw ArgumentError('A lock already exists for the selected date range.');
    }

    final actor = await _resolveCurrentActor();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await db.customStatement(
      '''
      INSERT INTO PeriodLocks
        (CompanyID, StartDate, EndDate, LockMode, Reason, IsActive, CreatedByUserID, CreatedByEmail, CreatedAt, UpdatedAt)
      VALUES (?1, ?2, ?3, ?4, ?5, 1, ?6, ?7, ?8, ?9)
      ''',
      [
        companyId,
        fromText,
        toText,
        normalizedLockMode,
        reason.trim().isEmpty ? null : reason.trim(),
        actor.userId,
        actor.userEmail,
        nowIso,
        nowIso,
      ],
    );

    final idRow = await db
        .customSelect('SELECT last_insert_rowid() AS id')
        .getSingle();
    final periodLockId = _toInt(idRow.data['id']);
    await _appendAuditTrail(
      companyId: companyId,
      entityType: 'period_lock',
      action: 'create',
      entityId: periodLockId.toString(),
      message: 'Period lock created',
      actor: actor,
      payload: {
        'periodLockId': periodLockId,
        'startDate': fromText,
        'endDate': toText,
        'lockMode': normalizedLockMode,
        'reason': reason.trim(),
      },
    );
    return periodLockId;
  }

  Future<void> deactivatePeriodLock({
    required int periodLockId,
    required int companyId,
    String reason = '',
  }) async {
    if (periodLockId <= 0) return;
    final actor = await _resolveCurrentActor();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await db.customStatement(
      '''
      UPDATE PeriodLocks
      SET IsActive = 0,
          UpdatedAt = ?1
      WHERE PeriodLockID = ?2
        AND CompanyID = ?3
      ''',
      [nowIso, periodLockId, companyId],
    );
    await _appendAuditTrail(
      companyId: companyId,
      entityType: 'period_lock',
      action: 'deactivate',
      entityId: periodLockId.toString(),
      actor: actor,
      message: 'Period lock deactivated',
      payload: {'periodLockId': periodLockId, 'reason': reason.trim()},
    );
  }

  Future<List<AuditTrailRow>> getAuditTrailRows({
    required int companyId,
    int limit = 300,
  }) async {
    final rows = await db
        .customSelect(
          '''
          SELECT
            AuditID,
            CompanyID,
            COALESCE(EntityType, '') AS EntityType,
            COALESCE(EntityID, '') AS EntityID,
            COALESCE(Action, '') AS Action,
            COALESCE(Message, '') AS Message,
            COALESCE(Payload, '') AS Payload,
            ActorUserID,
            ActorEmail,
            COALESCE(CreatedAt, '') AS CreatedAt
          FROM AuditTrail
          WHERE CompanyID = ?1 OR CompanyID IS NULL
          ORDER BY AuditID DESC
          LIMIT ?2
          ''',
          variables: [Variable.withInt(companyId), Variable.withInt(limit)],
        )
        .get();

    return rows
        .map(
          (r) => AuditTrailRow(
            auditId: _toInt(r.data['AuditID']),
            companyId: _toInt(r.data['CompanyID']) <= 0
                ? null
                : _toInt(r.data['CompanyID']),
            entityType: _toText(r.data['EntityType']),
            entityId: _toText(r.data['EntityID']),
            action: _toText(r.data['Action']),
            message: _toText(r.data['Message']),
            payload: _toText(r.data['Payload']),
            actorUserId: _toInt(r.data['ActorUserID']) <= 0
                ? null
                : _toInt(r.data['ActorUserID']),
            actorEmail: _toText(r.data['ActorEmail']).isEmpty
                ? null
                : _toText(r.data['ActorEmail']),
            createdAt: _toText(r.data['CreatedAt']),
          ),
        )
        .toList(growable: false);
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
              AccountTypeID = ?4,
              AssignmentGuid = COALESCE(NULLIF(TRIM(AssignmentGuid), ''), ?5)
          WHERE RegID = ?6
          ''',
          [nowIso, resolvedCompanyId, accId, accTypeId, Ulid.generate(), regId],
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
        (RegID, AssignmentGuid, AccID, AccountTypeID, CompanyID, IsDeleted, IsSynced, UpdatedAt)
      VALUES (?1, ?2, ?3, ?4, ?5, 0, 0, ?6)
      ''',
      [nextRegId, Ulid.generate(), accId, accTypeId, resolvedCompanyId, nowIso],
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

  Future<void> _assertUniqueAccountNameForCompany({
    required int companyId,
    required String accountName,
    int excludingAccId = 0,
  }) async {
    final rows = await db
        .customSelect(
          '''
          SELECT AccID
          FROM Acc_Personal
          WHERE COALESCE(IsDeleted, 0) = 0
            AND CompanyID = ?1
            AND AccID <> ?2
            AND LOWER(TRIM(COALESCE(Name, ''))) = LOWER(TRIM(?3))
          LIMIT 1
          ''',
          variables: [
            Variable.withInt(companyId),
            Variable.withInt(excludingAccId),
            Variable.withString(accountName),
          ],
          readsFrom: {db.accPersonal},
        )
        .get();
    if (rows.isNotEmpty) {
      throw ArgumentError('An account with this name already exists.');
    }
  }

  Future<int> createAccountForCompany({
    required int companyId,
    required String name,
    String? phone,
    String? address,
    String? statusg,
    int? chartOfAccountId,
  }) async {
    final nextAccId = await getNextAccId();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError('Account name cannot be empty.');
    }
    await _assertUniqueAccountNameForCompany(
      companyId: companyId,
      accountName: normalizedName,
    );
    if (chartOfAccountId != null && chartOfAccountId > 0) {
      final validChart = await db
          .customSelect(
            '''
            SELECT 1
            FROM ChartOfAccounts
            WHERE ChartOfAccountID = ?1
              AND COALESCE(IsDeleted, 0) = 0
            LIMIT 1
            ''',
            variables: [Variable.withInt(chartOfAccountId)],
            readsFrom: {db.chartOfAccounts},
          )
          .get();
      if (validChart.isEmpty) {
        throw ArgumentError('Selected chart account is not valid.');
      }
    }
    final normalizedHead = normalizeHeadNameForAccount(
      accountName: name,
      requestedHeadName: statusg,
    );
    final actor = await _resolveCurrentActor();

    await db
        .into(db.accPersonal)
        .insert(
          AccPersonalCompanion(
            accId: Value(nextAccId),
            accountGuid: Value(Ulid.generate()),
            rDate: Value(nowIso),
            name: Value(normalizedName),
            phone: Value(phone?.trim().isEmpty == true ? null : phone?.trim()),
            address: Value(
              address?.trim().isEmpty == true ? null : address?.trim(),
            ),
            statusg: Value(normalizedHead),
            chartOfAccountId: Value(chartOfAccountId),
            companyId: Value(companyId),
            isSynced: const Value(0),
            updatedAt: Value(nowIso),
            isDeleted: const Value(0),
          ),
        );

    await _appendAuditTrail(
      companyId: companyId,
      entityType: 'account_personal',
      action: 'create',
      entityId: nextAccId.toString(),
      actor: actor,
      message: 'Account created',
      payload: {
        'accId': nextAccId,
        'name': normalizedName,
        'chartOfAccountId': chartOfAccountId,
      },
    );

    return nextAccId;
  }

  Future<void> updateAccountBasic({
    required int accId,
    required String name,
    String? phone,
    String? address,
    String? statusg,
    int? chartOfAccountId,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final companyRows = await db
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
    final companyId = companyRows.isEmpty
        ? 0
        : _toInt(companyRows.first.data['CompanyID']);
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError('Account name cannot be empty.');
    }
    if (companyId > 0) {
      await _assertUniqueAccountNameForCompany(
        companyId: companyId,
        accountName: normalizedName,
        excludingAccId: accId,
      );
    }
    if (chartOfAccountId != null && chartOfAccountId > 0) {
      final validChart = await db
          .customSelect(
            '''
            SELECT 1
            FROM ChartOfAccounts
            WHERE ChartOfAccountID = ?1
              AND COALESCE(IsDeleted, 0) = 0
            LIMIT 1
            ''',
            variables: [Variable.withInt(chartOfAccountId)],
            readsFrom: {db.chartOfAccounts},
          )
          .get();
      if (validChart.isEmpty) {
        throw ArgumentError('Selected chart account is not valid.');
      }
    }
    final normalizedHead = normalizeHeadNameForAccount(
      accountName: name,
      requestedHeadName: statusg,
    );
    final actor = await _resolveCurrentActor();

    await (db.update(
      db.accPersonal,
    )..where((tbl) => tbl.accId.equals(accId))).write(
      AccPersonalCompanion(
        name: Value(normalizedName),
        phone: Value(phone?.trim().isEmpty == true ? null : phone?.trim()),
        address: Value(
          address?.trim().isEmpty == true ? null : address?.trim(),
        ),
        statusg: Value(normalizedHead),
        chartOfAccountId: Value(chartOfAccountId),
        isSynced: const Value(0),
        updatedAt: Value(nowIso),
      ),
    );

    await _appendAuditTrail(
      companyId: companyId > 0 ? companyId : null,
      entityType: 'account_personal',
      action: 'update',
      entityId: accId.toString(),
      actor: actor,
      message: 'Account updated',
      payload: {
        'accId': accId,
        'name': normalizedName,
        'chartOfAccountId': chartOfAccountId,
      },
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
                  AccountTypeID = ?4,
                  AssignmentGuid = COALESCE(NULLIF(TRIM(AssignmentGuid), ''), ?5)
              WHERE RegID = ?6
              ''',
              [
                nowIso,
                resolvedCompanyId,
                accId,
                accTypeId,
                Ulid.generate(),
                regId,
              ],
            );
            continue;
          }
        }

        final regId = await getNextCurrencyAssignmentRegId();
        await db.customStatement(
          '''
          INSERT INTO Account_PCurrencyAssignment
            (RegID, AssignmentGuid, AccID, AccountTypeID, CompanyID, IsDeleted, IsSynced, UpdatedAt)
          VALUES (?1, ?2, ?3, ?4, ?5, 0, 0, ?6)
          ''',
          [regId, Ulid.generate(), accId, accTypeId, resolvedCompanyId, nowIso],
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

  Future<int> _postReversalEntriesForRows({
    required int companyId,
    required List<TransactionsPData> rows,
    required _ActorMeta actor,
    required String reason,
  }) async {
    if (rows.isEmpty) return 0;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final openDate = await _nextOpenDate(companyId: companyId);
    final openDateText = _toDateOnly(openDate);

    final sortedRows = [...rows]..sort((a, b) => a.voucherNo - b.voucherNo);
    final pairLink = (sortedRows.first.others ?? '').trim();
    final isPair =
        pairLink.startsWith(_cashPairLinkPrefix) && sortedRows.length == 2;
    final mainOriginal = _mainVoucherFromPairLink(pairLink);

    var inserted = 0;
    await db.transaction(() async {
      int? newMainVoucher;
      int? newReverseVoucher;
      String? newPairLink;
      if (isPair) {
        newMainVoucher = await _reserveUniqueVoucherNo(userId: actor.userId);
        newReverseVoucher = await _reserveUniqueVoucherNo(
          minValue: newMainVoucher,
          userId: actor.userId,
        );
        newPairLink = '$_cashPairLinkPrefix$newMainVoucher:$newReverseVoucher';
      }

      for (final row in sortedRows) {
        final isMain =
            !isPair || (mainOriginal != null && row.voucherNo == mainOriginal);
        final targetVoucher = isPair
            ? (isMain ? newMainVoucher! : newReverseVoucher!)
            : await _reserveUniqueVoucherNo(userId: actor.userId);
        final reverseIsCredit = (row.dr ?? 0) > 0;
        final sourceRef = (mainOriginal ?? sortedRows.first.voucherNo)
            .toString();

        inserted += await db
            .into(db.transactionsP)
            .insert(
              TransactionsPCompanion(
                voucherNo: Value(targetVoucher),
                txGuid: Value(_generateTxGuid()),
                tDate: Value(openDateText),
                accId: Value(row.accId),
                accTypeId: Value(row.accTypeId),
                description: Value('REVERSAL of V${row.voucherNo}: $reason'),
                quality: Value(row.quality),
                rate: Value(row.rate),
                weight: Value(row.weight == null ? null : -row.weight!),
                dr: Value(row.cr ?? 0.0),
                cr: Value(row.dr ?? 0.0),
                status: Value(reverseIsCredit ? 'jama' : 'banam'),
                st: Value(reverseIsCredit ? 'jamakatha' : 'banamkatha'),
                currencyStatus: const Value('csave'),
                cashStatus: Value(row.cashStatus),
                companyId: Value(companyId),
                userId: Value(actor.userId),
                wName: Value(actor.userEmail),
                msgNo: Value('REV-$sourceRef'),
                msgNo2: Value('REV-$sourceRef'),
                hwls: Value(sourceRef),
                others: Value(newPairLink),
                isSynced: const Value(0),
                updatedAt: Value(nowIso),
                isDeleted: const Value(0),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    });

    await _appendAuditTrail(
      companyId: companyId,
      entityType: 'transaction',
      action: 'reversal_posted',
      entityId: rows.first.voucherNo.toString(),
      actor: actor,
      message: 'Reversal posted for locked-period transaction',
      payload: {
        'sourceVouchers': rows.map((e) => e.voucherNo).toList(growable: false),
        'reason': reason,
        'reversalDate': openDateText,
      },
    );
    return inserted;
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
    final txDateIso = _toDateOnly(txDate);
    final lock = await _findActivePeriodLockForDate(
      companyId: companyId,
      dateText: txDateIso,
    );
    if (lock != null) {
      if (_canBypassPeriodLock(actor: actor, lock: lock)) {
        await _appendAuditTrail(
          companyId: companyId,
          entityType: 'period_lock',
          action: 'override_insert',
          entityId: lock.periodLockId.toString(),
          actor: actor,
          message: 'SOFT lock overridden by admin/owner for insert',
          payload: {
            'lockMode': lock.lockMode,
            'lockedStart': lock.startDate,
            'lockedEnd': lock.endDate,
            'txDate': txDateIso,
          },
        );
      } else {
        throw Exception(
          'Date $txDateIso is locked (${lock.startDate} to ${lock.endDate}). Post in an open period.',
        );
      }
    }
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

    await _appendAuditTrail(
      companyId: companyId,
      entityType: 'transaction',
      action: 'create',
      entityId: mainVoucher.toString(),
      actor: actor,
      message: 'Transaction created',
      payload: {
        'voucherNo': mainVoucher,
        'isCash': isCash,
        'accId': accId,
        'accTypeId': accTypeId,
        'debit': debit,
        'credit': credit,
        'date': txDateIso,
      },
    );
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

    final sourceDate = _normalizeDateText(mainExisting.tDate ?? '');
    final sourceLock = await _findActivePeriodLockForDate(
      companyId: companyId,
      dateText: sourceDate,
    );
    if (sourceLock != null) {
      if (_canBypassPeriodLock(actor: actor, lock: sourceLock)) {
        await _appendAuditTrail(
          companyId: companyId,
          entityType: 'period_lock',
          action: 'override_update_source',
          entityId: sourceLock.periodLockId.toString(),
          actor: actor,
          message: 'SOFT lock overridden by admin/owner for update source date',
          payload: {
            'lockMode': sourceLock.lockMode,
            'lockedStart': sourceLock.startDate,
            'lockedEnd': sourceLock.endDate,
            'sourceDate': sourceDate,
            'voucherNo': mainVoucher,
          },
        );
      } else {
        final reversalCount = await _postReversalEntriesForRows(
          companyId: companyId,
          rows: existingRows,
          actor: actor,
          reason: 'Locked period update',
        );
        final openDate = await _nextOpenDate(
          companyId: companyId,
          preferred: txDate,
        );
        await insertTransactionEntry(
          companyId: companyId,
          accId: accId,
          accTypeId: accTypeId,
          txDate: openDate,
          description: cleanDescription,
          entryReference: cleanReference,
          debit: debit,
          credit: credit,
          isCash: isCash,
          cashAccId: cashAccId,
          quality: cleanQuality,
          rate: rate,
          weight: weight,
        );
        final openDateText = _toDateOnly(openDate);
        _lastComplianceNotice =
            'Locked period detected (${sourceLock.startDate} to ${sourceLock.endDate}). '
            'Posted reversal and replacement in open date $openDateText.';
        await _appendAuditTrail(
          companyId: companyId,
          entityType: 'transaction',
          action: 'update_reversed',
          entityId: mainVoucher.toString(),
          actor: actor,
          message: 'Locked-period update converted into reversal + replacement',
          payload: {
            'sourceVoucher': mainVoucher,
            'sourceDate': sourceDate,
            'replacementDate': openDateText,
            'reversalEntries': reversalCount,
          },
        );
        return reversalCount + 1;
      }
    }

    final targetDateText = _toDateOnly(txDate);
    final targetLock = await _findActivePeriodLockForDate(
      companyId: companyId,
      dateText: targetDateText,
    );
    if (targetLock != null) {
      if (_canBypassPeriodLock(actor: actor, lock: targetLock)) {
        await _appendAuditTrail(
          companyId: companyId,
          entityType: 'period_lock',
          action: 'override_update_target',
          entityId: targetLock.periodLockId.toString(),
          actor: actor,
          message: 'SOFT lock overridden by admin/owner for update target date',
          payload: {
            'lockMode': targetLock.lockMode,
            'lockedStart': targetLock.startDate,
            'lockedEnd': targetLock.endDate,
            'targetDate': targetDateText,
            'voucherNo': mainVoucher,
          },
        );
      } else {
        throw Exception(
          'Cannot move voucher to locked date $targetDateText '
          '(${targetLock.startDate} to ${targetLock.endDate}).',
        );
      }
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

    await _appendAuditTrail(
      companyId: companyId,
      entityType: 'transaction',
      action: 'update',
      entityId: mainVoucher.toString(),
      actor: actor,
      message: 'Transaction updated',
      payload: {
        'voucherNo': mainVoucher,
        'isCash': isCash,
        'accId': accId,
        'accTypeId': accTypeId,
        'debit': debit,
        'credit': credit,
        'date': targetDateText,
      },
    );

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

    _PeriodLockMatch? sourceLock;
    var lockedDate = '';
    for (final row in rows) {
      final rowDate = _normalizeDateText(row.tDate ?? '');
      final lock = await _findActivePeriodLockForDate(
        companyId: companyId,
        dateText: rowDate,
      );
      if (lock != null) {
        sourceLock = lock;
        lockedDate = rowDate;
        break;
      }
    }
    if (sourceLock != null) {
      if (_canBypassPeriodLock(actor: actor, lock: sourceLock)) {
        await _appendAuditTrail(
          companyId: companyId,
          entityType: 'period_lock',
          action: 'override_delete',
          entityId: sourceLock.periodLockId.toString(),
          actor: actor,
          message: 'SOFT lock overridden by admin/owner for delete',
          payload: {
            'lockMode': sourceLock.lockMode,
            'lockedStart': sourceLock.startDate,
            'lockedEnd': sourceLock.endDate,
            'sourceDate': lockedDate,
            'voucherNo': voucherNo,
          },
        );
      } else {
        final reversalCount = await _postReversalEntriesForRows(
          companyId: companyId,
          rows: rows,
          actor: actor,
          reason: 'Locked period delete',
        );
        _lastComplianceNotice =
            'Voucher is in a locked period (${sourceLock.startDate} to ${sourceLock.endDate}). '
            'Posted reversal entry instead of deleting.';
        await _appendAuditTrail(
          companyId: companyId,
          entityType: 'transaction',
          action: 'delete_reversed',
          entityId: voucherNo.toString(),
          actor: actor,
          message: 'Locked-period delete converted into reversal',
          payload: {
            'voucherNo': voucherNo,
            'sourceDate': lockedDate,
            'reversalEntries': reversalCount,
          },
        );
        return reversalCount;
      }
    }

    final voucherNos = rows.map((row) => row.voucherNo).toSet().toList();
    final affected =
        await (db.update(db.transactionsP)..where(
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
    await _appendAuditTrail(
      companyId: companyId,
      entityType: 'transaction',
      action: 'delete',
      entityId: voucherNo.toString(),
      actor: actor,
      message: 'Transaction moved to trash',
      payload: {'voucherNo': voucherNo, 'affectedRows': affected},
    );
    return affected;
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
    final affected =
        await (db.update(db.transactionsP)..where(
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
    await _appendAuditTrail(
      companyId: companyId,
      entityType: 'transaction',
      action: 'restore',
      entityId: voucherNo.toString(),
      message: 'Transaction restored from trash',
      payload: {'voucherNo': voucherNo, 'affectedRows': affected},
    );
    return affected;
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

    final query =
        """
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
