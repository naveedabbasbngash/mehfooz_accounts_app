// lib/viewmodel/sync/sync_viewmodel.dart
import 'dart:async';
import 'package:drift/drift.dart' show Variable;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:async/async.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repository/sync/sync_repository.dart';
import '../../services/sync/sync_service.dart';
import '../../data/local/app_database.dart';
import '../../model/SyncResult.dart';
import '../../services/auth_service.dart';
import '../../services/local_storage.dart';
import '../../services/global_state.dart';
import '../../services/device_identity_service.dart';
import '../../services/sync/sync_invalidation_store.dart';
import '../../utils/ulid.dart';

enum AutoSyncInterval { off, sec30, min2, min5, min20 }

class SyncLogEntry {
  final DateTime timestamp;
  final bool success;
  final String message;

  SyncLogEntry({
    required this.timestamp,
    required this.success,
    required this.message,
  });
}

class _PushSummary {
  final int pushed;
  final int failed;

  const _PushSummary({required this.pushed, required this.failed});

  bool get hasAny => pushed > 0 || failed > 0;
}

class _SyncWritePermissionDenied implements Exception {
  final String message;
  const _SyncWritePermissionDenied([
    this.message = 'Missing permission: sync.write',
  ]);

  @override
  String toString() => message;
}

class SyncViewModel extends ChangeNotifier {
  final SyncService syncService;
  final Logger _log = Logger();
  static bool _globalSyncInProgress = false;

  SyncViewModel({required this.syncService});

  // 🔔 Callback for Home/Profile refresh
  VoidCallback? onActivationChanged;

  // ─────────────────────────────────────────────
  // CORE STATE
  // ─────────────────────────────────────────────
  SyncRepository? syncRepo;
  String? _userEmail;
  String? _deviceId;
  String? _referenceId;
  String? _lastRemoteCursor;
  bool isVerifyingReferenceId = false;
  String? referenceIdError;

  bool isSyncing = false;
  bool isBackgroundSync = false;
  double syncProgress = 0.0;
  String lastMessage = '';
  DateTime? lastSyncedTime;
  bool isPendingBatchesLoading = false;
  String? pendingBatchesError;
  List<PendingBatchItem> pendingBatches = const [];

  // 🔴 NEW: last sync result
  SyncResult? lastSyncResult;

  CancelableOperation<void>? _activeSync;
  Timer? _autoSyncTimer;
  bool _isFinalizingAck = false;
  StreamSubscription<dynamic>? _connectivitySub;
  Timer? _fastSyncDebounce;
  bool _syncLaunchLock = false;
  bool _forceMasterSnapshotNextRun = false;
  StreamSubscription<String>? _fcmTokenRefreshSub;
  StreamSubscription<RemoteMessage>? _fcmMessageSub;
  StreamSubscription<RemoteMessage>? _fcmOpenAppMessageSub;
  bool _fcmBridgeInitialized = false;
  bool _processingPendingInvalidation = false;

  // ✅ NEW: failsafe unlock timer (prevents stuck state forever)
  Timer? _failsafeTimer;
  bool _skipPushDueToMissingSyncWrite = false;

  // ─────────────────────────────────────────────
  // 🔐 PERMISSIONS
  // ─────────────────────────────────────────────
  bool _adminCanSync = false;
  bool _hasLocalImport = false;

  // ─────────────────────────────────────────────
  // PREF KEYS
  // ─────────────────────────────────────────────
  static const _kLocalImportPrefix = "has_local_import_";
  static const _kAutoSyncKeyPrefix = "auto_sync_interval_";
  static const _kReferenceIdPrefix = "reference_uuid_";
  static const _kRemoteCursorPrefix = "remote_sync_cursor_";
  static const _kPushTokenPrefix = "push_token_registered_";

  // ─────────────────────────────────────────────
  // AUTO SYNC
  // ─────────────────────────────────────────────
  AutoSyncInterval autoSyncInterval = AutoSyncInterval.min2;
  static const int _pushMaxRetries = 3;
  static const int _pullMaxRetries = 3;
  static const int _ackMaxRetries = 3;
  static const Duration _minSmartSyncGap = Duration(seconds: 20);

  // ✅ NEW: extra safety (timeout can throw, but this prevents UI stuck)
  static const Duration _failsafeUnlock = Duration(seconds: 45);

