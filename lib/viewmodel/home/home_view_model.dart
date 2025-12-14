// lib/viewmodel/home/home_view_model.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/database_manager.dart';
import '../../model/cash_in_hand_row.dart';
import '../../model/cash_summary_row.dart';
import '../../model/pending_amount_row.dart';
import '../../repository/account_repository.dart';
import '../../services/global_state.dart';
import '../../services/sqlite_import_service.dart';
import '../../services/sqlite_validation_service.dart';

import '../../viewmodel/sync/sync_viewmodel.dart';
import '../../model/user_model.dart';

class HomeViewModel extends ChangeNotifier {
  final Logger _log = Logger();

  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey drawerKey;

  int? selectedCompanyId;
  String? selectedCompanyName;

  String? verifiedDbPath;

  bool _hasRestored = false;
  bool _isImporting = false;
  bool get isImporting => _isImporting;

  SyncViewModel? syncVM;

  List<CashInHandRow> cashInHandSummary = [];
  List<CashSummaryRow> acc1CashSummary = [];
  List<PendingAmountRow> pendingAmounts = [];

  HomeViewModel({
    required this.navigatorKey,
    required this.drawerKey,
  });

  // ------------------------------------------------------------
  // CONNECT SyncVM to DB (called from main.dart)
  // ------------------------------------------------------------
  void registerSyncVM(SyncViewModel vm) {
    syncVM = vm;
    _log.i("🔗 SyncViewModel linked");

    // If DB already restored → attach immediately
    if (DatabaseManager.instance.activeDbPath != null) {
      try {
        vm.attachDatabase(DatabaseManager.instance.db);
        _log.i("🔗 Existing DB attached to SyncVM (registerSyncVM)");
      } catch (e) {
        _log.e("❌ Failed attaching DB to SyncVM", error: e);
      }
    }
  }

  // ------------------------------------------------------------
  // INIT — Restore per-user DB
  // ------------------------------------------------------------
  Future<void> init({required UserModel user}) async {
    _log.i("🏁 HomeViewModel.init() → ${user.email}");

    if (_hasRestored) {
      _log.i("ℹ Already restored → skipping");
      return;
    }

    // Try restore DB
    final restored =
    await DatabaseManager.instance.restoreDatabaseForUser(user.email);

    if (restored) {
      _log.i("✅ User DB restored");

      verifiedDbPath = DatabaseManager.instance.activeDbPath;

      await _restoreCompanySelection();
      await loadPendingAmounts();

      // ⭐ CRITICAL: Attach DB to SyncVM here
      if (syncVM != null) {
        try {
          syncVM!.attachDatabase(DatabaseManager.instance.db);
          _log.i("🔗 DB attached to SyncVM (init)");
        } catch (e) {
          _log.e("❌ SyncVM attach failed", error: e);
        }
      }
    } else {
      _log.w("⚠ No DB restored for this user");
    }

    _hasRestored = true;
    notifyListeners();
  }

