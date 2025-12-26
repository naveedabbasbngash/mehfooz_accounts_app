import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/database_manager.dart';
import '../../model/cash_in_hand_row.dart';
import '../../model/cash_summary_row.dart';
import '../../model/pending_amount_row.dart';
import '../../repository/account_repository.dart';
import '../../services/global_state.dart';
import '../../services/sqlite_import_service.dart';
import '../../services/sqlite_validation_service.dart';

import '../../ui/commons/confirm_action.dart';
import '../../ui/commons/confirm_action_dialog.dart';
import '../../viewmodel/sync/sync_viewmodel.dart';
import '../../model/user_model.dart';
import '../profile/profile_view_model.dart';

class HomeViewModel extends ChangeNotifier {
  final Logger _log = Logger();

  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey drawerKey;

  HomeViewModel({
    required this.navigatorKey,
    required this.drawerKey,
  });

  // ─────────────────────────────────────────────
  // STATE
  // ─────────────────────────────────────────────
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

  // ─────────────────────────────────────────────
  // CONNECT SYNC VM (called from main.dart)
  // ─────────────────────────────────────────────
  void registerSyncVM(SyncViewModel vm, UserModel user) {
    syncVM = vm;

    final adminCanSync = user.planStatus?.canSync ?? false;

    vm.configureForUser(
      email: DatabaseManager.instance.activeUserEmail ?? user.email,
      adminCanSync: adminCanSync,
    );

    if (DatabaseManager.instance.activeDbPath != null) {
      vm.attachDatabase(DatabaseManager.instance.db);
    }

    vm.onActivationChanged = () async {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        await ctx.read<ProfileViewModel>().refresh();

      }
    };

    _log.i("🔗 SyncVM registered | adminCanSync=$adminCanSync");
  }

  // ─────────────────────────────────────────────
  // INIT — RESTORE USER DB
  // ─────────────────────────────────────────────
  Future<void> init({required UserModel user}) async {
    if (_hasRestored) return;

    _log.i("🏁 HomeViewModel.init → ${user.email}");

    final restored =
    await DatabaseManager.instance.restoreDatabaseForUser(user.email);

    if (restored) {
      verifiedDbPath = DatabaseManager.instance.activeDbPath;

      await _restoreCompanySelection();
      await loadPendingAmounts();

      // 🔗 Attach DB to SyncViewModel (SAFE)
      if (syncVM != null) {
        syncVM!.attachDatabase(DatabaseManager.instance.db);
        await syncVM!.markLocalImportDone();
      }
    } else {
      _log.w("⚠ No local DB restored for user");
    }

    _hasRestored = true;
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // IMPORT DATABASE (NO SYNC UNLOCK HERE)
  // ─────────────────────────────────────────────
  Future<void> importDatabase(String inputPath, UserModel user) async {
    _isImporting = true;
    notifyListeners();

    try {
      _log.i("📥 Importing SQLite DB for ${user.email}");

      final importedPath =
      await SqliteImportService.importAndSaveDb(inputPath);
      if (importedPath == null) {
        throw Exception("Failed to import database");
      }

      await SqliteValidationService().validateDatabase(importedPath);

      final previewDb =
      await DatabaseManager.instance.previewDatabase(importedPath);
      final info = await previewDb.select(previewDb.dbInfoTable).get();

      if (info.isEmpty) {
        throw Exception("Invalid DB: Db_Info missing");
      }

      final dbEmail =
      (info.first.emailAddress ?? "").trim().toLowerCase();
      final userEmail = user.email.trim().toLowerCase();

      if (dbEmail != userEmail) {
        throw Exception(
          "This database belongs to another user.\n\n"
              "Your Email: $userEmail",
        );
      }

      await DatabaseManager.instance.useImportedDbForUser(
        importedPath,
        user.email,
      );

      verifiedDbPath = DatabaseManager.instance.activeDbPath;

      if (selectedCompanyId != null) {
        await loadPendingAmounts();
      }

      // ✅ ONLY attach DB — DO NOT unlock sync
      if (syncVM != null) {
        syncVM!.attachDatabase(DatabaseManager.instance.db);
        _log.i("📦 DB attached to SyncVM after import");
      }
    } catch (e, st) {
      _log.e("❌ Import failed", error: e, stackTrace: st);
      rethrow;
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // COMPANY SELECTION
  // ─────────────────────────────────────────────
  Future<void> _restoreCompanySelection() async {
    final prefs = await SharedPreferences.getInstance();
    selectedCompanyId = prefs.getInt("selected_company_id") ?? 1;

    final db = DatabaseManager.instance.db;
    final rows = await (db.select(db.companyTable)
      ..where((t) => t.companyId.equals(selectedCompanyId!)))
        .get();

    selectedCompanyName =
    rows.isNotEmpty ? rows.first.companyName : "Your Company";

    GlobalState.instance.setCompany(
      id: selectedCompanyId!,
      name: selectedCompanyName!,
    );
  }

  Future<void> setCompany(int id) async {
    selectedCompanyId = id;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("selected_company_id", id);

    final db = DatabaseManager.instance.db;
    final rows = await (db.select(db.companyTable)
      ..where((t) => t.companyId.equals(id)))
        .get();

    selectedCompanyName =
    rows.isNotEmpty ? rows.first.companyName : "Your Company";

    GlobalState.instance.setCompany(
      id: id,
      name: selectedCompanyName!,
    );

    await loadPendingAmounts();
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // DASHBOARD DATA
  // ─────────────────────────────────────────────
  Future<void> loadPendingAmounts() async {
    if (selectedCompanyId == null) return;

    try {
      final repo = AccountRepository(DatabaseManager.instance.db);

      pendingAmounts =
      await repo.getPendingAmountSummary(selectedCompanyId: selectedCompanyId!);

      cashInHandSummary =
      await repo.getCashInHandSummary(selectedCompanyId: selectedCompanyId!);

      acc1CashSummary =
      await repo.getAcc1CashSummary(selectedCompanyId!);
    } catch (e, st) {
      _log.e("❌ Dashboard load failed", error: e, stackTrace: st);
    }

    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // LOGOUT CLEANUP
  // ─────────────────────────────────────────────
  Future<void> clearOnLogout(UserModel user) async {
    _log.w("🚪 Clearing HomeViewModel state");

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


  Future<void> confirmAndImportDatabase({
    required BuildContext context,
    required String inputPath,
    required UserModel user,
  }) async {
    // ✅ Always use ROOT navigator for dialogs in your app
    final rootCtx = navigatorKey.currentContext ?? context;

    final confirmed = await showDialog<bool>(
      context: rootCtx,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text("Import Database"),
        content: const Text(
          "This will replace your current local database.\n\n"
              "Do you want to continue?",
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogCtx, rootNavigator: true).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogCtx, rootNavigator: true).pop(true),
            child: const Text("Import"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {

      await importDatabase(inputPath, user);

// 🔓 IMPORTANT: notify ProfileViewModel to remove restriction
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        await ctx.read<ProfileViewModel>().onLocalDatabaseImported();

        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text("✅ Database imported successfully"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;

      showDialog(
        context: ctx,
        useRootNavigator: true,
        builder: (_) => AlertDialog(
          title: const Text("Import Failed"),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }
}