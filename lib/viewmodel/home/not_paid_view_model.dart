import 'package:flutter/material.dart';
import '../../model/pending_currency_summary.dart';
import '../../data/local/database_manager.dart';
import '../../repository/transactions_repository.dart';
import '../../model/pending_group_row.dart';
import '../../model/pending_status_summary.dart';

class NotPaidViewModel extends ChangeNotifier {
  TransactionsRepository? _repository;
  TransactionsRepository get repository =>
      _repository ??= TransactionsRepository(DatabaseManager.instance.db);

  int accId;        // required (same as Kotlin)
  int companyId;    // 🔥 NEW: dynamic company filter
  final String? currencyFilter;
  String statusFilter = "NOTPAID";

  List<PendingGroupRow> rows = [];
  PendingStatusSummary summary = PendingStatusSummary.empty;
  List<PendingCurrencySummary> currencySummaries = const [];
  bool isLoading = true;
  String? errorMessage;

  NotPaidViewModel({
    required this.accId,
    required this.companyId,  // 🔥 keep companyId in the ViewModel
    this.currencyFilter,
  });

  Future<void> loadRows({String? status}) async {
    if (status != null && status.trim().isNotEmpty) {
      statusFilter = status.trim().toUpperCase();
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final rowsFuture =
          (currencyFilter != null && currencyFilter!.trim().isNotEmpty)
          ? repository.getPendingByCurrencyClick(
              companyId: companyId,
              currency: currencyFilter!.trim(),
              statusFilter: statusFilter,
            )
          : repository.getPendingGroups(
              accId: accId,
              companyId: companyId,
              statusFilter: statusFilter,
            );

      final summaryFuture = repository.getPendingStatusSummary(
        accId: accId,
        companyId: companyId,
        currency: currencyFilter?.trim(),
      );

      final currencySummaryFuture =
          (currencyFilter == null || currencyFilter!.trim().isEmpty)
          ? repository.getPendingStatusSummaryByCurrency(
              accId: accId,
              companyId: companyId,
            )
          : Future.value(const <PendingCurrencySummary>[]);

      final results = await Future.wait<Object>([
        rowsFuture,
        summaryFuture,
        currencySummaryFuture,
      ]);

      rows = results[0] as List<PendingGroupRow>;
      summary = results[1] as PendingStatusSummary;
      currencySummaries = results[2] as List<PendingCurrencySummary>;
    } catch (e) {
      errorMessage = e.toString();
      rows = [];
      summary = PendingStatusSummary.empty;
      currencySummaries = const [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // 🔥 Call this when company changes from Home or Settings
  void updateCompany(int newCompanyId) {
    companyId = newCompanyId;
    loadRows(); // auto refresh data
  }

  List<T> smartFilter<T>({
    required List<T> rows,
    required String query,
    required String Function(T item) fieldGetter,
  }) {
    if (query.trim().isEmpty) return rows;

    final q = query.trim();

    // Detect numeric or text
    final isNumeric = double.tryParse(q) != null;

    return rows.where((item) {
      final value = fieldGetter(item).trim();

      if (isNumeric) {
        // Numeric → EXACT MATCH
        return value == q;
      } else {
        // Text → PREFIX MATCH
        return value.toLowerCase().startsWith(q.toLowerCase());
      }
    }).toList();
  }
}
