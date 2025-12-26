import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../repository/transactions_repository.dart';
import '../../model/last_credit_row.dart';
import '../../model/balance_matrix_result.dart';
import '../../services/pdf/last_credit_pdf_service.dart';

class LastCreditViewModel extends ChangeNotifier {
  final TransactionsRepository repo;
  final int companyId; // 🔥 COMPANY CONTEXT

  LastCreditViewModel({
    required this.repo,
    required this.companyId,
  });

  bool isLoading = false;
  String? error;

  /// Currency names (AccTypeName)
  List<String> currencies = [];

  // ----------------------------------------------------------
  // Load currencies (company-scoped)
  // ----------------------------------------------------------
  Future<void> loadCurrencies() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final BalanceMatrixResult matrix =
      await repo.getBalanceMatrix(companyId: companyId);

      currencies = matrix.currencies;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ----------------------------------------------------------
  // Resolve AccTypeID (currency) — ✅ CORRECT
  // ----------------------------------------------------------
  Future<int?> _resolveAccTypeId(String currencyName) {
    return repo.resolveAccTypeIdByName(
      companyId: companyId,
      currencyName: currencyName,
    );
  }

  // ----------------------------------------------------------
  // Load last-credit rows (company-scoped)
  // ----------------------------------------------------------
  Future<List<LastCreditRow>> _loadRows(int currencyId) {
    return repo.getLastCreditSummary(
      companyId: companyId,
      currencyId: currencyId,
    );
  }

  // ----------------------------------------------------------
  // PUBLIC: Generate PDF for selected currency
  // ----------------------------------------------------------
  Future<File?> generatePdf({
    required String currencyName,
  }) async {
    try {
      final id = await _resolveAccTypeId(currencyName);
      if (id == null) {
        throw Exception('Currency not found in AccType table');
      }

      final rows = await _loadRows(id);
      if (rows.isEmpty) return null;

      final file = await LastCreditPdfService.instance.render(
        currencyName: currencyName,
        rows: rows,
      );

      return file;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}