  // ─────────────────────────────────────────────
  // CONFIGURE USER
  // ─────────────────────────────────────────────
  Future<void> configureForUser({
    required String email,
    required bool adminCanSync,
  }) async {
    _userEmail = email.trim().toLowerCase();
    _adminCanSync = adminCanSync;
    _skipPushDueToMissingSyncWrite = false;

    final prefs = await SharedPreferences.getInstance();
    _hasLocalImport = prefs.getBool("$_kLocalImportPrefix$_userEmail") ?? false;
    _referenceId = prefs.getString("$_kReferenceIdPrefix$_userEmail")?.trim();
    _lastRemoteCursor = prefs
        .getString("$_kRemoteCursorPrefix$_userEmail")
        ?.trim();
    if (_lastRemoteCursor != null && _lastRemoteCursor!.isEmpty) {
      _lastRemoteCursor = null;
    }
    if (_referenceId != null && _referenceId!.isNotEmpty) {
      _deviceId = _referenceId;
    } else {
      _referenceId = null;
      _deviceId = null;
    }

    _log.i("🔐 Admin sync permission = $_adminCanSync");
    _log.i("📱 Sync reference_id=${_referenceId ?? '(missing)'}");

    await _loadAutoSyncSetting();
    _startConnectivityWatch();
    _restartAutoSync();
    unawaited(_initializeFcmRealtimeSync());
    if (hasReferenceId) {
      await refreshPendingBatches(silent: true);
    } else {
      pendingBatches = const [];
      pendingBatchesError = null;
    }
    unawaited(triggerSmartSync());
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // DB ATTACH
  // ─────────────────────────────────────────────
  void attachDatabase(AppDatabase db) {
    syncRepo = SyncRepository(db);
    _log.i("🔗 SyncRepository attached/replaced");
    _restartAutoSync();
    unawaited(_registerCurrentFcmToken(force: true));
    unawaited(_drainPendingInvalidation(reason: 'db-attached'));
    notifyListeners();
  }

  bool get isReady => syncRepo != null;
  int get pendingBatchCount => pendingBatches.length;
  String? get referenceId => _referenceId;
  bool get hasReferenceId =>
      _referenceId != null && _referenceId!.trim().isNotEmpty;

  // ─────────────────────────────────────────────
  // SYNC GATE
  // ─────────────────────────────────────────────
  bool get canSync {
    if (!_adminCanSync) return false;
    if (!_hasLocalImport) return false;
    if (!isReady) return false;
    return true;
  }

  /// True when sync is running in pull-only mode because sync.write is missing.
  bool get isPushPermissionMissing =>
      _skipPushDueToMissingSyncWrite || _isMissingSyncWriteError(lastMessage);

  String get syncBlockReason {
    if (!_adminCanSync) return "🔒 Sync disabled by admin";
    if (!_hasLocalImport) return "🟠 Import local database to enable sync";
    if (!isReady) return "⚠ Database not ready";
    return "";
  }

  Future<bool> verifyAndSaveReferenceId(String rawUuid) async {
    if (_userEmail == null) {
      referenceIdError = "User not ready";
      notifyListeners();
      return false;
    }

    final uuid = rawUuid.trim();
    if (uuid.isEmpty) {
      referenceIdError = "Please enter Reference ID";
      notifyListeners();
      return false;
    }

    isVerifyingReferenceId = true;
    referenceIdError = null;
    notifyListeners();

    try {
      final result = await syncService.verifyDeviceUuid(
        email: _userEmail!,
        uuid: uuid,
      );

      if (!result.isVerified) {
        referenceIdError = result.message.trim().isEmpty
            ? "Reference ID not verified"
            : result.message;
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("$_kReferenceIdPrefix$_userEmail", uuid);

      _referenceId = uuid;
      _deviceId = uuid;
      referenceIdError = null;

      _restartAutoSync();
      await refreshPendingBatches(silent: true);
      notifyListeners();
      return true;
    } catch (e) {
      referenceIdError = "Verification failed: $e";
      notifyListeners();
      return false;
    } finally {
      isVerifyingReferenceId = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // AUTO SYNC
  // ─────────────────────────────────────────────
  Duration? get autoSyncDuration {
    switch (autoSyncInterval) {
      case AutoSyncInterval.sec30:
        return const Duration(seconds: 30);
      case AutoSyncInterval.min2:
        return const Duration(minutes: 2);
      case AutoSyncInterval.min5:
        return const Duration(minutes: 5);
      case AutoSyncInterval.min20:
        return const Duration(minutes: 20);
      case AutoSyncInterval.off:
        return null;
    }
  }

  Future<void> _loadAutoSyncSetting() async {
    if (_userEmail == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt("$_kAutoSyncKeyPrefix$_userEmail");
    if (raw != null) {
      autoSyncInterval = AutoSyncInterval.values[raw];
      return;
    }

    // Default to background auto-sync for reliable cross-device updates.
    autoSyncInterval = AutoSyncInterval.min2;
    await prefs.setInt(
      "$_kAutoSyncKeyPrefix$_userEmail",
      autoSyncInterval.index,
    );
  }

  void _restartAutoSync() {
    _autoSyncTimer?.cancel();
    final d = autoSyncDuration;
    if (d == null || !canSync) {
      if (d == null) {
        _log.w("⛔ Auto-sync blocked → Auto-sync interval is Off");
      } else {
        _log.w("⛔ Auto-sync blocked → $syncBlockReason");
      }
      return;
    }
    _autoSyncTimer = Timer.periodic(d, (_) {
      if (!isSyncing) {
        unawaited(triggerSmartSync(immediate: true));
      }
    });
  }

  // ─────────────────────────────────────────────
  // MANUAL SYNC  ✅ FIXED (NO MORE STUCK)
  // ─────────────────────────────────────────────
  Future<void> syncNow({bool silent = false}) async {
    if (!canSync) {
      _log.w("⛔ Sync blocked → $syncBlockReason");
      _setState(syncing: false, progress: 0, message: syncBlockReason);
      return;
    }

    if (isSyncing ||
        _isFinalizingAck ||
        _syncLaunchLock ||
        _globalSyncInProgress) {
      if (!silent) {
        _setState(syncing: isSyncing, message: "Finishing previous sync…");
      }
      return;
    }
    // Acquire launch guards before async checks to avoid race-starting
    // two sync runs in parallel from closely-timed triggers.
    _syncLaunchLock = true;
    _globalSyncInProgress = true;

    // ✅ IMPORTANT: Don’t silently return on user tap
    final hasNet = await _hasNetwork();
    if (!hasNet) {
      if (!silent) {
        _setState(
          syncing: false,
          progress: 0,
          message: "❌ No internet connection",
        );
      } else {
        _setState(syncing: false, progress: 0);
      }
      _syncLaunchLock = false;
      _globalSyncInProgress = false;
      return;
    }

    isBackgroundSync = silent;

    // ✅ Start syncing state immediately (button disables correctly)
    _setState(
      syncing: true,
      progress: 0.05,
      message: silent ? null : "Starting sync…",
    );

    // ✅ Failsafe unlock if something hangs (prevents "stuck forever")
    _startFailsafeUnlock();

    _activeSync = CancelableOperation.fromFuture(
      _runWithRetry(_userEmail!, await _ensureDeviceId(), silent: silent),
    );

    try {
      await _activeSync!.value;

      // Success state is already handled inside _runWithRetry.
    } catch (e, st) {
      // ✅ THIS is where your old code broke: exception skipped reset.
      _log.e("❌ Sync failed", error: e, stackTrace: st);

      // Ensure state resets + UI shows error (unless silent background)
      _setState(syncing: false, progress: 0, message: "❌ Sync failed");
    } finally {
      // ✅ Always cleanup
      _stopFailsafeUnlock();
      isBackgroundSync = false;
      _syncLaunchLock = false;
      _globalSyncInProgress = false;

      // If somehow still marked syncing, force release.
      if (isSyncing) {
        _setState(syncing: false, progress: 0, message: null);
      }
    }
  }

  /// Starts sync if idle, otherwise waits for the in-flight sync to complete.
  /// Useful for pull-to-refresh so one gesture maps to one sync cycle.
  Future<void> syncNowSingleFlight({bool silent = false}) async {
    if (isSyncing ||
        _isFinalizingAck ||
        _syncLaunchLock ||
        _globalSyncInProgress) {
      final active = _activeSync;
      if (active != null) {
        await active.valueOrCancellation();
      }
      return;
    }
    await syncNow(silent: silent);
  }

  // ─────────────────────────────────────────────
  // SYNC FLOW
  // ─────────────────────────────────────────────
  Future<String> _ensureDeviceId() async {
    if (_deviceId != null && _deviceId!.trim().isNotEmpty) {
      return _deviceId!;
    }
    final fallback = await DeviceIdentityService.getDeviceId();
    _deviceId = fallback.trim();
    return _deviceId!;
  }

  Future<int?> _activeCompanyIdForSync() async {
    final currentCompanyId = GlobalState.instance.selectedCompanyId;
    if (currentCompanyId != null && currentCompanyId > 0) {
      return currentCompanyId;
    }

    final repo = syncRepo;
    if (repo == null) return null;

    final fallbackCompanyId = await repo.resolveDefaultCompanyId();
    return fallbackCompanyId > 0 ? fallbackCompanyId : null;
  }

  Future<String?> _activeCompanyGuidForSync(int? companyId) async {
    final repo = syncRepo;
    if (repo == null || (companyId ?? 0) <= 0) return null;
    final guid = await repo.resolveCompanyGuidForId(companyId!);
    return guid.trim().isEmpty ? null : guid.trim();
  }

  Future<void> _logLocalSyncSnapshot(
    String stage, {
    int? activeCompanyId,
  }) async {
    final repo = syncRepo;
    if (repo == null) return;

    try {
      final companies = await repo.db
          .customSelect(
            '''
        SELECT CompanyID, CompanyName
        FROM Company
        ORDER BY CompanyID ASC
        ''',
            readsFrom: {repo.db.companyTable},
          )
          .get();

      final companyRows = companies
          .map(
            (row) =>
                '${row.data['CompanyID']}:${row.data['CompanyName'] ?? '(null)'}',
          )
          .join(', ');

      int accountCount = 0;
      if ((activeCompanyId ?? 0) > 0) {
        final accountRow = await repo.db
            .customSelect(
              '''
          SELECT COUNT(*) AS c
          FROM Acc_Personal
          WHERE CompanyID = ?1
            AND COALESCE(IsDeleted, 0) = 0
          ''',
              variables: [Variable.withInt(activeCompanyId!)],
              readsFrom: {repo.db.accPersonal},
            )
            .getSingle();
        accountCount = int.tryParse('${accountRow.data['c'] ?? 0}') ?? 0;
      }

      _log.i(
        "🏢 [SYNC_DEBUG] $stage activeCompany=${activeCompanyId ?? '(null)'} "
        "companies=[${companyRows.isEmpty ? '(empty)' : companyRows}] "
        "accountCountForActive=$accountCount",
      );
    } catch (e) {
      _log.w("⚠️ [SYNC_DEBUG] failed to log $stage snapshot: $e");
    }
  }

  Future<void> _runWithRetry(
    String email,
    String deviceId, {
    required bool silent,
  }) async {
    final activeCompanyId = await _activeCompanyIdForSync();
    await _logLocalSyncSnapshot(
      'before-sync',
      activeCompanyId: activeCompanyId,
    );
    _setState(syncing: true, progress: 0.1, message: "Starting sync…");

    var readOnlySync = _skipPushDueToMissingSyncWrite;
    _setState(
      syncing: true,
      progress: 0.22,
      message: readOnlySync
          ? "Pull-only mode (no sync.write)…"
          : "Uploading local changes…",
    );
    var pushSummary = const _PushSummary(pushed: 0, failed: 0);
    if (!readOnlySync) {
      try {
        pushSummary = await _pushLocalPendingChanges(
          deviceId: deviceId,
          forceMasterSnapshot: _consumeForceMasterSnapshotFlag(),
        );
        _skipPushDueToMissingSyncWrite = false;
      } on _SyncWritePermissionDenied catch (e) {
        readOnlySync = true;
        _skipPushDueToMissingSyncWrite = true;
        _log.w("⚠️ sync.write missing → pull-only sync mode (${e.toString()})");
        _setState(
          syncing: true,
          progress: 0.24,
          message: "Pull-only mode (no sync.write)…",
        );
      }
    } else {
      _log.w("⚠️ sync.write still missing → skipping push, pull-only mode");
    }

    final activeCompanyGuid = await _activeCompanyGuidForSync(activeCompanyId);
    final pullSw = Stopwatch()..start();
    SyncBatch? batch;
    Object? pullError;
    for (int i = 0; i < _pullMaxRetries; i++) {
      try {
        batch = await syncService.pullForMobile(
          email: email,
          deviceId: deviceId,
          companyId: activeCompanyId,
          companyGuid: activeCompanyGuid,
        );
        pullError = null;
        break;
      } catch (e) {
        pullError = e;
        if (i == _pullMaxRetries - 1) break;
        _log.w("⚠️ pull failed (attempt ${i + 1}/$_pullMaxRetries): $e");
        await Future.delayed(Duration(seconds: 2 << i));
      }
    }
    pullSw.stop();
    _log.i("⏱ [Sync] pull ms=${pullSw.elapsedMilliseconds}");

    if (batch == null && pullError != null) {
      if (pushSummary.hasAny) {
        lastSyncedTime = DateTime.now();
        final msg = pushSummary.failed > 0
            ? "⚠ Uploaded ${pushSummary.pushed}, ${pushSummary.failed} still pending"
            : "✔ Uploaded ${pushSummary.pushed} local changes";
        _setState(syncing: false, progress: 1, message: msg);
        await refreshPendingBatches(silent: true);
        return;
      }
      throw pullError;
    }

    if (batch == null) {
      await _logLocalSyncSnapshot(
        'after-sync-empty',
        activeCompanyId: activeCompanyId,
      );
      lastSyncedTime = DateTime.now();
      lastSyncResult = null;
      final msg = pushSummary.pushed > 0
          ? "✔ Uploaded ${pushSummary.pushed} local changes"
          : (readOnlySync ? "✔ Pull-only sync complete" : "Nothing to update");
      _setState(syncing: false, progress: 1, message: msg);
      await refreshPendingBatches(silent: true);
      return;
    }

    _setState(syncing: true, progress: 0.6, message: "Applying updates…");

    final applySw = Stopwatch()..start();
    final result = await syncRepo!.applyBatch(batch);
    applySw.stop();
    _log.i(
      "⏱ [Sync] apply ms=${applySw.elapsedMilliseconds} batch=${batch.batchId}",
    );

    lastSyncResult = result;
    lastSyncedTime = DateTime.now();
    await _persistRemoteCursor(batch.batchId);
    await _logLocalSyncSnapshot(
      'after-apply',
      activeCompanyId: activeCompanyId,
    );
    final finalMessage = pushSummary.failed > 0
        ? "⚠ Sync complete, ${pushSummary.failed} upload(s) need retry"
        : "✔ Sync complete";
    _setState(syncing: false, progress: 1, message: finalMessage);

    // 🔔 notify Home/Profile right after local apply to keep UI responsive.
    onActivationChanged?.call();

    // ACK in background so slow internet doesn't keep sync spinner active.
    unawaited(
      _finalizeAck(
        email: email,
        deviceId: deviceId,
        batchId: batch.batchId,
        silent: silent,
      ),
    );
  }

  Future<_PushSummary> _pushLocalPendingChanges({
    required String deviceId,
    required bool forceMasterSnapshot,
  }) async {
    if (syncRepo == null) return const _PushSummary(pushed: 0, failed: 0);

    final token = await LocalStorageService.loadAuthTokenForLastUsedUser();
    if (token == null || token.trim().isEmpty) {
      throw Exception("Session token missing. Please sign in again.");
    }

    final tenantId = await AuthService.resolveTenantIdForCurrentSession();
    if (tenantId == null || tenantId <= 0) {
      throw Exception("Tenant id missing. Please sign in again.");
    }

    final repo = syncRepo!;
    final defaultCompanyId = await repo.resolveDefaultCompanyId();
    final unsyncedCompanies = await repo.collectUnsyncedCompanyChanges(
      limit: 200,
    );

    final unsyncedCurrencies = await repo.collectUnsyncedAccTypeChanges(
      fallbackCompanyId: defaultCompanyId,
      limit: 600,
    );
    final unsyncedAccounts = await repo.collectUnsyncedAccPersonalChanges(
      limit: 900,
    );
    final pendingHeads = await repo.collectHeadSnapshotChanges(
      companyId: defaultCompanyId,
      limit: 500,
      unsyncedOnly: !forceMasterSnapshot,
    );
    final pendingTransactions = await repo.collectUnsyncedTransactionChanges(
      limit: 1400,
    );
    final assignmentRows = await repo.collectUnsyncedAssignmentChanges();

    // Ensure transaction parent rows (account + currency) are always pushed
    // before Transactions_P, even if parent rows were locally marked synced.
    final txAccIds = <int>{};
    final txAccTypeIds = <int>{};
    for (final tx in pendingTransactions) {
      final data = tx.payload['data'];
      if (data is! Map) continue;
      final accId = _toIntSafe(data['AccID']);
      final accTypeId = _toIntSafe(data['AccTypeID']);
      if (accId > 0) txAccIds.add(accId);
      if (accTypeId > 0) txAccTypeIds.add(accTypeId);
    }

    final txAccountSnapshots = await repo.collectAccPersonalSnapshotByIds(
      accIds: txAccIds.toList(growable: false),
      limit: 900,
    );
    final txCurrencySnapshots = await repo.collectAccTypeSnapshotByIds(
      fallbackCompanyId: defaultCompanyId,
      accTypeIds: txAccTypeIds.toList(growable: false),
      limit: 600,
    );

    // Ensure assignment parent rows are also present on the server before
    // Account_PCurrencyAssignment is pushed, even if they were marked synced
    // locally during an earlier incomplete/partial sync.
    final assignmentAccIds = <int>{};
    final assignmentAccTypeIds = <int>{};
    for (final row in assignmentRows) {
      final data = row.payload['data'];
      if (data is! Map) continue;
      final accId = _toIntSafe(data['AccID']);
      final accTypeId = _toIntSafe(data['AccountTypeID']);
      if (accId > 0) assignmentAccIds.add(accId);
      if (accTypeId > 0) assignmentAccTypeIds.add(accTypeId);
    }

    final assignmentAccountSnapshots = await repo
        .collectAccPersonalSnapshotByIds(
          accIds: assignmentAccIds.toList(growable: false),
          limit: 900,
        );
    final assignmentCurrencySnapshots = await repo.collectAccTypeSnapshotByIds(
      fallbackCompanyId: defaultCompanyId,
      accTypeIds: assignmentAccTypeIds.toList(growable: false),
      limit: 600,
    );

    final pendingAccounts = _mergeUniqueMasterRows(
      _mergeUniqueMasterRows(unsyncedAccounts, txAccountSnapshots),
      assignmentAccountSnapshots,
    );
    final pendingCurrencies = _mergeUniqueMasterRows(
      _mergeUniqueMasterRows(unsyncedCurrencies, txCurrencySnapshots),
      assignmentCurrencySnapshots,
    );

    final companyIdsToEnsure = <int>{};
    for (final row in unsyncedCompanies) {
      if (row.companyId > 0) {
        companyIdsToEnsure.add(row.companyId);
      }
    }
    for (final row in pendingAccounts) {
      if (row.companyId > 0) {
        companyIdsToEnsure.add(row.companyId);
      }
    }
    for (final row in pendingTransactions) {
      if (row.companyId > 0) {
        companyIdsToEnsure.add(row.companyId);
      }
    }
    if (pendingCurrencies.isNotEmpty || pendingHeads.isNotEmpty) {
      companyIdsToEnsure.add(defaultCompanyId);
    }
    final snapshotCompanies =
        (forceMasterSnapshot || companyIdsToEnsure.isNotEmpty)
        ? await repo.collectCompanySnapshotChanges(
            companyIds: companyIdsToEnsure.toList(growable: false),
          )
        : const <PendingMasterChange>[];
    final pendingCompanies = _mergeUniqueMasterRows(
      unsyncedCompanies,
      snapshotCompanies,
    );

    final baseAssignments = <PendingMasterChange>[];
    final seenAssignments = <String>{};
    for (final row in assignmentRows) {
      final key = '${row.companyId}:${row.rowId}';
      if (!seenAssignments.add(key)) continue;
      baseAssignments.add(row);
    }

    if (pendingCompanies.isEmpty &&
        pendingCurrencies.isEmpty &&
        pendingHeads.isEmpty &&
        pendingAccounts.isEmpty &&
        baseAssignments.isEmpty &&
        pendingTransactions.isEmpty) {
      return const _PushSummary(pushed: 0, failed: 0);
    }

    var summary = const _PushSummary(pushed: 0, failed: 0);

    // Push company snapshots through a known existing company envelope first.
    // Why: server sync_batches has FK(sync_batches.CompanyID -> Company.CompanyID),
    // so pushing with a brand-new company id can fail before changes are applied.
    summary = _mergeSummary(
      summary,
      await _pushCompanySnapshots(
        token: token,
        tenantId: tenantId,
        deviceId: deviceId,
        rows: pendingCompanies,
        preferredEnvelopeCompanyId: defaultCompanyId,
      ),
    );

    summary = _mergeSummary(
      summary,
      await _pushChangesByCompany<PendingMasterChange>(
        token: token,
        tenantId: tenantId,
        deviceId: deviceId,
        label: 'currencies',
        rows: pendingCurrencies,
        companyIdOf: (r) => r.companyId,
        payloadOf: (r) => r.payload,
        onSuccess: (companyId, successRows) async {
          final ids = successRows.map((e) => e.rowId).toList(growable: false);
          await repo.markAccTypesSynced(ids);
        },
        failOnPartial: true,
      ),
    );

    summary = _mergeSummary(
      summary,
      await _pushChangesByCompany<PendingMasterChange>(
        token: token,
        tenantId: tenantId,
        deviceId: deviceId,
        label: 'heads',
        rows: pendingHeads,
        companyIdOf: (r) => r.companyId,
        payloadOf: (r) => r.payload,
        onSuccess: (_, successRows) async {
          await repo.markHeadSnapshotsSynced(successRows);
        },
        nonBlocking: true,
      ),
    );

    final failedAccountIdsByCompany = <int, Set<int>>{};
    summary = _mergeSummary(
      summary,
      await _pushChangesByCompany<PendingMasterChange>(
        token: token,
        tenantId: tenantId,
        deviceId: deviceId,
        label: 'accounts',
        rows: pendingAccounts,
        companyIdOf: (r) => r.companyId,
        payloadOf: (r) => r.payload,
        onSuccess: (companyId, successRows) async {
          final ids = successRows.map((e) => e.rowId).toList(growable: false);
          await repo.markAccPersonalSynced(companyId: companyId, accIds: ids);
        },
        onFailureRows: (companyId, failedRows) {
          final bucket = failedAccountIdsByCompany.putIfAbsent(
            companyId,
            () => <int>{},
          );
          for (final row in failedRows) {
            if (row.rowId > 0) bucket.add(row.rowId);
          }
        },
        // Keep account push best-effort so one bad account row does not block
        // assignment/transaction sync for the rest of the team.
        nonBlocking: true,
      ),
    );

    final pendingAssignments = <PendingMasterChange>[];
    var deferredAssignments = 0;
    for (final row in baseAssignments) {
      final data = row.payload['data'];
      final accId = data is Map ? _toIntSafe(data['AccID']) : 0;
      final failedForCompany = failedAccountIdsByCompany[row.companyId];
      if (accId > 0 &&
          failedForCompany != null &&
          failedForCompany.contains(accId)) {
        deferredAssignments++;
        continue;
      }
      pendingAssignments.add(row);
    }
    if (deferredAssignments > 0) {
      _log.w(
        "⚠️ Deferred assignment rows due to failed parent account push: $deferredAssignments",
      );
    }

    summary = _mergeSummary(
      summary,
      await _pushChangesByCompany<PendingMasterChange>(
        token: token,
        tenantId: tenantId,
        deviceId: deviceId,
        label: 'assignments',
        rows: pendingAssignments,
        companyIdOf: (r) => r.companyId,
        payloadOf: (r) => r.payload,
        onSuccess: (_, successRows) async {
          final ids = successRows.map((e) => e.rowId).toList(growable: false);
          await repo.markAssignmentsSynced(ids);
        },
        // Assignments are dependent rows; any failed rows stay unsynced and
        // will retry in the next cycle after parent accounts are accepted.
        nonBlocking: true,
        failOnPartial: true,
      ),
    );

    summary = _mergeSummary(
      summary,
      await _pushChangesByCompany<PendingSyncChange>(
        token: token,
        tenantId: tenantId,
        deviceId: deviceId,
        label: 'transactions',
        rows: pendingTransactions,
        companyIdOf: (r) => r.companyId,
        payloadOf: (r) => r.payload,
        onSuccess: (companyId, successRows) async {
          final ids = successRows.map((e) => e.txGuid).toList(growable: false);
          await repo.markTransactionsSynced(companyId: companyId, txGuids: ids);
        },
      ),
    );

    return summary;
  }

  _PushSummary _mergeSummary(_PushSummary a, _PushSummary b) {
    return _PushSummary(
      pushed: a.pushed + b.pushed,
      failed: a.failed + b.failed,
    );
  }

  List<PendingMasterChange> _mergeUniqueMasterRows(
    List<PendingMasterChange> primary,
    List<PendingMasterChange> secondary,
  ) {
    final merged = <PendingMasterChange>[];
    final seen = <String>{};

    void addAllRows(List<PendingMasterChange> rows) {
      for (final row in rows) {
        final table = (row.payload['table'] ?? '').toString();
        final key = '$table:${row.companyId}:${row.rowId}';
        if (seen.add(key)) {
          merged.add(row);
        }
      }
    }

    addAllRows(primary);
    addAllRows(secondary);
    return merged;
  }

  int _toIntSafe(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String? _companyGuidFromPayload(Map<String, dynamic> payload) {
    final data = payload['data'];
    final value = data is Map
        ? (data['CompanyGuid'] ?? data['company_guid'])
        : (payload['CompanyGuid'] ?? payload['company_guid']);
    final guid = value?.toString().trim() ?? '';
    return guid.isEmpty ? null : guid;
  }

  Future<_PushSummary> _pushCompanySnapshots({
    required String token,
    required int tenantId,
    required String deviceId,
    required List<PendingMasterChange> rows,
    required int preferredEnvelopeCompanyId,
  }) async {
    if (rows.isEmpty) return const _PushSummary(pushed: 0, failed: 0);

    final envelopeCandidates = <int>[];
    if (preferredEnvelopeCompanyId > 0) {
      envelopeCandidates.add(preferredEnvelopeCompanyId);
    }
    if (!envelopeCandidates.contains(1)) {
      envelopeCandidates.add(1);
    }

    var best = const _PushSummary(pushed: 0, failed: 0);

    for (final envelopeCompanyId in envelopeCandidates) {
      final result = await _pushChangesByCompany<PendingMasterChange>(
        token: token,
        tenantId: tenantId,
        deviceId: deviceId,
        label: 'companies',
        rows: rows,
        companyIdOf: (_) => envelopeCompanyId,
        payloadOf: (r) => r.payload,
        onSuccess: (_, successRows) async {
          await syncRepo?.markCompanySnapshotsSynced(successRows);
        },
        nonBlocking: true,
      );

      if (result.pushed > best.pushed ||
          (result.pushed == best.pushed && result.failed > best.failed)) {
        best = result;
      }

      if (result.failed == 0 && result.pushed >= rows.length) {
        return result;
      }

      _log.w(
        "⚠️ company bootstrap via envelope company=$envelopeCompanyId "
        "applied=${result.pushed} failed=${result.failed}",
      );
    }

    return best;
  }

  Future<_PushSummary> _pushChangesByCompany<T>({
    required String token,
    required int tenantId,
    required String deviceId,
    required String label,
    required List<T> rows,
    required int Function(T row) companyIdOf,
    required Map<String, dynamic> Function(T row) payloadOf,
    Future<void> Function(int companyId, List<T> successRows)? onSuccess,
    void Function(int companyId, List<T> failedRows)? onFailureRows,
    bool nonBlocking = false,
    bool failOnPartial = false,
  }) async {
    if (rows.isEmpty) return const _PushSummary(pushed: 0, failed: 0);

    var pushed = 0;
    var failed = 0;

    final byCompany = <int, List<T>>{};
    for (final row in rows) {
      final companyId = companyIdOf(row);
      if (companyId <= 0) continue;
      byCompany.putIfAbsent(companyId, () => <T>[]).add(row);
    }

    for (final entry in byCompany.entries) {
      final companyId = entry.key;
      final companyRows = entry.value;
      for (final chunk in _chunked(companyRows, 150)) {
        final chunkCompanyGuid = _companyGuidFromPayload(
          payloadOf(chunk.first),
        );
        SyncPushResponse? response;
        Object? chunkError;
        for (int attempt = 0; attempt < _pushMaxRetries; attempt++) {
          try {
            response = await syncService.pushChangesToMkb(
              bearerToken: token,
              tenantId: tenantId,
              companyId: companyId,
              deviceId: deviceId,
              changes: chunk.map(payloadOf).toList(growable: false),
              companyGuid: chunkCompanyGuid,
              requestId: 'push_${label}_${Ulid.generate()}_$companyId',
            );
            break;
          } catch (e) {
            if (_isMissingSyncWriteError(e)) {
              throw _SyncWritePermissionDenied(e.toString());
            }
            chunkError = e;
            if (attempt == _pushMaxRetries - 1) break;
            _log.w(
              "⚠️ push $label failed (attempt ${attempt + 1}/$_pushMaxRetries): $e",
            );
            await Future.delayed(Duration(seconds: 2 << attempt));
          }
        }

        final pushResp = response;
        if (pushResp == null) {
          if (chunkError != null && _isMissingSyncWriteError(chunkError)) {
            throw _SyncWritePermissionDenied(chunkError.toString());
          }
          if (nonBlocking) {
            _log.w(
              "⚠️ push $label skipped for company=$companyId after retries: ${chunkError ?? 'unknown error'}",
            );
            failed += chunk.length;
            continue;
          }
          throw Exception("Push response missing for $label.");
        }
        if (!pushResp.ok && pushResp.applied == 0) {
          if (_isMissingSyncWriteError(pushResp.message)) {
            throw _SyncWritePermissionDenied(pushResp.message);
          }
          throw Exception(pushResp.message);
        }

        final failedIndexes = pushResp.failedIndexes.toSet();
        final successRows = <T>[];
        final failedRows = <T>[];
        for (int i = 0; i < chunk.length; i++) {
          if (!failedIndexes.contains(i)) {
            successRows.add(chunk[i]);
          } else {
            failedRows.add(chunk[i]);
          }
        }

        if (successRows.isNotEmpty && onSuccess != null) {
          await onSuccess(companyId, successRows);
        }
        if (failedRows.isNotEmpty && onFailureRows != null) {
          onFailureRows(companyId, failedRows);
        }

        pushed += successRows.length;
        final failedForChunk = chunk.length - successRows.length;
        if (failedForChunk > 0) {
          failed += failedForChunk;
          if (!nonBlocking && failOnPartial) {
            final details = pushResp.failedErrors.isEmpty
                ? ''
                : ' errors=${pushResp.failedErrors.join(" | ")}';
            throw Exception(
              'Push $label partial failure for company=$companyId '
              '(failed=$failedForChunk of ${chunk.length}).$details',
            );
          }
        }
      }
    }

    return _PushSummary(pushed: pushed, failed: failed);
  }

  bool _isMissingSyncWriteError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('sync.write') ||
        text.contains('missing permission') ||
        text.contains('forbidden');
  }

  List<List<T>> _chunked<T>(List<T> source, int size) {
    if (source.isEmpty || size <= 0) return <List<T>>[];
    final chunks = <List<T>>[];
    for (int i = 0; i < source.length; i += size) {
      final end = (i + size < source.length) ? i + size : source.length;
      chunks.add(source.sublist(i, end));
    }
    return chunks;
  }

  Future<void> _finalizeAck({
    required String email,
    required String deviceId,
    required String batchId,
    required bool silent,
  }) async {
    _isFinalizingAck = true;
    final ackSw = Stopwatch()..start();
    bool acked = false;

    try {
      for (int i = 0; i < _ackMaxRetries; i++) {
        try {
          acked = await syncService.ackBatch(
            email: email,
            deviceId: deviceId,
            batchId: batchId,
            success: true,
          );
          if (acked) break;
        } catch (e) {
          if (i == _ackMaxRetries - 1) rethrow;
          _log.w("⚠️ ack failed (attempt ${i + 1}/$_ackMaxRetries): $e");
        }
        if (i < _ackMaxRetries - 1) {
          await Future.delayed(Duration(seconds: 1 << i));
        }
      }

      ackSw.stop();
      if (acked) {
        _log.i("⏱ [Sync] ack ms=${ackSw.elapsedMilliseconds} batch=$batchId");
      } else {
        _log.w("⚠️ [Sync] ack pending batch=$batchId");
        if (!silent && !isSyncing) {
          _setState(syncing: false, message: "⚠️ Synced locally, ack pending");
        }
      }
    } catch (e, st) {
      ackSw.stop();
      _log.e("❌ [Sync] ack failed batch=$batchId", error: e, stackTrace: st);
      if (!silent && !isSyncing) {
        _setState(syncing: false, message: "⚠️ Synced locally, ack pending");
      }
    } finally {
      _isFinalizingAck = false;
      unawaited(refreshPendingBatches(silent: true));
    }
  }

  Future<void> refreshPendingBatches({bool silent = false}) async {
    if (_userEmail == null) return;
    if (!hasReferenceId) {
      pendingBatches = const [];
      pendingBatchesError = null;
      isPendingBatchesLoading = false;
      notifyListeners();
      return;
    }

    final email = _userEmail!;
    final deviceId = await _ensureDeviceId();

    if (!silent) {
      isPendingBatchesLoading = true;
      pendingBatchesError = null;
      notifyListeners();
    }

    try {
      final rows = await syncService.fetchPendingBatches(
        email: email,
        deviceId: deviceId,
      );
      pendingBatches = rows;
      pendingBatchesError = null;
    } catch (e) {
      _log.w("⚠️ pending batches load failed: $e");
      pendingBatchesError = "Unable to load pending batches";
    } finally {
      isPendingBatchesLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // IMPORT FLAG
  // ─────────────────────────────────────────────
  Future<void> markLocalImportDone() async {
    if (_userEmail == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("$_kLocalImportPrefix$_userEmail", true);

    _hasLocalImport = true;
    _restartAutoSync();
    unawaited(_drainPendingInvalidation(reason: 'local-import-ready'));
    unawaited(triggerSmartSync());
    notifyListeners();
  }

  Future<void> syncNowIfNeededSingleFlight({
    bool force = false,
    bool silent = true,
  }) async {
    if (!canSync || syncRepo == null) return;
    if (isSyncing ||
        _isFinalizingAck ||
        _syncLaunchLock ||
        _globalSyncInProgress) {
      final active = _activeSync;
      if (active != null) {
        await active.valueOrCancellation();
      }
      return;
    }
    if (!await _hasNetwork()) return;

    if (force) {
      _forceMasterSnapshotNextRun = true;
    }

    final shouldSync = await _shouldRunSyncByCursorGate(force: force);
    if (!shouldSync) return;
    await syncNow(silent: silent);
  }

  Future<void> triggerSmartSync({
    bool immediate = false,
    bool force = false,
  }) async {
    if (!canSync || syncRepo == null) return;
    if (isSyncing ||
        _isFinalizingAck ||
        _syncLaunchLock ||
        _globalSyncInProgress) {
      return;
    }
    if (!await _hasNetwork()) return;

    if (force) {
      _forceMasterSnapshotNextRun = true;
    }

    if (!force && !immediate && lastSyncedTime != null) {
      final gap = DateTime.now().difference(lastSyncedTime!);
      if (gap < _minSmartSyncGap) {
        return;
      }
    }

    if (immediate) {
      unawaited(syncNowIfNeededSingleFlight(force: force, silent: true));
      return;
    }

    _fastSyncDebounce?.cancel();
    _fastSyncDebounce = Timer(const Duration(seconds: 2), () {
      if (!isSyncing && !_isFinalizingAck) {
        unawaited(syncNowIfNeededSingleFlight(force: force, silent: true));
      }
    });
  }

  Future<bool> _shouldRunSyncByCursorGate({required bool force}) async {
    if (force) return true;
    if (_userEmail == null || syncRepo == null) return true;

    try {
      final hasLocalChanges = await syncRepo!.hasUnsyncedLocalChanges();
      if (hasLocalChanges) return true;

      final activeCompanyId = await _activeCompanyIdForSync();
      final activeCompanyGuid = await _activeCompanyGuidForSync(
        activeCompanyId,
      );
      final status = await syncService.peekRemoteCursorStatus(
        email: _userEmail!,
        deviceId: await _ensureDeviceId(),
        knownCursor: _lastRemoteCursor,
        companyId: activeCompanyId,
        companyGuid: activeCompanyGuid,
      );

      if (!status.hasUpdates) {
        _log.d("🟢 [SyncGate] skip sync (no remote updates)");
        return false;
      }
      _log.d(
        "🟡 [SyncGate] remote updates detected source=${status.source} cursor=${status.cursor ?? '(missing)'}",
      );
      return true;
    } catch (e) {
      _log.w("⚠️ [SyncGate] cursor check failed; running sync: $e");
      return true; // Fail open: never miss updates.
    }
  }

  void _startConnectivityWatch() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((
      dynamic result,
    ) {
      if (_connectivityHasInternet(result)) {
        unawaited(_drainPendingInvalidation(reason: 'connectivity-restored'));
        unawaited(triggerSmartSync());
      }
    });
  }

  Future<void> _initializeFcmRealtimeSync() async {
    if (kIsWeb || _userEmail == null) return;
    try {
      await _ensureFcmBridgeInitialized();
      await _registerCurrentFcmToken(force: true);
      await _drainPendingInvalidation(reason: 'fcm-init');
    } catch (e) {
      _log.w('⚠️ [SyncPush] init failed: $e');
    }
  }

  Future<void> _ensureFcmBridgeInitialized() async {
    if (_fcmBridgeInitialized) return;
    _fcmBridgeInitialized = true;

    try {
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
    } catch (_) {}

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      _log.w('⚠️ [SyncPush] permission request skipped: $e');
    }

    _fcmTokenRefreshSub?.cancel();
    _fcmTokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
      token,
    ) {
      unawaited(_registerCurrentFcmToken(force: true, explicitToken: token));
    });

    _fcmMessageSub?.cancel();
    _fcmMessageSub = FirebaseMessaging.onMessage.listen((message) {
      unawaited(
        _handlePushInvalidationData(message.data, source: 'fcm-foreground'),
      );
    });

    _fcmOpenAppMessageSub?.cancel();
    _fcmOpenAppMessageSub = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      unawaited(
        _handlePushInvalidationData(message.data, source: 'fcm-opened-app'),
      );
    });

    try {
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        await _handlePushInvalidationData(
          initialMessage.data,
          source: 'fcm-initial-message',
        );
      }
    } catch (e) {
      _log.w('⚠️ [SyncPush] initial message check failed: $e');
    }
  }

  Future<void> _handlePushInvalidationData(
    Map<String, dynamic> rawData, {
    required String source,
  }) async {
    final stored = await SyncInvalidationStore.markFromPayload(
      rawData,
      source: source,
    );
    if (!stored) return;

    final cursor = (rawData['cursor'] ?? '').toString().trim();
    _log.i(
      "📨 [SyncPush] invalidation received source=$source cursor=${cursor.isEmpty ? '(none)' : cursor}",
    );
    await _drainPendingInvalidation(reason: source);
  }

  Future<void> _registerCurrentFcmToken({
    required bool force,
    String? explicitToken,
  }) async {
    if (_userEmail == null || kIsWeb) return;

    final token = (explicitToken ?? await FirebaseMessaging.instance.getToken())
        ?.trim();
    if (token == null || token.isEmpty) return;

    final deviceId = await _ensureDeviceId();
    if (deviceId.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final tokenKey = "$_kPushTokenPrefix$_userEmail";
    final prev = prefs.getString(tokenKey)?.trim();
    if (!force && prev == token) {
      return;
    }

    int? companyId;
    if (syncRepo != null) {
      final resolved = await syncRepo!.resolveDefaultCompanyId();
      if (resolved > 0) {
        companyId = resolved;
      }
    }

    try {
      await syncService.registerDeviceToken(
        email: _userEmail!,
        deviceId: deviceId,
        fcmToken: token,
        platform: _pushPlatformTag(),
        companyId: companyId,
      );
      await prefs.setString(tokenKey, token);
      _log.i(
        "✅ [SyncPush] token registered platform=${_pushPlatformTag()} company=${companyId ?? '(auto)'}",
      );
    } catch (e) {
      _log.w("⚠️ [SyncPush] token register failed: $e");
    }
  }

  Future<void> _drainPendingInvalidation({required String reason}) async {
    if (_processingPendingInvalidation) return;
    _processingPendingInvalidation = true;
    try {
      final pending = await SyncInvalidationStore.peekPending();
      if (!pending.pending) return;

      if (!canSync || syncRepo == null) {
        _log.i("📨 [SyncPush] pending kept (sync blocked) reason=$reason");
        return;
      }

      if (!await _hasNetwork()) {
        _log.i("📨 [SyncPush] pending kept (offline) reason=$reason");
        return;
      }

      final before = lastSyncedTime;
      await syncNowIfNeededSingleFlight(force: true, silent: true);

      final after = lastSyncedTime;
      final synced = after != null && (before == null || after.isAfter(before));
      if (synced) {
        await SyncInvalidationStore.clearPending();
        _log.i(
          "✅ [SyncPush] pending invalidation processed reason=$reason cursor=${pending.cursor ?? '(none)'}",
        );
      } else {
        _log.w(
          "⚠️ [SyncPush] sync did not complete, keeping pending invalidation reason=$reason",
        );
      }
    } catch (e) {
      _log.w("⚠️ [SyncPush] pending drain failed: $e");
    } finally {
      _processingPendingInvalidation = false;
    }
  }

  String _pushPlatformTag() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  bool _consumeForceMasterSnapshotFlag() {
    final force = _forceMasterSnapshotNextRun;
    _forceMasterSnapshotNextRun = false;
    return force;
  }

  Future<void> _persistRemoteCursor(String rawCursor) async {
    final cursor = rawCursor.trim();
    if (cursor.isEmpty || _userEmail == null) return;
    if (_lastRemoteCursor == cursor) return;

    _lastRemoteCursor = cursor;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("$_kRemoteCursorPrefix$_userEmail", cursor);
  }

  // ─────────────────────────────────────────────
  // UI HELPERS
  // ─────────────────────────────────────────────
  String get labelForInterval {
    switch (autoSyncInterval) {
      case AutoSyncInterval.off:
        return "Off";
      case AutoSyncInterval.sec30:
        return "Every 30 seconds";
      case AutoSyncInterval.min2:
        return "Every 2 minutes";
      case AutoSyncInterval.min5:
        return "Every 5 minutes";
      case AutoSyncInterval.min20:
        return "Every 20 minutes";
    }
  }

  String get lastSyncLabel {
    if (lastSyncedTime == null) return "Never synced";
    if (lastSyncResult == null || !lastSyncResult!.hasChanges) {
      return "Last sync: just now";
    }
    return "Last sync: just now • ${lastSyncResult!.label}";
  }

  Future<void> setAutoSyncInterval(AutoSyncInterval interval) async {
    autoSyncInterval = interval;
    if (_userEmail == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      "$_kAutoSyncKeyPrefix$_userEmail",
      autoSyncInterval.index,
    );

    _restartAutoSync();
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────
  Future<bool> _hasNetwork() async {
    final connectivity = await Connectivity().checkConnectivity();
    return _connectivityHasInternet(connectivity);
  }

  bool _connectivityHasInternet(dynamic value) {
    if (value is ConnectivityResult) {
      return value != ConnectivityResult.none;
    }
    if (value is Iterable) {
      for (final entry in value) {
        if (entry is ConnectivityResult && entry != ConnectivityResult.none) {
          return true;
        }
      }
      return false;
    }
    return false;
  }

  void _setState({required bool syncing, double? progress, String? message}) {
    isSyncing = syncing;
    if (progress != null) syncProgress = progress;

    if (!isBackgroundSync && message != null) {
      lastMessage = message;
      notifyListeners();

      Future.delayed(const Duration(seconds: 3), () {
        if (lastMessage == message) {
          lastMessage = '';
          notifyListeners();
        }
      });
      return;
    }

    notifyListeners();
  }

  // ✅ NEW: failsafe unlock
  void _startFailsafeUnlock() {
    _failsafeTimer?.cancel();
    _failsafeTimer = Timer(_failsafeUnlock, () {
      if (isSyncing) {
        _log.e("⛔ Sync stuck → forcing unlock (failsafe)");
        _setState(syncing: false, progress: 0, message: "❌ Sync timeout");
        isBackgroundSync = false;
      }
    });
  }

  void _stopFailsafeUnlock() {
    _failsafeTimer?.cancel();
    _failsafeTimer = null;
  }

  void cancelSync() {
    if (_activeSync != null && !_activeSync!.isCompleted) {
      _activeSync!.cancel();
      _activeSync = null;
      _stopFailsafeUnlock();
      _setState(syncing: false, progress: 0, message: "❌ Sync cancelled");
    }
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _connectivitySub?.cancel();
    _fastSyncDebounce?.cancel();
    _failsafeTimer?.cancel();
    _fcmTokenRefreshSub?.cancel();
    _fcmMessageSub?.cancel();
    _fcmOpenAppMessageSub?.cancel();
    super.dispose();
  }
}
