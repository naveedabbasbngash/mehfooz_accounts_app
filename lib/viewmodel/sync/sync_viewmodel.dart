import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:async/async.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repository/sync/sync_repository.dart';
import '../../services/sync/sync_service.dart';
import '../../data/local/app_database.dart';
import '../../data/local/database_manager.dart';

/// =============================================================
/// Auto Sync Interval Options (TOP LEVEL)
/// =============================================================
enum AutoSyncInterval {
  off,
  sec30,
  min2,
  min5,
  min20,
}

/// =============================================================
/// Sync History Entry
/// =============================================================
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

/// =============================================================
/// Sync ViewModel
/// =============================================================
class SyncViewModel extends ChangeNotifier {
  final SyncService syncService;
  final Logger _log = Logger();

  SyncRepository? syncRepo;

  bool isSyncing = false;
  bool isBackgroundSync = false;

  double syncProgress = 0.0;
  String lastMessage = '';
  DateTime? lastSyncedTime;

  final List<SyncLogEntry> history = [];

  /// 🔁 Auto sync
  AutoSyncInterval autoSyncInterval = AutoSyncInterval.min5;
  Timer? _autoSyncTimer;

  CancelableOperation<void>? _activeSync;

  static const _prefKey = "auto_sync_interval";
  static const int _maxRetries = 3;
  static const Duration _timeout = Duration(seconds: 30);

  SyncViewModel({required this.syncService});

  // ------------------------------------------------------------
  // DB Attach
  // ------------------------------------------------------------
  void attachDatabase(AppDatabase db) {
    syncRepo = SyncRepository(db);
    restoreAutoSync();
    notifyListeners();
  }

  bool get isReady => syncRepo != null;

  // ------------------------------------------------------------
  // Auto Sync Helpers
  // ------------------------------------------------------------
  bool get isAutoSyncEnabled => autoSyncInterval != AutoSyncInterval.off;

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

  String get autoSyncLabel {
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

  Future<void> restoreAutoSync() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_prefKey);
    if (index != null && index < AutoSyncInterval.values.length) {
      autoSyncInterval = AutoSyncInterval.values[index];
    }
    _restartAutoSync();
    notifyListeners();
  }

  Future<void> setAutoSyncInterval(AutoSyncInterval interval) async {
    autoSyncInterval = interval;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, interval.index);
    _restartAutoSync();
    notifyListeners();
  }

  void _restartAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;

    final duration = autoSyncDuration;
    if (duration == null || !isReady) return;

    _autoSyncTimer = Timer.periodic(duration, (_) async {
      if (!isSyncing) {
        await syncNow(silent: true);
      }
    });
  }

  // ------------------------------------------------------------
  // Network
  // ------------------------------------------------------------
  Future<bool> _hasNetwork() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  // ------------------------------------------------------------
  // Cancel Sync
  // ------------------------------------------------------------
  void cancelSync() {
    if (_activeSync != null && !_activeSync!.isCompleted) {
      _activeSync!.cancel();
      _activeSync = null;

      _setState(
        syncing: false,
        progress: 0,
        message: "❌ Sync cancelled",
      );
    }
  }

  // ------------------------------------------------------------
  // Public Sync
  // ------------------------------------------------------------
  Future<void> syncNow({bool silent = false}) async {
    if (!isReady || isSyncing) return;

    if (!await _hasNetwork()) {
      _setState(syncing: false, message: "❌ No internet connection");
      return;
    }

    isBackgroundSync = silent;

    _activeSync = CancelableOperation.fromFuture(
      _runWithRetry(),
      onCancel: () => _log.w("⛔ Sync cancelled"),
    );

    try {
      await _activeSync!.value;
    } finally {
      _activeSync = null;
      isBackgroundSync = false;
    }
  }

  // ------------------------------------------------------------
  // Retry Wrapper
  // ------------------------------------------------------------
  Future<void> _runWithRetry() async {
    int attempt = 0;

    while (attempt < _maxRetries) {
      try {
        await _runSyncFlow().timeout(_timeout);
        return;
      } catch (e) {
        attempt++;
        if (attempt >= _maxRetries) {
          _setState(
            syncing: false,
            progress: 0,
            message: "❌ Sync failed after retries",
          );
          return;
        }
        final delay = Duration(seconds: 2 << attempt);
        await Future.delayed(delay);
      }
    }
  }

  // ------------------------------------------------------------
  // Core Sync Flow
  // ------------------------------------------------------------
  Future<void> _runSyncFlow() async {
    _setState(syncing: true, progress: 0.05, message: "Starting sync...");

    final email = await _readEmail();
    if (email == null) {
      _setState(syncing: false, message: "❌ No email in Db_Info");
      return;
    }

    _setState(syncing: true, progress: 0.2, message: "Pulling batch for $email...");

    final batch = await syncService.pullForMobile(email: email);
    if (batch == null) {
      _setState(syncing: false, progress: 1, message: "✔ Nothing to sync");
      return;
    }

    _setState(syncing: true, progress: 0.5, message: "Applying batch...");

    final ok = await syncRepo!.applyBatch(batch);
    if (!ok) {
      await syncService.ackBatch(
        email: email,
        batchId: batch.batchId,
        success: false,
      );
      throw Exception("Apply batch failed");
    }

    _setState(syncing: true, progress: 0.8, message: "Sending ACK...");

    await syncService.ackBatch(
      email: email,
      batchId: batch.batchId,
      success: true,
    );

    lastSyncedTime = DateTime.now();
    _setState(syncing: false, progress: 1, message: "✔ Sync complete");
  }

  // ------------------------------------------------------------
  void _setState({
    required bool syncing,
    double? progress,
    String? message,
  }) {
    isSyncing = syncing;
    if (progress != null) syncProgress = progress;

    if (!isBackgroundSync && message != null) {
      lastMessage = message;
      history.insert(
        0,
        SyncLogEntry(
          timestamp: DateTime.now(),
          success: !message.startsWith("❌"),
          message: message,
        ),
      );
    }

    notifyListeners();
  }

  Future<String?> _readEmail() async {
    try {
      final db = DatabaseManager.instance.db;
      final rows = await db.select(db.dbInfoTable).get();
      return rows.isEmpty ? null : rows.first.emailAddress;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }
}