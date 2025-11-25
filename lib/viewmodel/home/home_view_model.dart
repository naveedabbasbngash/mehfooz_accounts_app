// lib/viewmodel/home/home_view_model.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/database_manager.dart';
import '../../model/cash_in_hand_row.dart';
import '../../model/cash_summary_row.dart';
import '../../repository/account_repository.dart';
import '../../services/sqlite_import_service.dart';
import '../../services/sqlite_validation_service.dart';
import '../../model/pending_amount_row.dart';

class HomeViewModel extends ChangeNotifier {
  final Logger _log = Logger();

  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey drawerKey;
  List<CashInHandRow> cashInHandSummary = [];
  List<CashSummaryRow> acc1CashSummary = [];
  HomeViewModel({
    required this.navigatorKey,
    required this.drawerKey,
  });

  /// Active database path
  String? verifiedDbPath;

  /// The company selected from Profile screen
  int? selectedCompanyId;

  /// Summary data
  List<PendingAmountRow> pendingAmounts = [];

  bool _isImporting = false;
  bool get isImporting => _isImporting;

  bool _hasRestored = false;

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

      // Restore chosen company
      await _restoreCompanySelection();

      // Load summary only if company selected
      if (selectedCompanyId != null) {
        await loadPendingAmounts();
      }

      _log.i("✅ Database restored successfully.");
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
    } catch (e, st) {
      _log.e("❌ DB import failed", error: e, stackTrace: st);
      rethrow;
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // COMPANY SELECTION (Called from ProfileViewModel)
  // ---------------------------------------------------------------------------
  Future<void> selectCompany(int companyId) async {
    selectedCompanyId = companyId;

    // Save to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("selected_company_id", companyId);

    _log.i("🏢 Selected company saved: $companyId");

    // Reload summary
    await loadPendingAmounts();
  }

  // Restore previously selected company
  Future<void> _restoreCompanySelection() async {
    final prefs = await SharedPreferences.getInstance();
    selectedCompanyId = prefs.getInt("selected_company_id");

    if (selectedCompanyId != null) {
      _log.i("🏢 Restored company selection: $selectedCompanyId");
    } else {
      _log.w("⚠ No company selected yet.");
    }
  }

  // ---------------------------------------------------------------------------
  // LOAD PENDING SUMMARY (REQUIRES company ID)
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
      _log.i("📊 Summary loaded for company ID: $selectedCompanyId");

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
    pendingAmounts = [];
    _hasRestored = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("selected_company_id");

    notifyListeners();
  }
}