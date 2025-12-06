// lib/viewmodel/sync/sync_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../../repository/sync/sync_repository.dart';
import '../../services/sync/sync_service.dart';
import '../../data/local/app_database.dart';
import '../../data/local/database_manager.dart';

/// =============================================================
///  📜 Sync History Log Entry
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
///  🔄 SyncViewModel
///
/// Orchestrates:
///   ✔ pull-for-mobile
///   ✔ apply batch locally
///   ✔ ack-batch
///   ✔ sync history
///   ✔ last synced time
///   ✔ auto-sync flag
///
/// NOTE:
///   Database is NOT attached in constructor.
///   attachDatabase() must be called AFTER DB restore/import.
/// =============================================================
class SyncViewModel extends ChangeNotifier {
  final SyncService syncService;
  final Logger _log = Logger();

  SyncRepository? syncRepo; // attached later

  bool isSyncing = false;
  String lastMessage = '';

  /// 🕒 Last successful sync time
  DateTime? lastSyncedTime;

  /// 📜 Sync history (latest at index 0)
  final List<SyncLogEntry> history = [];

  /// ⚙️ Auto-sync toggle (HomeScreen timer uses this)
  bool autoSync = true;

  SyncViewModel({
    required this.syncService,
  });

  // -------------------------------------------------------------
  // Attach database AFTER restore/import
  // -------------------------------------------------------------
  void attachDatabase(AppDatabase db) {
    syncRepo = SyncRepository(db);
    _log.i("🔗 SyncRepository attached to SyncViewModel");
    notifyListeners();
  }

  bool get isReady => syncRepo != null;

  void setAutoSync(bool value) {
    autoSync = value;
    notifyListeners();
  }

  // -------------------------------------------------------------
  // Update UI state + auto-hide logic
  // -------------------------------------------------------------
  void _setState({required bool syncing, String? message}) {
    isSyncing = syncing;

    if (message != null) {
      lastMessage = message;
      _addToHistory(message);
    }

    notifyListeners();

    // Auto-hide non-error messages after 3 seconds
    if (!syncing &&
        message != null &&
        message.isNotEmpty &&
        !message.startsWith("❌")) {
      final snapshot = message;
      Future.delayed(const Duration(seconds: 3), () {
        if (!isSyncing && lastMessage == snapshot) {
          lastMessage = '';
          notifyListeners();
        }
      });
    }
  }

  // -------------------------------------------------------------
  // Sync history entry
  // -------------------------------------------------------------
  void _addToHistory(String msg) {
    if (msg.trim().isEmpty) return;

    bool success = !msg.startsWith("❌");

    history.insert(
      0,
      SyncLogEntry(
        timestamp: DateTime.now(),
        success: success,
        message: msg,
      ),
    );

    if (history.length > 50) {
      history.removeLast();
    }
  }

  // -------------------------------------------------------------
  // MAIN SYNC OPERATION
  // -------------------------------------------------------------
  Future<void> syncNow() async {
    if (!isReady) {
      _setState(syncing: false, message: "❌ SyncRepo not ready (DB missing)");
      return;
    }

    if (isSyncing) return;

    _setState(syncing: true, message: "Starting sync...");

    try {
      // 1️⃣ Load email from Db_Info
      final email = await _readEmail();
      if (email == null || email.isEmpty) {
        _setState(syncing: false, message: "❌ No email in Db_Info");
        return;
      }

      _setState(syncing: true, message: "Pulling batch for $email...");

      // 2️⃣ Pull batch
      final batch = await syncService.pullForMobile(email: email);

      if (batch == null) {
        _setState(syncing: false, message: "✔ Nothing to sync");
        return;
      }

      _setState(syncing: true, message: "Applying batch...");

      // 3️⃣ Apply batch using repository
      final repo = syncRepo!;
      final ok = await repo.applyBatch(batch);

      if (!ok) {
        _setState(syncing: false, message: "❌ Failed applying batch");

        await syncService.ackBatch(
          email: email,
          batchId: batch.batchId,
          success: false,
        );

        return;
      }

      _setState(syncing: true, message: "Sending ACK...");

      // 4️⃣ Final ACK
      await syncService.ackBatch(
        email: email,
        batchId: batch.batchId,
        success: true,
      );

      // ⭐ Update last synced time
      lastSyncedTime = DateTime.now();

      _setState(syncing: false, message: "✔ Sync complete");
    } catch (e, st) {
      _log.e("❌ Sync error", error: e, stackTrace: st);
      _setState(syncing: false, message: "❌ Sync failed: $e");
    }
  }

  // -------------------------------------------------------------
  // READ EMAIL FROM Db_Info
  // -------------------------------------------------------------
  Future<String?> _readEmail() async {
    try {
      final db = DatabaseManager.instance.db;
      final rows = await db.select(db.dbInfoTable).get();
      if (rows.isEmpty) return null;
      return rows.first.emailAddress;
    } catch (e) {
      _log.e("❌ Failed to read Db_Info", error: e);
      return null;
    }
  }
}