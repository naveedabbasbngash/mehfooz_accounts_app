// lib/viewmodel/sync/sync_viewmodel.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:async/async.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repository/sync/sync_repository.dart';
import '../../services/device_identity_service.dart';
import '../../services/sync/sync_service.dart';
import '../../data/local/app_database.dart';
import '../../model/SyncResult.dart';

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

class SyncViewModel extends ChangeNotifier {
  final SyncService syncService;
  final Logger _log = Logger();

  SyncViewModel({required this.syncService});

  // 🔔 Callback for Home/Profile refresh
  VoidCallback? onActivationChanged;

  // ─────────────────────────────────────────────
  // CORE STATE
  // ─────────────────────────────────────────────
  SyncRepository? syncRepo;
  String? _userEmail;
  String? _deviceId;

  bool isSyncing = false;
  bool isBackgroundSync = false;
  double syncProgress = 0.0;
  String lastMessage = '';
  DateTime? lastSyncedTime;

  // 🔴 NEW: last sync result
  SyncResult? lastSyncResult;

  CancelableOperation<void>? _activeSync;
  Timer? _autoSyncTimer;
  bool _isFinalizingAck = false;

  // ✅ NEW: failsafe unlock timer (prevents stuck state forever)
  Timer? _failsafeTimer;

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

  // ─────────────────────────────────────────────
  // AUTO SYNC
  // ─────────────────────────────────────────────
  AutoSyncInterval autoSyncInterval = AutoSyncInterval.off;
  static const int _pullMaxRetries = 3;
  static const int _ackMaxRetries = 3;

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
    _deviceId = await DeviceIdentityService.getDeviceId();
    _adminCanSync = adminCanSync;

    _log.i("🔐 Admin sync permission = $_adminCanSync");
    _log.i("📱 Sync device_id=$_deviceId");

    final prefs = await SharedPreferences.getInstance();
    _hasLocalImport = prefs.getBool("$_kLocalImportPrefix$_userEmail") ?? false;

    await _loadAutoSyncSetting();
    _restartAutoSync();
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // DB ATTACH
  // ─────────────────────────────────────────────
  void attachDatabase(AppDatabase db) {
    syncRepo = SyncRepository(db);
    _log.i("🔗 SyncRepository attached/replaced");
    _restartAutoSync();
    notifyListeners();
  }

  bool get isReady => syncRepo != null;

  // ─────────────────────────────────────────────
  // SYNC GATE
  // ─────────────────────────────────────────────
  bool get canSync {
    if (!_adminCanSync) return false;
    if (!_hasLocalImport) return false;
    if (!isReady) return false;
    return true;
  }

  String get syncBlockReason {
    if (!_adminCanSync) return "🔒 Sync disabled by admin";
    if (!_hasLocalImport) return "🟠 Import local database to enable sync";
    if (!isReady) return "⚠ Database not ready";
    return "";
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
    }
  }

  void _restartAutoSync() {
    _autoSyncTimer?.cancel();
    final d = autoSyncDuration;
    if (d == null || !canSync) {
      _log.w("⛔ Auto-sync blocked → $syncBlockReason");
      return;
    }
    _autoSyncTimer = Timer.periodic(d, (_) {
      if (!isSyncing) syncNow(silent: true);
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

    if (isSyncing || _isFinalizingAck) {
      if (!silent) {
        _setState(syncing: isSyncing, message: "Finishing previous sync…");
      }
      return;
    }

    // ✅ IMPORTANT: Don’t silently return on user tap
    final hasNet = await _hasNetwork();
    if (!hasNet) {
      _setState(
        syncing: false,
        progress: 0,
        message: "❌ No internet connection",
      );
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

      // If somehow still marked syncing, force release.
      if (isSyncing) {
        _setState(syncing: false, progress: 0, message: null);
      }
    }
  }

  // ─────────────────────────────────────────────
  // SYNC FLOW
  // ─────────────────────────────────────────────
  Future<String> _ensureDeviceId() async {
    if (_deviceId != null && _deviceId!.trim().isNotEmpty) {
      return _deviceId!;
    }
    _deviceId = await DeviceIdentityService.getDeviceId();
    return _deviceId!;
  }

  Future<void> _runWithRetry(
    String email,
    String deviceId, {
    required bool silent,
  }) async {
    _setState(syncing: true, progress: 0.1, message: "Starting sync…");

    final pullSw = Stopwatch()..start();
    SyncBatch? batch;
    for (int i = 0; i < _pullMaxRetries; i++) {
      try {
        batch = await syncService.pullForMobile(
          email: email,
          deviceId: deviceId,
        );
        break;
      } catch (e) {
        if (i == _pullMaxRetries - 1) rethrow;
        _log.w("⚠️ pull failed (attempt ${i + 1}/$_pullMaxRetries): $e");
        await Future.delayed(Duration(seconds: 2 << i));
      }
    }
    pullSw.stop();
    _log.i("⏱ [Sync] pull ms=${pullSw.elapsedMilliseconds}");

    if (batch == null) {
      lastSyncedTime = DateTime.now();
      lastSyncResult = null;
      _setState(syncing: false, progress: 1, message: "Nothing to update");
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
    _setState(syncing: false, progress: 1, message: "✔ Sync complete");

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
    notifyListeners();
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
    return connectivity.any((c) => c != ConnectivityResult.none);
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
    _failsafeTimer?.cancel();
    super.dispose();
  }
}
