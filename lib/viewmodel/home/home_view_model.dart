// lib/viewmodel/home/home_view_model.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/database_manager.dart';
import '../../model/cash_in_hand_row.dart';
import '../../model/cash_summary_row.dart';
import '../../repository/account_repository.dart';
import '../../services/global_state.dart';
import '../../services/sqlite_import_service.dart';
import '../../services/sqlite_validation_service.dart';
import '../../model/pending_amount_row.dart';

// 🔥 NEW
import '../../viewmodel/sync/sync_viewmodel.dart';

class HomeViewModel extends ChangeNotifier {
  final Logger _log = Logger();

  int? selectedCompanyId;
  String? selectedCompanyName;

  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey drawerKey;

  List<CashInHandRow> cashInHandSummary = [];
  List<CashSummaryRow> acc1CashSummary = [];
  List<PendingAmountRow> pendingAmounts = [];

  HomeViewModel({
    required this.navigatorKey,
    required this.drawerKey,
  });

  /// Active database path
  String? verifiedDbPath;

  bool _isImporting = false;
  bool get isImporting => _isImporting;

  bool _hasRestored = false;

  // 🔥 NEW: Sync ViewModel reference
  SyncViewModel? syncVM;

  // ---------------------------------------------------------------------------
  // NEW → Register SyncViewModel (called from main.dart)
  // ---------------------------------------------------------------------------
  void registerSyncVM(SyncViewModel vm) {
    syncVM = vm;
    _log.i("🔗 SyncViewModel registered inside HomeViewModel");

    // If DB already restored, attach immediately
    if (DatabaseManager.instance.activeDbPath != null) {
      try {
        vm.attachDatabase(DatabaseManager.instance.db);
        _log.i("🔗 Attached existing DB to SyncViewModel");
      } catch (e) {
        _log.e("❌ Failed attaching DB to SyncViewModel", error: e);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // INIT — Only restore DB when user is logged in
  // ---------------------------------------------------------------------------
  Future<void> init({required bool isUserLoggedIn}) async {
    _log.i("🔄 HomeViewModel.init() → Checking login + DB state...");

    if (!isUserLoggedIn) {
      _log.w("⚠ User not logged in → Skipping DB restore");
      _hasRestored = false;
      return;
    }

    if (_hasRestored) {
      _log.i("ℹ DB already restored in this session → Skipping");
      return;
    }

    final restored = await DatabaseManager.instance.restoreDatabaseIfExists();

    if (restored) {
      verifiedDbPath = DatabaseManager.instance.activeDbPath;

      // 🔹 Restore (or default) company selection + name + GlobalState
      await _restoreCompanySelection();

      // Load summary only if company selected
      if (selectedCompanyId != null) {
        await loadPendingAmounts();
      }

      _log.i("✅ Database restored successfully.");

      // 🔥 NEW → Attach DB to SyncVM after restore
      if (syncVM != null) {
        try {
          syncVM!.attachDatabase(DatabaseManager.instance.db);
          _log.i("🔗 DB attached to SyncViewModel after restore");
        } catch (e) {
          _log.e("❌ Failed attaching restored DB to SyncVM", error: e);
        }
      }
    } else {
      _log.w("⚠ No saved database found.");
    }

    _hasRestored = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // IMPORT DATABASE (.sqlite / .db)
  // ---------------------------------------------------------------------------
  Future<void> importDatabase(String inputPath) async {
    _isImporting = true;
    notifyListeners();

    try {
      _log.i("📂 Importing DB: $inputPath");

      final importedPath = await SqliteImportService.importAndSaveDb(inputPath);

      if (importedPath == null) {
        throw Exception("❌ Invalid database file.");
      }

      // Validate schema
      await SqliteValidationService().validateDatabase(importedPath);

      // Activate the DB and load summary (company must be selected)
      await DatabaseManager.instance.activateAndThen(
        importedPath,
            (db) async {
          final repo = AccountRepository(db);

          if (selectedCompanyId != null) {
            pendingAmounts = await repo.getPendingAmountSummary(
              selectedCompanyId: selectedCompanyId!,
            );
          }
        },
      );

      verifiedDbPath = DatabaseManager.instance.activeDbPath;

      _log.i("✅ Database imported + activated.");

      // 🔥 NEW → Attach DB to SyncVM after import
      if (syncVM != null) {
        try {
          syncVM!.attachDatabase(DatabaseManager.instance.db);
          _log.i("🔗 DB attached to SyncViewModel after import");
        } catch (e) {
          _log.e("❌ Failed attaching imported DB to SyncVM", error: e);
        }
      }
    } catch (e, st) {
      _log.e("❌ DB import failed", error: e, stackTrace: st);
      rethrow;
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // COMPANY SELECTION (legacy entry point - delegate to setCompany)
  // ---------------------------------------------------------------------------
  Future<void> selectCompany(int companyId) async {
    await setCompany(companyId);
  }

  // ---------------------------------------------------------------------------
  // Restore previously selected company
  // ---------------------------------------------------------------------------
  Future<void> _restoreCompanySelection() async {
    final prefs = await SharedPreferences.getInstance();
    final storedId = prefs.getInt("selected_company_id");

    if (storedId != null) {
      selectedCompanyId = storedId;
      _log.i("🏢 Restored company selection from prefs: $selectedCompanyId");
    } else {
      selectedCompanyId = 1;
      await prefs.setInt("selected_company_id", 1);
      _log.w("ℹ No company in prefs → defaulting to companyId=1");
    }

    // Load company name
    if (selectedCompanyId != null) {
      final db = DatabaseManager.instance.db;
      final result = await (db.select(db.companyTable)
        ..where((tbl) => tbl.companyId.equals(selectedCompanyId!)))
          .get();

      selectedCompanyName = result.isNotEmpty
          ? (result.first.companyName ?? "Your Company")
          : "Your Company";

      GlobalState.instance.setCompany(
        id: selectedCompanyId!,
        name: selectedCompanyName!,
      );

      _log.i(
        "🏢 Company restored → id=$selectedCompanyId, name=$selectedCompanyName",
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Set company ID
  // ---------------------------------------------------------------------------
  Future<void> setCompany(int id) async {
    selectedCompanyId = id;

    final db = DatabaseManager.instance.db;
    final result = await (db.select(db.companyTable)
      ..where((tbl) => tbl.companyId.equals(id)))
        .get();

    selectedCompanyName = result.isNotEmpty
        ? (result.first.companyName ?? "Your Company")
        : "Your Company";

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("selected_company_id", id);

    GlobalState.instance.setCompany(
      id: selectedCompanyId!,
      name: selectedCompanyName!,
    );

    _log.i("🏢 setCompany → $selectedCompanyId / $selectedCompanyName");

    await loadPendingAmounts();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // LOAD PENDING SUMMARY
  // ---------------------------------------------------------------------------
  Future<void> loadPendingAmounts() async {
    try {
      if (selectedCompanyId == null) {
        _log.w("⚠ Cannot load summary → Company not selected.");
        pendingAmounts = [];
        notifyListeners();
        return;
      }

      final repo = AccountRepository(DatabaseManager.instance.db);

      pendingAmounts = await repo.getPendingAmountSummary(
        selectedCompanyId: selectedCompanyId!,
      );

      cashInHandSummary = await repo.getCashInHandSummary(
        selectedCompanyId: selectedCompanyId!,
      );

      acc1CashSummary =
      await repo.getAcc1CashSummary(selectedCompanyId!);

      _log.i("📊 Summary loaded for company $selectedCompanyId");

      notifyListeners();
    } catch (e) {
      _log.e("❌ loadPendingAmounts failed: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // LOGOUT — Reset full state
  // ---------------------------------------------------------------------------
  Future<void> clearOnLogout() async {
    _log.w("🚪 HomeViewModel.clearOnLogout() → Resetting state...");

    verifiedDbPath = null;
    selectedCompanyId = null;
    selectedCompanyName = null;
    pendingAmounts = [];
    cashInHandSummary = [];
    acc1CashSummary = [];
    _hasRestored = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("selected_company_id");

    GlobalState.instance.setCompany(
      id: 1,
      name: "Your Company",
    );

    notifyListeners();
  }
}