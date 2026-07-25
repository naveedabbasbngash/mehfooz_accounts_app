// lib/viewmodel/profile/profile_view_model.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:mehfooz_accounts_app/ui/auth/auth_screen.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/app_database.dart';
import '../../data/local/database_manager.dart';
import '../../model/user_model.dart';
import '../../services/company_tombstone_store.dart';
import '../../services/global_state.dart';
import '../../utils/ulid.dart';
import '../home/home_view_model.dart';
import '../sync/sync_viewmodel.dart';
import 'package:http/http.dart' as http;

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({required this.loggedInUser}) {
    _init();
  }

  // ─────────────────────────────────────────────────────────────
  // CORE STATE
  // ─────────────────────────────────────────────────────────────
  bool isLoading = true;

  // 🍎 Apple App Review account
  static const String _appleReviewEmail = 'applereviewmehfooz@gmail.com';

  late UserModel loggedInUser;

  /// 🔑 Admin permission from backend
  bool get isAdminSyncAllowed => loggedInUser.planStatus?.canSync ?? false;

  // Company selection
  List<CompanyTableData> companies = [];
  CompanyTableData? selectedCompany;
  bool isExportingDatabase = false;

  // Db_Info values
  String? dbEmail;
  String? dbName;
  bool emailMatch = false;

  /// True if a per-user database exists on disk and was restored
  bool databaseFound = false;

  /// When true, ONLY Profile tab is allowed (HomeWrapper checks this)
  bool isRestricted = false;

  // ─────────────────────────────────────────────────────────────
  // DERIVED GETTERS
  // ─────────────────────────────────────────────────────────────

  /// ⭐ REQUIRED BY HomeWrapper
  int get remainingDays {
    final expiry = loggedInUser.expiry;
    if (expiry == null) return 0;
    return expiry.remainingDays;
  }

  /// True when subscription is finished (expired or 0 days)
  bool get isSubscriptionExpired {
    final expiry = loggedInUser.expiry;

    // 🆓 FREE plan NEVER expires
    if (isFreePlan) {
      debugPrint("🟢 [SUBSCRIPTION] FREE plan → never expired");
      return false;
    }

    if (expiry == null) return false;

    final expired = expiry.isExpired == true || expiry.remainingDays <= 0;

    debugPrint(
      "🟡 [SUBSCRIPTION] PAID plan | "
      "remainingDays=${expiry.remainingDays} | expired=$expired",
    );

    return expired;
  }

  /// Can we safely use this DB?
  bool get canUseDatabase => databaseFound && !isSubscriptionExpired;

  /// Can user toggle restrictions manually?
  bool get canToggleRestriction => canUseDatabase;

  /// Sync allowed?
  bool get canSync =>
      isAdminSyncAllowed && databaseFound && !isSubscriptionExpired;

  /// Import allowed? (blocked only when subscription expired)
  bool get canImport => !isSubscriptionExpired;

  // ─────────────────────────────────────────────────────────────
  // INIT / REFRESH
  // ─────────────────────────────────────────────────────────────

  Future<void> _init() async {
    isLoading = true;
    notifyListeners();

    try {
      final dbManager = DatabaseManager.instance;
      final prefs = await SharedPreferences.getInstance();

      // Reset VM state
      companies = [];
      selectedCompany = null;
      dbEmail = null;
      dbName = null;
      emailMatch = false;
      databaseFound = false;

      // 1️⃣ Restore database from disk
      // 🔒 If DB is already active for this user, DO NOT restore again
      if (DatabaseManager.instance.activeDbPath != null &&
          DatabaseManager.instance.activeUserEmail == loggedInUser.email) {
        databaseFound = true;
      } else {
        final hasDb = await dbManager.restoreDatabaseForUser(
          loggedInUser.email,
        );
        databaseFound = hasDb;
      }

      final db = dbManager.db;

      // 2️⃣ Load companies
      await _loadCompanies();

      // Restore selected company
      final storedGuid = prefs.getString("selected_company_guid")?.trim();
      final storedId = prefs.getInt("selected_company_id");
      if (storedGuid != null && storedGuid.isNotEmpty && companies.isNotEmpty) {
        try {
          selectedCompany = companies.firstWhere(
            (c) => (c.companyGuid ?? '').trim() == storedGuid,
          );

          GlobalState.instance.setCompany(
            id: selectedCompany!.companyId,
            name: selectedCompany!.companyName ?? "Your Company",
          );
        } catch (_) {
          selectedCompany = null;
        }
      }
      if (selectedCompany == null && storedId != null && companies.isNotEmpty) {
        try {
          selectedCompany = companies.firstWhere(
            (c) => c.companyId == storedId,
          );

          GlobalState.instance.setCompany(
            id: selectedCompany!.companyId,
            name: selectedCompany!.companyName ?? "Your Company",
          );
        } catch (_) {
          selectedCompany = null;
        }
      }

      // Default to first company
      if (selectedCompany == null && companies.isNotEmpty) {
        selectedCompany = companies.first;

        await prefs.setInt("selected_company_id", selectedCompany!.companyId);
        final companyGuid = selectedCompany!.companyGuid?.trim();
        if (companyGuid != null && companyGuid.isNotEmpty) {
          await prefs.setString("selected_company_guid", companyGuid);
        }

        GlobalState.instance.setCompany(
          id: selectedCompany!.companyId,
          name: selectedCompany!.companyName ?? "Your Company",
        );
      }

      // 3️⃣ Load Db_Info
      final info = await db.select(db.dbInfoTable).get();
      if (info.isNotEmpty) {
        dbEmail = info.first.emailAddress;
        dbName = info.first.databaseName;
      }

      // 4️⃣ Check email match
      emailMatch =
          dbEmail != null &&
          dbEmail!.trim().toLowerCase() ==
              loggedInUser.email.trim().toLowerCase();

      // 5️⃣ Restriction engine
      if (isAppleReviewUser) {
        debugPrint("🍎 [RESTRICTION] Apple Review user → unrestricted");
        isRestricted = false;
      } else if (!databaseFound) {
        debugPrint("🔴 [RESTRICTION:init] No local database → restricted");
        isRestricted = true;
      } else if (isSubscriptionExpired) {
        debugPrint("🔴 [RESTRICTION:init] Paid plan expired → restricted");
        isRestricted = true;
      } else {
        if (!emailMatch) {
          debugPrint(
            "🟡 [RESTRICTION:init] Email mismatch allowed for team member access",
          );
        }
        debugPrint("🟢 [RESTRICTION:init] Allowed (FREE or active paid plan)");
        isRestricted = false;
      }
    } catch (e, st) {
      debugPrint("❌ Error in ProfileViewModel._init: $e");
      debugPrintStack(stackTrace: st);
      isRestricted = true;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Public — called after import or sync
  Future<void> refresh() async {
    await _init();
  }

  // ─────────────────────────────────────────────────────────────
  // COMPANY SELECTOR
  // ─────────────────────────────────────────────────────────────
  Future<void> _loadCompanies() async {
    final db = DatabaseManager.instance.db;
    final rows = await db
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
    companies = rows
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
    final snapshot = companies
        .map((c) => '${c.companyId}:${c.companyName ?? '(null)'}')
        .join(', ');
    debugPrint(
      "🏢 [COMPANY_DEBUG] _loadCompanies total=${companies.length} rows=[$snapshot]",
    );
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<bool> _companyNameExists(String name, {int? excludeCompanyId}) async {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    final db = DatabaseManager.instance.db;
    if (excludeCompanyId == null) {
      final rows = await db
          .customSelect(
            '''
	        SELECT 1
	        FROM Company
	        WHERE COALESCE(IsDeleted, 0) = 0
            AND LOWER(TRIM(COALESCE(CompanyName, ''))) = ?1
	        LIMIT 1
	        ''',
            variables: [Variable.withString(normalized)],
          )
          .get();
      return rows.isNotEmpty;
    }

    final rows = await db
        .customSelect(
          '''
      SELECT 1
	      FROM Company
	      WHERE CompanyID <> ?1
	        AND COALESCE(IsDeleted, 0) = 0
	        AND LOWER(TRIM(COALESCE(CompanyName, ''))) = ?2
	      LIMIT 1
      ''',
          variables: [
            Variable.withInt(excludeCompanyId),
            Variable.withString(normalized),
          ],
        )
        .get();
    return rows.isNotEmpty;
  }

  Future<void> selectCompany(int id, {required BuildContext context}) async {
    try {
      selectedCompany = companies.firstWhere((c) => c.companyId == id);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt("selected_company_id", id);
      final companyGuid = selectedCompany!.companyGuid?.trim();
      if (companyGuid != null && companyGuid.isNotEmpty) {
        await prefs.setString("selected_company_guid", companyGuid);
      }

      GlobalState.instance.setCompany(
        id: selectedCompany!.companyId,
        name: selectedCompany!.companyName ?? "Your Company",
      );

      if (!context.mounted) return;
      final homeVM = context.read<HomeViewModel>();
      await homeVM.setCompany(id);

      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error selecting company: $e");
    }
  }

  Future<void> _syncCompaniesNow(BuildContext context) async {
    try {
      if (!context.mounted) return;
      debugPrint(
        "🏢 [COMPANY_DEBUG] trigger sync selected=${selectedCompany?.companyId}:${selectedCompany?.companyName}",
      );
      await context.read<SyncViewModel>().syncNowIfNeededSingleFlight(
        force: true,
        silent: true,
      );
    } catch (e, st) {
      debugPrint("⚠️ Company sync trigger failed: $e");
      debugPrintStack(stackTrace: st);
    }
  }

  Future<String?> addCompany({
    required BuildContext context,
    required String name,
    String? remarks,
  }) async {
    final cleanName = name.trim();
    final cleanRemarks = remarks?.trim();

    if (cleanName.isEmpty) return "Company name is required.";
    if (await _companyNameExists(cleanName)) {
      return "Company name already exists.";
    }
    if (companies.length >= 2) {
      return "You already have 2 companies. New companies cannot be added.";
    }

    final db = DatabaseManager.instance.db;
    try {
      debugPrint(
        "🏢 [COMPANY_DEBUG] addCompany start name=$cleanName remarks=${cleanRemarks ?? '(null)'}",
      );
      await db.customStatement(
        '''
	        INSERT INTO Company
	          (CompanyGuid, CompanyName, Remarks, IsDeleted, IsSynced, UpdatedAt)
	        VALUES (?1, ?2, ?3, 0, 0, ?4);
	        ''',
        [
          Ulid.generate(),
          cleanName,
          (cleanRemarks?.isEmpty ?? true) ? null : cleanRemarks,
          DateTime.now().toUtc().toIso8601String(),
        ],
      );

      final idRow = await db
          .customSelect('SELECT last_insert_rowid() AS id;')
          .getSingle();
      final newCompanyId = _toInt(idRow.data['id']);
      if (newCompanyId <= 0) {
        return "Failed to create company.";
      }
      await CompanyTombstoneStore.clear(
        companyId: newCompanyId,
        companyName: cleanName,
      );
      debugPrint(
        "🏢 [COMPANY_DEBUG] addCompany inserted companyId=$newCompanyId name=$cleanName",
      );

      await DatabaseManager.instance.seedDefaultsForCompany(newCompanyId);
      await _loadCompanies();
      if (!context.mounted) return null;
      await selectCompany(newCompanyId, context: context);
      if (!context.mounted) return null;
      await _syncCompaniesNow(context);
      return null;
    } catch (e) {
      return "Failed to add company: $e";
    }
  }

  Future<String?> updateCompany({
    required BuildContext context,
    required int companyId,
    required String name,
    String? remarks,
  }) async {
    final cleanName = name.trim();
    final cleanRemarks = remarks?.trim();

    if (cleanName.isEmpty) return "Company name is required.";
    if (await _companyNameExists(cleanName, excludeCompanyId: companyId)) {
      return "Company name already exists.";
    }

    final db = DatabaseManager.instance.db;
    try {
      await db.customStatement(
        '''
	        UPDATE Company
	        SET CompanyName = ?1,
	            Remarks = ?2,
	            IsSynced = 0,
	            UpdatedAt = ?3
	        WHERE CompanyID = ?4
	        ''',
        [
          cleanName,
          (cleanRemarks?.isEmpty ?? true) ? null : cleanRemarks,
          DateTime.now().toUtc().toIso8601String(),
          companyId,
        ],
      );
      await CompanyTombstoneStore.clear(
        companyId: companyId,
        companyName: cleanName,
      );

      await _loadCompanies();
      if (selectedCompany?.companyId == companyId) {
        if (!context.mounted) return null;
        await selectCompany(companyId, context: context);
      } else {
        notifyListeners();
      }
      if (!context.mounted) return null;
      await _syncCompaniesNow(context);
      return null;
    } catch (e) {
      return "Failed to update company: $e";
    }
  }

  Future<String?> deleteCompany({
    required BuildContext context,
    required int companyId,
  }) async {
    final db = DatabaseManager.instance.db;
    try {
      await db.transaction(() async {
        await db.customStatement(
          'DELETE FROM AccountCurrencyMap WHERE CompanyID = ?1;',
          [companyId],
        );
        await db.customStatement(
          'DELETE FROM Transactions_P WHERE CompanyID = ?1;',
          [companyId],
        );
        await db.customStatement(
          'DELETE FROM Acc_Personal WHERE CompanyID = ?1;',
          [companyId],
        );
        await db.customStatement('DELETE FROM Company WHERE CompanyID = ?1;', [
          companyId,
        ]);
      });
      final deletedCompany = companies.where((c) => c.companyId == companyId);
      await CompanyTombstoneStore.markDeleted(
        companyId: companyId,
        companyName: deletedCompany.isEmpty
            ? null
            : deletedCompany.first.companyName,
      );

      await _loadCompanies();
      if (companies.isEmpty) {
        final fallbackId = await DatabaseManager.instance
            .ensureDefaultCompanyForActiveDb();
        await DatabaseManager.instance.seedDefaultsForCompany(fallbackId);
        await _loadCompanies();
      }

      final prefs = await SharedPreferences.getInstance();
      final storedId = prefs.getInt("selected_company_id");
      final nextId =
          (storedId != null && companies.any((c) => c.companyId == storedId))
          ? storedId
          : companies.first.companyId;

      if (!context.mounted) return null;
      await selectCompany(nextId, context: context);
      if (!context.mounted) return null;
      await _syncCompaniesNow(context);
      return null;
    } catch (e) {
      return "Failed to delete company: $e";
    }
  }

  // ─────────────────────────────────────────────────────────────
  // RESTRICTION TOGGLE
  // ─────────────────────────────────────────────────────────────
  Future<void> toggleRestriction() async {
    if (!canToggleRestriction) return;

    isRestricted = !isRestricted;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("profile_is_restricted", isRestricted);
    } catch (e) {
      debugPrint("❌ Error saving restriction flag: $e");
    }

    notifyListeners();
  }

  Future<void> onLocalDatabaseImported() async {
    debugPrint("🟡 [IMPORT] onLocalDatabaseImported() called");

    isLoading = true;
    notifyListeners();

    try {
      final db = DatabaseManager.instance.db;

      // 🔑 CRITICAL FLAG
      databaseFound = true;

      debugPrint("🟢 [IMPORT] databaseFound = $databaseFound");

      // Reload Db_Info
      final info = await db.select(db.dbInfoTable).get();

      if (info.isNotEmpty) {
        dbEmail = info.first.emailAddress;
        dbName = info.first.databaseName;
      }

      debugPrint("🟢 [IMPORT] dbEmail from DB = $dbEmail");
      debugPrint("🟢 [IMPORT] loggedInUser.email = ${loggedInUser.email}");

      emailMatch =
          dbEmail != null &&
          dbEmail!.trim().toLowerCase() ==
              loggedInUser.email.trim().toLowerCase();

      debugPrint("🟢 [IMPORT] emailMatch = $emailMatch");
      debugPrint("🟢 [IMPORT] isSubscriptionExpired = $isSubscriptionExpired");

      // FINAL DECISION
      if (isAppleReviewUser) {
        debugPrint("🍎 [IMPORT] Apple Review user → unrestricted");
        isRestricted = false;
      } else if (!databaseFound) {
        isRestricted = true;
      } else if (isSubscriptionExpired) {
        isRestricted = true;
      } else {
        if (!emailMatch) {
          debugPrint(
            "🟡 [IMPORT] Email mismatch allowed for team member access",
          );
        }
        isRestricted = false;
      }

      debugPrint("🔴 [IMPORT] FINAL isRestricted = $isRestricted");
    } catch (e, st) {
      debugPrint("❌ [IMPORT] ERROR: $e");
      debugPrintStack(stackTrace: st);
      isRestricted = true;
    } finally {
      isLoading = false;
      notifyListeners();
      debugPrint("✅ [IMPORT] onLocalDatabaseImported() finished");
    }
  }

  /// 🆓 Detect FREE plan
  bool get isFreePlan {
    final text = loggedInUser.planStatus?.statusText.toLowerCase() ?? "";
    return text.contains("free");
  }

  /// 💰 Paid plan = not free
  bool get isPaidPlan => !isFreePlan;

  // 🍎 Detect Apple Review user
  bool get isAppleReviewUser =>
      loggedInUser.email.trim().toLowerCase() == _appleReviewEmail;

  Future<void> deleteAccount(BuildContext context) async {
    final email = loggedInUser.email;

    try {
      isLoading = true;
      notifyListeners();

      debugPrint("🧨 [DELETE] Starting delete account flow");
      debugPrint("🧨 [DELETE] Email = $email");
      debugPrint(
        "🧨 [DELETE] API = https://admin.mahfoozaccounts.com/api/deleteAccount",
      );

      final uri = Uri.parse(
        "https://admin.mahfoozaccounts.com/api/deleteAccount",
      );

      final response = await http.post(
        uri,
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: {"email": email},
      );

      // 🔍 LOG EVERYTHING
      debugPrint("🧨 [DELETE] Status code = ${response.statusCode}");
      debugPrint("🧨 [DELETE] Response headers = ${response.headers}");
      debugPrint("🧨 [DELETE] Raw response body = ${response.body}");

      if (response.statusCode == 200) {
        debugPrint("✅ [DELETE] Server accepted delete request");

        // Optional: parse body if JSON
        if (response.body.isNotEmpty) {
          debugPrint("📦 [DELETE] Server message = ${response.body}");
        }

        // 🧹 Clear local data
        await DatabaseManager.instance.clearAllForUser(email);
        debugPrint("🧹 [DELETE] Local DB cleared");

        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthScreen()),
            (_) => false,
          );
        }
      } else {
        // ❌ Server responded but not OK
        throw Exception(
          "Delete API failed | "
          "status=${response.statusCode} | "
          "body=${response.body}",
        );
      }
    } catch (e, st) {
      debugPrint("❌ [DELETE] ERROR: $e");
      debugPrintStack(stackTrace: st);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Account deletion failed. Please try again."),
        ),
      );
    } finally {
      isLoading = false;
      notifyListeners();
      debugPrint("🏁 [DELETE] Flow finished");
    }
  }

  Future<String?> exportAndShareDatabase() async {
    if (isExportingDatabase) return "Database export is already in progress.";

    isExportingDatabase = true;
    notifyListeners();

    try {
      final dbManager = DatabaseManager.instance;
      var sourcePath = dbManager.activeDbPath;

      if (sourcePath == null || sourcePath.trim().isEmpty) {
        await dbManager.restoreDatabaseForUser(loggedInUser.email);
        sourcePath = dbManager.activeDbPath;
      }

      if (sourcePath == null || sourcePath.trim().isEmpty) {
        return "No active database found to export.";
      }

      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return "Database file not found on device.";
      }

      try {
        await dbManager.db.customStatement('PRAGMA wal_checkpoint(FULL);');
      } catch (_) {}

      final tmpDir = await Directory.systemTemp.createTemp('mahfooz_export_');
      final now = DateTime.now();
      final stamp =
          '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final safeUser = loggedInUser.email
          .split('@')
          .first
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final exportPath =
          '${tmpDir.path}/mahfooz_backup_${safeUser}_$stamp.sqlite';

      final exportedFile = await sourceFile.copy(exportPath);
      const title = 'Mahfooz Database Backup';
      await Share.shareXFiles(
        [XFile(exportedFile.path)],
        text: title,
        subject: title,
      );

      return null;
    } catch (e) {
      return "Failed to export database: $e";
    } finally {
      isExportingDatabase = false;
      notifyListeners();
    }
  }
}
