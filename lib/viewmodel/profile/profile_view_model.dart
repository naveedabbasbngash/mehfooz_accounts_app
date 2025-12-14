// lib/viewmodel/profile/profile_view_model.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/app_database.dart';
import '../../data/local/database_manager.dart';
import '../../model/user_model.dart';
import '../../services/global_state.dart';
import '../home/home_view_model.dart';

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({required this.loggedInUser}) {
    _init();
  }

  // ─────────────────────────────────────────────────────────────
  // CORE STATE
  // ─────────────────────────────────────────────────────────────
  bool isLoading = true;

  late UserModel loggedInUser;

  // Company selection
  List<CompanyTableData> companies = [];
  CompanyTableData? selectedCompany;

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
    if (expiry == null) return false;
    return expiry.isExpired == true || expiry.remainingDays <= 0;
  }

  /// Can we safely use this DB?
  bool get canUseDatabase =>
      databaseFound && emailMatch && !isSubscriptionExpired;

  /// Can user toggle restrictions manually?
  bool get canToggleRestriction => canUseDatabase;

  /// Sync allowed?
  bool get canSync => databaseFound && emailMatch && !isSubscriptionExpired;

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
      final hasDb = await dbManager.restoreDatabaseForUser(loggedInUser.email);
      databaseFound = hasDb;

      if (!hasDb) {
        // Force restriction since there's no DB
        isRestricted = true;
        return;
      }

      final db = dbManager.db;

      // 2️⃣ Load companies
      companies = await db.select(db.companyTable).get();

      // Restore selected company
      final storedId = prefs.getInt("selected_company_id");
      if (storedId != null && companies.isNotEmpty) {
        try {
          selectedCompany =
              companies.firstWhere((c) => c.companyId == storedId);

          GlobalState.instance.setCompany(
            id: selectedCompany!.companyId!,
            name: selectedCompany!.companyName ?? "Your Company",
          );
        } catch (_) {
          selectedCompany = null;
        }
      }

      // Default to first company
      if (selectedCompany == null && companies.isNotEmpty) {
        selectedCompany = companies.first;

        await prefs.setInt("selected_company_id", selectedCompany!.companyId!);

        GlobalState.instance.setCompany(
          id: selectedCompany!.companyId!,
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
      emailMatch = dbEmail != null &&
          dbEmail!.trim().toLowerCase() ==
              loggedInUser.email.trim().toLowerCase();

      // 5️⃣ Restriction engine
      if (isSubscriptionExpired || !emailMatch) {
        isRestricted = true;
      } else {
        isRestricted = prefs.getBool("profile_is_restricted") ?? false;
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
  Future<void> selectCompany(int id, {required BuildContext context}) async {
    try {
      selectedCompany = companies.firstWhere((c) => c.companyId == id);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt("selected_company_id", id);

      GlobalState.instance.setCompany(
        id: selectedCompany!.companyId!,
        name: selectedCompany!.companyName ?? "Your Company",
      );

      final homeVM = context.read<HomeViewModel>();
      await homeVM.setCompany(id);

      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error selecting company: $e");
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
}