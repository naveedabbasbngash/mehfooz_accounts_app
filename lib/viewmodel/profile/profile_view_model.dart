import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/app_database.dart';
import '../../data/local/database_manager.dart';
import '../../model/user_model.dart';
import '../home/home_view_model.dart';

class ProfileViewModel extends ChangeNotifier {
  bool isLoading = true;

  late UserModel loggedInUser;

  List<CompanyTableData> companies = [];
  CompanyTableData? selectedCompany;

  String? dbEmail;

  ProfileViewModel({required this.loggedInUser}) {
    _init();
  }

  Future<void> _init() async {
    isLoading = true;
    notifyListeners();

    final db = DatabaseManager.instance.db;
    final prefs = await SharedPreferences.getInstance();

    // 1) Load all companies
    companies = await db.select(db.companyTable).get();

    // 2) Restore selected company
    final storedId = prefs.getInt("selected_company_id");

    if (storedId != null) {
      try {
        selectedCompany =
            companies.firstWhere((c) => c.companyId == storedId);
      } catch (_) {
        selectedCompany = null;
      }
    }

    // 3) Load Db_Info email
    final info = await db.select(db.dbInfoTable).get();
    if (info.isNotEmpty) {
      dbEmail = info.first.emailAddress;
    }

    isLoading = false;
    notifyListeners();
  }

  // =========================================================
  // SELECT COMPANY → Save + Update HomeViewModel
  // =========================================================
  Future<void> selectCompany(int? id, {required BuildContext context}) async {
    if (id == null) return;

    try {
      selectedCompany =
          companies.firstWhere((c) => c.companyId == id);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt("selected_company_id", id);

      // 🔥 Notify HOME VIEWMODEL about new company
      final homeVM = context.read<HomeViewModel>();
      homeVM.selectCompany(id);

      notifyListeners();
    } catch (_) {}
  }
}