  // ------------------------------------------------------------
  // IMPORT DATABASE — includes email validation
  // ------------------------------------------------------------
  Future<void> importDatabase(String inputPath, UserModel user) async {
    _isImporting = true;
    notifyListeners();

    try {
      _log.i("📥 Starting import for → ${user.email}");

      // 1️⃣ Copy to app folder
      final importedTempPath =
      await SqliteImportService.importAndSaveDb(inputPath);

      if (importedTempPath == null) {
        throw Exception("❌ Failed importing DB");
      }

      // 2️⃣ Validate schema
      await SqliteValidationService().validateDatabase(importedTempPath);

      // 3️⃣ Read Db_Info BEFORE switching database
      final previewDb =
      await DatabaseManager.instance.previewDatabase(importedTempPath);

      final info = await previewDb.select(previewDb.dbInfoTable).get();
      if (info.isEmpty) {
        throw Exception("❌ Invalid database: Db_Info missing");
      }

      final dbEmail =
      (info.first.emailAddress ?? "").trim().toLowerCase();
      final userEmail = user.email.trim().toLowerCase();

      // 4️⃣ SECURITY: prevent wrong DB import
      if (dbEmail != userEmail) {
        throw Exception(
          "❌ Import Blocked!\n\n"
              "This SQLite file belongs to another Mahfooz user.\n\n"
              "DB Email: $dbEmail\n"
              "Your Email: $userEmail\n",
        );
      }

      _log.i("🔐 DB ownership verified — safe to import");

      // 5️⃣ Activate NEW DB for this user
      await DatabaseManager.instance.useImportedDbForUser(
        importedTempPath,
        user.email,
      );

      verifiedDbPath = DatabaseManager.instance.activeDbPath;

      // 6️⃣ Reload summaries
      if (selectedCompanyId != null) {
        await loadPendingAmounts();
      }

      // 7️⃣ Re-attach DB to SyncVM
      if (syncVM != null) {
        try {
          syncVM!.attachDatabase(DatabaseManager.instance.db);
          _log.i("🔗 DB attached to SyncVM (import)");
        } catch (e) {
          _log.e("❌ SyncVM attach failed", error: e);
        }
      }

      _log.i("🎉 Import completed successfully");

    } catch (e, st) {
      _log.e("❌ Import failed", error: e, stackTrace: st);
      rethrow;
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------
  // Restore company selection
  // ------------------------------------------------------------
  Future<void> _restoreCompanySelection() async {
    final prefs = await SharedPreferences.getInstance();
    selectedCompanyId = prefs.getInt("selected_company_id") ?? 1;

    final db = DatabaseManager.instance.db;
    final result = await (db.select(db.companyTable)
      ..where((t) => t.companyId.equals(selectedCompanyId!)))
        .get();

    selectedCompanyName =
    result.isNotEmpty ? (result.first.companyName ?? "Your Company") : "Your Company";

    GlobalState.instance.setCompany(
      id: selectedCompanyId!,
      name: selectedCompanyName!,
    );

    _log.i("🏢 Company restored → $selectedCompanyId | $selectedCompanyName");
  }

  // ------------------------------------------------------------
  // Change company
  // ------------------------------------------------------------
  Future<void> setCompany(int id) async {
    selectedCompanyId = id;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("selected_company_id", id);

    final db = DatabaseManager.instance.db;

    final rows = await (db.select(db.companyTable)
      ..where((t) => t.companyId.equals(id)))
        .get();

    selectedCompanyName =
    rows.isNotEmpty ? (rows.first.companyName ?? "Your Company") : "Your Company";

    GlobalState.instance.setCompany(
      id: id,
      name: selectedCompanyName!,
    );

    await loadPendingAmounts();
    notifyListeners();
  }

  // ------------------------------------------------------------
  // Load Dashboard Summaries
  // ------------------------------------------------------------
  Future<void> loadPendingAmounts() async {
    if (selectedCompanyId == null) {
      _log.w("⚠ Cannot load summaries — No company selected");
      return;
    }

    try {
      final repo = AccountRepository(DatabaseManager.instance.db);

      pendingAmounts =
      await repo.getPendingAmountSummary(selectedCompanyId: selectedCompanyId!);

      cashInHandSummary =
      await repo.getCashInHandSummary(selectedCompanyId: selectedCompanyId!);

      acc1CashSummary =
      await repo.getAcc1CashSummary(selectedCompanyId!);

      _log.i("📊 Dashboard summaries loaded");

    } catch (e, st) {
      _log.e("❌ Error loading dashboard summaries", error: e, stackTrace: st);
    }

    notifyListeners();
  }

  // ------------------------------------------------------------
  // LOGOUT CLEANUP
  // ------------------------------------------------------------
  Future<void> clearOnLogout(UserModel user) async {
    _log.w("🚪 Clearing HomeViewModel state...");

    verifiedDbPath = null;
    selectedCompanyId = null;
    selectedCompanyName = null;

    pendingAmounts.clear();
    cashInHandSummary.clear();
    acc1CashSummary.clear();

    _hasRestored = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("selected_company_id");

    await DatabaseManager.instance.clearUserDb(user.email);

    GlobalState.instance.setCompany(id: 1, name: "Your Company");

    notifyListeners();
  }
}