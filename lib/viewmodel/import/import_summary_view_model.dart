// lib/viewmodel/import/import_summary_view_model.dart

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/app_database.dart';
import '../../data/local/database_manager.dart';
import '../../services/sqlite_import_service.dart';
import '../../services/sqlite_validation_service.dart';

import '../../model/user_model.dart';

class ImportSummaryViewModel extends ChangeNotifier {
  final Logger _log = Logger();

  final String filePath;   // Path of shared/imported DB
  final UserModel user;    // Logged-in user (email needed)

  // UI State
  bool isLoading = true;

  List<String> tables = [];
  List<CompanyTableData> companies = [];
  CompanyTableData? selectedCompany;

  String? dbEmail;
  String? dbName;

  bool emailMatch = false;

  ImportSummaryViewModel({
    required this.filePath,
    required this.user,
  }) {
    loadAll();
  }

  // ===========================================================================
  // MAIN LOADER — now using PER-USER DATABASE
  // ===========================================================================
  Future<void> loadAll() async {
    try {
      isLoading = true;
      notifyListeners();

      // 1️⃣ Validate structure BEFORE saving internally
      await SqliteValidationService().validateDatabase(filePath);

      // 2️⃣ Save imported DB into this user's private DB slot + activate it
      await DatabaseManager.instance.useImportedDbForUser(filePath, user.email);

      final db = DatabaseManager.instance.db;

      // 3️⃣ Load Db_Info (email + database name)
      final info = await db.select(db.dbInfoTable).get();
      dbEmail = info.isNotEmpty ? info.first.emailAddress : null;
      dbName  = info.isNotEmpty ? info.first.databaseName : null;

      // Check email match
      emailMatch = (dbEmail?.trim().toLowerCase() ==
          user.email.trim().toLowerCase());

      // 4️⃣ Load companies from user's DB
      companies = await db.select(db.companyTable).get();

      // Restore last selected company from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final storedId = prefs.getInt("selected_company_id");

      if (storedId != null) {
        try {
          selectedCompany = companies.firstWhere((c) => c.companyId == storedId);
        } catch (_) {}
      }

      // Default if none
      selectedCompany ??=
      companies.isNotEmpty ? companies.first : null;

      // 5️⃣ Load table list (using original file, not internal copy)
      tables = await SqliteImportService.getTables(filePath);
    } catch (e, st) {
      _log.e("❌ ImportSummary load error", error: e, stackTrace: st);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ===========================================================================
  // COMPANY SELECTOR
  // ===========================================================================
  Future<void> selectCompany(int id) async {
    selectedCompany = companies.firstWhere((c) => c.companyId == id);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("selected_company_id", id);

    notifyListeners();
  }
}