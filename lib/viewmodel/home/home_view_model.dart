import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🍎 REQUIRED
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/database_manager.dart';
import '../../data/local/app_database.dart';
import '../../model/cash_in_hand_row.dart';
import '../../model/cash_summary_row.dart';
import '../../model/pending_amount_row.dart';
import '../../repository/account_repository.dart';
import '../../services/global_state.dart';
import '../../services/sqlite_import_service.dart';
import '../../services/sqlite_validation_service.dart';

import '../../viewmodel/sync/sync_viewmodel.dart';
import '../../model/user_model.dart';
import '../profile/profile_view_model.dart';

class HomeViewModel extends ChangeNotifier {
  final Logger _log = Logger();

  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey drawerKey;

  HomeViewModel({required this.navigatorKey, required this.drawerKey});

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  // 🍎 APPLE REVIEW ACCOUNT
  static const String _appleReviewEmail = 'applereviewmehfooz@gmail.com';

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
  // STREAM SUBSCRIPTIONS
  // ─────────────────────────────────────────────
  StreamSubscription<List<CashInHandRow>>? _cashInHandSub;
  StreamSubscription<List<CashSummaryRow>>? _acc1CashSub;
  StreamSubscription<List<PendingAmountRow>>? _pendingSub;

  // ─────────────────────────────────────────────
  // CONNECT SYNC VM
  // ─────────────────────────────────────────────
  void registerSyncVM(SyncViewModel vm, UserModel user) {
    syncVM = vm;

    final adminCanSync = user.planStatus?.canSync ?? true;

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
    // 🔑 Single identity for this init run
    final trace = "HOME_INIT_${DateTime.now().millisecondsSinceEpoch}";

    if (_hasRestored) {
      _log.w("[$trace] ⛔ init skipped (_hasRestored = true)");
      return;
    }

    _log.i("[$trace] 🏁 init START → email=${user.email}");

    try {
      // --------------------------------------------------
      // 1️⃣ Try restore existing DB
      // --------------------------------------------------
      _log.i("[$trace] 📦 Calling restoreDatabaseForUser...");
      final restored = await DatabaseManager.instance.restoreDatabaseForUser(
        user.email,
      );

      _log.i("[$trace] 📦 restoreDatabaseForUser result = $restored");

      // --------------------------------------------------
      // 🍎 Apple Review Auto Demo DB
      // --------------------------------------------------
      // 🍎 APPLE REVIEW — ALWAYS FORCE DEMO DB
      if (user.email == _appleReviewEmail) {
        _log.w("🍎 Apple Review user — forcing demo DB");

        await DatabaseManager.instance.clearUserDb(user.email);

        final demoPath = await _loadAppleReviewDemoDb(user.email);

        if (demoPath == null) {
          _log.e("❌ Apple demo DB failed to load");
        } else {
          verifiedDbPath = demoPath;
          _log.i("🍎 Demo DB forced → $demoPath");

          await _restoreCompanySelection();
          _startDashboardStreams();

          if (syncVM != null) {
            syncVM!.attachDatabase(DatabaseManager.instance.db);
            await syncVM!.markLocalImportDone();
          }

          _hasRestored = true;
          notifyListeners();
          return;
        }
      }

      // --------------------------------------------------
      // ✅ Normal restore path
      // --------------------------------------------------
      if (restored) {
        verifiedDbPath = DatabaseManager.instance.activeDbPath;
        _log.i("[$trace] ✅ Local DB restored → $verifiedDbPath");

        _log.i("[$trace] 🏢 Restoring company selection...");
        await _restoreCompanySelection();

        _log.i("[$trace] 📊 Starting dashboard streams...");
        _startDashboardStreams();

        if (syncVM != null) {
          _log.i("[$trace] 🔗 Attaching DB to SyncVM...");
          syncVM!.attachDatabase(DatabaseManager.instance.db);

          _log.i("[$trace] ☑ Marking local import done...");
          await syncVM!.markLocalImportDone();
        } else {
          _log.w("[$trace] ⚠ syncVM is NULL (restore path)");
        }
      } else {
        _log.w("[$trace] ⚠ No local DB restored AND not Apple demo");
      }
    } catch (e, st) {
      _log.e("[$trace] 🔥 init FAILED", error: e, stackTrace: st);
    } finally {
      _hasRestored = true;
      _log.i("[$trace] 🔚 init EXIT (_hasRestored=true)");
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // 🍎 APPLE REVIEW DEMO DB LOADER
  // ─────────────────────────────────────────────
  Future<String?> _loadAppleReviewDemoDb(String email) async {
    try {
      _log.w("🍎 Apple Review detected — starting demo DB load");

      // --------------------------------------------------
      // 1️⃣ Load asset
      // --------------------------------------------------
      _log.i("📦 Loading asset: assets/demo/demo.sqlite");
      final byteData = await rootBundle.load('assets/demo/demo.sqlite');

      _log.i(
        "📦 Asset loaded: "
        "bytes=${byteData.lengthInBytes}",
      );

      // --------------------------------------------------
      // 2️⃣ Write to temp file
      // --------------------------------------------------
      _log.i("📝 Writing demo DB to temp file...");
      final tempPath = await SqliteImportService.writeBytesToTemp(byteData);

      _log.i("📝 Demo DB written to tempPath = $tempPath");

      // --------------------------------------------------
      // 3️⃣ Validate SQLite file
      // --------------------------------------------------
      _log.i("🔍 Validating demo SQLite DB...");
      await SqliteValidationService().validateDatabase(tempPath);

      _log.i("✅ Demo DB validation PASSED");

      // --------------------------------------------------
      // 4️⃣ Activate DB for user
      // --------------------------------------------------
      _log.i("🔄 Activating demo DB for user = $email");

      await DatabaseManager.instance.useImportedDbForUser(tempPath, email);

      final activePath = DatabaseManager.instance.activeDbPath;
      _log.i("✅ Demo DB activated at: $activePath");

      // --------------------------------------------------
      // 5️⃣ Sanity check (CRITICAL)
      // --------------------------------------------------
      try {
        final tables = await SqliteImportService.getTables(activePath!);
        _log.i("📊 Demo DB tables = ${tables.join(', ')}");
      } catch (e) {
        _log.w("⚠ Could not list demo DB tables: $e");
      }

      return activePath;
    } catch (e, st) {
      _log.e("❌ Apple Review demo DB FAILED", error: e, stackTrace: st);
      return null;
    }
  } // ─────────────────────────────────────────────

  // IMPORT DATABASE (UNCHANGED)
  // ─────────────────────────────────────────────
  Future<void> importDatabase(String inputPath, UserModel user) async {
    _isImporting = true;
    notifyListeners();

    try {
      _log.i("📥 Importing SQLite DB for ${user.email}");

      final importedPath = await SqliteImportService.importAndSaveDb(inputPath);
      if (importedPath == null) {
        throw Exception("Failed to import database");
      }

      await SqliteValidationService().validateDatabase(importedPath);

      await DatabaseManager.instance.useImportedDbForUser(
        importedPath,
        user.email,
      );

      verifiedDbPath = DatabaseManager.instance.activeDbPath;
      _startDashboardStreams();

      if (syncVM != null) {
        syncVM!.attachDatabase(DatabaseManager.instance.db);
      }
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // COMPANY SELECTION (UNCHANGED)
  // ─────────────────────────────────────────────
  Future<void> _restoreCompanySelection() async {
    final prefs = await SharedPreferences.getInstance();
    final db = DatabaseManager.instance.db;
    final storedGuid = prefs.getString("selected_company_guid")?.trim();
    final storedId = prefs.getInt("selected_company_id");

    final companyRows = await db
        .customSelect(
          '''
          SELECT c.CompanyID, c.CompanyGuid, c.CompanyName, c.Remarks
          FROM Company c
          WHERE COALESCE(c.IsDeleted, 0) = 0
            AND NOT EXISTS (
              SELECT 1
              FROM Company other
              WHERE COALESCE(other.IsDeleted, 0) = 0
                AND LOWER(TRIM(COALESCE(other.CompanyName, ''))) =
                    LOWER(TRIM(COALESCE(c.CompanyName, '')))
                AND (
                  COALESCE(other.IsSynced, 0) > COALESCE(c.IsSynced, 0)
                  OR (
                    COALESCE(other.IsSynced, 0) = COALESCE(c.IsSynced, 0)
                    AND COALESCE(other.UpdatedAt, '') > COALESCE(c.UpdatedAt, '')
                  )
                  OR (
                    COALESCE(other.IsSynced, 0) = COALESCE(c.IsSynced, 0)
                    AND COALESCE(other.UpdatedAt, '') = COALESCE(c.UpdatedAt, '')
                    AND other.CompanyID < c.CompanyID
                  )
                )
            )
          ORDER BY c.CompanyID ASC
          ''',
          readsFrom: {db.companyTable},
        )
        .get();
    final companies = companyRows
        .map(
          (row) => CompanyTableData(
            companyId: _toInt(row.data['CompanyID']),
            companyGuid: row.data['CompanyGuid']?.toString(),
            companyName: row.data['CompanyName']?.toString(),
            remarks: row.data['Remarks']?.toString(),
          ),
        )
        .where((company) => company.companyId > 0)
        .toList(growable: false);

    if (companies.isEmpty) {
      selectedCompanyId = 1;
      selectedCompanyName = "Your Company";
      GlobalState.instance.setCompany(id: 1, name: selectedCompanyName!);
      return;
    }

    if (storedGuid != null && storedGuid.isNotEmpty) {
      final stored = companies.where(
        (c) => (c.companyGuid ?? '').trim() == storedGuid,
      );
      if (stored.isNotEmpty) {
        final selected = stored.first;
        selectedCompanyId = selected.companyId;
        selectedCompanyName = selected.companyName ?? "Your Company";
        await prefs.setInt("selected_company_id", selectedCompanyId!);
        GlobalState.instance.setCompany(
          id: selectedCompanyId!,
          name: selectedCompanyName!,
        );
        return;
      }
      _log.w(
        "⚠ selected_company_guid=$storedGuid not found in DB; trying legacy id",
      );
    }

    if (storedId != null) {
      final stored = companies.where((c) => c.companyId == storedId);
      if (stored.isNotEmpty) {
        final selected = stored.first;
        selectedCompanyId = selected.companyId;
        selectedCompanyName = selected.companyName ?? "Your Company";
        final selectedGuid = selected.companyGuid?.trim();
        if (selectedGuid != null && selectedGuid.isNotEmpty) {
          await prefs.setString("selected_company_guid", selectedGuid);
        }
        GlobalState.instance.setCompany(
          id: selectedCompanyId!,
          name: selectedCompanyName!,
        );
        return;
      }
      _log.w(
        "⚠ selected_company_id=$storedId not found in DB; falling back to first company",
      );
    }

    final fallback = companies.first;
    selectedCompanyId = fallback.companyId;
    selectedCompanyName = fallback.companyName ?? "Your Company";
    await prefs.setInt("selected_company_id", selectedCompanyId!);
    final fallbackGuid = fallback.companyGuid?.trim();
    if (fallbackGuid != null && fallbackGuid.isNotEmpty) {
      await prefs.setString("selected_company_guid", fallbackGuid);
    }

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
    final rawRows = await db
        .customSelect(
          '''
          SELECT CompanyID, CompanyGuid, CompanyName, Remarks
          FROM Company
          WHERE CompanyID = ?1
            AND COALESCE(IsDeleted, 0) = 0
          LIMIT 1
          ''',
          variables: [Variable.withInt(id)],
          readsFrom: {db.companyTable},
        )
        .get();
    final rows = rawRows
        .map(
          (row) => CompanyTableData(
            companyId: _toInt(row.data['CompanyID']),
            companyGuid: row.data['CompanyGuid']?.toString(),
            companyName: row.data['CompanyName']?.toString(),
            remarks: row.data['Remarks']?.toString(),
          ),
        )
        .where((company) => company.companyId > 0)
        .toList(growable: false);

    selectedCompanyName = rows.isNotEmpty
        ? rows.first.companyName
        : "Your Company";
    final selectedGuid = rows.isNotEmpty
        ? rows.first.companyGuid?.trim()
        : null;
    if (selectedGuid != null && selectedGuid.isNotEmpty) {
      await prefs.setString("selected_company_guid", selectedGuid);
    }

    GlobalState.instance.setCompany(id: id, name: selectedCompanyName!);

    _startDashboardStreams();
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // DASHBOARD STREAMS (UNCHANGED)
  // ─────────────────────────────────────────────
  void _startDashboardStreams() {
    if (selectedCompanyId == null) return;

    final repo = AccountRepository(DatabaseManager.instance.db);

    _cashInHandSub?.cancel();
    _acc1CashSub?.cancel();
    _pendingSub?.cancel();

    _cashInHandSub = repo.watchCashInHandSummary(selectedCompanyId!).listen((
      rows,
    ) {
      cashInHandSummary = rows;
      notifyListeners();
    });

    _acc1CashSub = repo.watchAcc1CashSummary(selectedCompanyId!).listen((rows) {
      acc1CashSummary = rows;
      notifyListeners();
    });

    _pendingSub = repo.watchPendingAmountSummary(selectedCompanyId!).listen((
      rows,
    ) {
      pendingAmounts = rows;
      notifyListeners();
    });
  }

  // ─────────────────────────────────────────────
  // LOGOUT CLEANUP (UNCHANGED)
  // ─────────────────────────────────────────────
  Future<void> clearOnLogout(UserModel user) async {
    _cashInHandSub?.cancel();
    _acc1CashSub?.cancel();
    _pendingSub?.cancel();

    verifiedDbPath = null;
    selectedCompanyId = null;
    selectedCompanyName = null;

    pendingAmounts.clear();
    cashInHandSummary.clear();
    acc1CashSummary.clear();

    _hasRestored = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("selected_company_id");
    await prefs.remove("selected_company_guid");

    await DatabaseManager.instance.clearUserDb(user.email);

    GlobalState.instance.setCompany(id: 1, name: "Your Company");

    notifyListeners();
  }

  @override
  void dispose() {
    _cashInHandSub?.cancel();
    _acc1CashSub?.cancel();
    _pendingSub?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // CONFIRM & IMPORT (UNCHANGED)
  // ─────────────────────────────────────────────
  Future<void> confirmAndImportDatabase({
    required BuildContext context,
    required String inputPath,
    required UserModel user,
  }) async {
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
