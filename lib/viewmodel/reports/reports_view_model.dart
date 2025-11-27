import 'dart:io';
import 'package:flutter/material.dart';

import '../../repository/transactions_repository.dart';
import '../../model/balance_row.dart';
import '../../model/balance_matrix_result.dart';
import '../../services/pdf/report_pdf_service.dart';

class ReportsUiState {
  final bool loading;
  final String? error;

  final List<String> currencies;
  final List<BalanceRow> rows;        // ⬅ REAL rows used by Kotlin
  final List<dynamic> pendingRows;    // ⬅ will fill later

  const ReportsUiState({
    this.loading = false,
    this.error,
    this.currencies = const [],
    this.rows = const [],
    this.pendingRows = const [],
  });

  ReportsUiState copyWith({
    bool? loading,
    String? error,
    List<String>? currencies,
    List<BalanceRow>? rows,
    List<dynamic>? pendingRows,
  }) {
    return ReportsUiState(
      loading: loading ?? this.loading,
      error: error,
      currencies: currencies ?? this.currencies,
      rows: rows ?? this.rows,
      pendingRows: pendingRows ?? this.pendingRows,
    );
  }
}

class ReportsViewModel extends ChangeNotifier {
  final TransactionsRepository repo;

  ReportsUiState _ui = const ReportsUiState(loading: true);
  ReportsUiState get ui => _ui;

  ReportsViewModel({required this.repo});

  // ----------------------------------------------------------------------
  // LOAD BALANCE MATRIX (Flutter equivalent of Kotlin queryBalancePivot)
  // ----------------------------------------------------------------------
  Future<void> loadBalanceMatrix() async {
    try {
      _ui = _ui.copyWith(loading: true, error: null);
      notifyListeners();

      // 🔥 EXACT Kotlin logic we ported
      BalanceMatrixResult result = await repo.getBalanceMatrix();

      _ui = _ui.copyWith(
        loading: false,
        currencies: result.currencies,
        rows: result.rows,           // ⬅ REAL BalanceRow list
      );

      notifyListeners();
    } catch (e) {
      _ui = _ui.copyWith(
        loading: false,
        error: e.toString(),
      );
      notifyListeners();
    }
  }

  // ----------------------------------------------------------------------
  // GENERATE BALANCE REPORT PDF (Flutter equivalent of Kotlin renderMatrix)
  // ----------------------------------------------------------------------
  Future<File?> generateBalanceReport() async {
    try {
      if (_ui.rows.isEmpty || _ui.currencies.isEmpty) return null;

      final file = await ReportPdfService.instance.renderBalanceReport(
        currencies: _ui.currencies,
        rows: _ui.rows,      // <-- LIST<BalanceRow>
      );

      return file;
    } catch (e) {
      _ui = _ui.copyWith(error: e.toString());
      notifyListeners();
      return null;
    }
  }

  // ----------------------------------------------------------------------
  // PLACEHOLDERS (we will implement later)
  // ----------------------------------------------------------------------
  Future<File?> generateCreditReport() async => null;

  Future<File?> generateDebitReport() async => null;

  Future<File?> generatePendingReport() async => null;
}