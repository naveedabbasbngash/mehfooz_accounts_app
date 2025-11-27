import 'package:flutter/material.dart';
import '../../repository/transactions_repository.dart';
import '../../model/pending_group_row.dart';

class NotPaidViewModel extends ChangeNotifier {
  final TransactionsRepository repository;

  int accId;        // required (same as Kotlin)
  int companyId;    // 🔥 NEW: dynamic company filter
  bool showAll = false;

  List<PendingGroupRow> rows = [];

  NotPaidViewModel({
    required this.repository,
    required this.accId,
    required this.companyId,  // 🔥 keep companyId in the ViewModel
  });

  Future<void> loadRows() async {
    rows = await repository.getPendingGroups(
      accId: accId,
      companyId: companyId,   // 🔥 pass companyId dynamically
      showAll: showAll,
    );
    notifyListeners();
  }

  void toggleShowAll(bool value) {
    showAll = value;
    loadRows();
  }

  // 🔥 Call this when company changes from Home or Settings
  void updateCompany(int newCompanyId) {
    companyId = newCompanyId;
    loadRows(); // auto refresh data
  }
}