import 'dart:io';
import 'package:flutter/material.dart';

import '../../repository/transactions_repository.dart';
import '../../repository/pending_repository.dart';  // <-- NEW
import '../../model/balance_row.dart';
import '../../model/balance_matrix_result.dart';
import '../../model/pending_row.dart';

// PDF services
import '../../services/pdf/balance_pdf_service.dart';
import '../../services/pdf/credit_pdf_service.dart';
import '../../services/pdf/debit_pdf_service.dart';
import '../../services/pdf/pending_pdf_service.dart';

class ReportsUiState {
  final bool loading;
  final String? error;

  final List<String> currencies;
  final List<BalanceRow> rows;     // For balance, debit, credit
  final List<PendingRow> pending;  // For pending report

  const ReportsUiState({
    this.loading = false,
    this.error,
    this.currencies = const [],
    this.rows = const [],
    this.pending = const [],
  });

  ReportsUiState copyWith({
    bool? loading,
    String? error,
    List<String>? currencies,
    List<BalanceRow>? rows,
    List<PendingRow>? pending,
  }) {
    return ReportsUiState(
      loading: loading ?? this.loading,
      error: error,
      currencies: currencies ?? this.currencies,
      rows: rows ?? this.rows,
      pending: pending ?? this.pending,
    );
  }
}

class ReportsViewModel extends ChangeNotifier {
  final TransactionsRepository repo;
  final PendingRepository pendingRepo; // <-- NEW REPO FOR PENDING ROWS

  ReportsUiState _ui = const ReportsUiState(loading: true);
  ReportsUiState get ui => _ui;

  ReportsViewModel({
    required this.repo,
    required this.pendingRepo,
  });

  // ----------------------------------------------------------------------
  // LOAD BALANCE MATRIX (for Balance, Debit reports)
  // ----------------------------------------------------------------------
  Future<void> loadBalanceMatrix() async {
    try {
      _ui = _ui.copyWith(loading: true, error: null);
      notifyListeners();

      final BalanceMatrixResult result = await repo.getBalanceMatrix();

      _ui = _ui.copyWith(
        loading: false,
        currencies: result.currencies,
        rows: result.rows,
      );
      notifyListeners();
    } catch (e) {
      _ui = _ui.copyWith(loading: false, error: e.toString());
      notifyListeners();
    }
  }

  // ----------------------------------------------------------------------
  // BALANCE REPORT
  // ----------------------------------------------------------------------
  Future<File?> generateBalanceReport() async {
    try {
      if (_ui.rows.isEmpty || _ui.currencies.isEmpty) {
        await loadBalanceMatrix();
      }
      if (_ui.rows.isEmpty) return null;

      return await BalancePdfService.instance.render(
        currencies: _ui.currencies,
        rows: _ui.rows,
      );
    } catch (e) {
      _ui = _ui.copyWith(error: e.toString());
      notifyListeners();
      return null;
    }
  }

  // ----------------------------------------------------------------------
  // CREDIT REPORT
  // ----------------------------------------------------------------------
  Future<File?> generateCreditReport() async {
    try {
      final result = await repo.getCreditMatrix();
      if (result.rows.isEmpty || result.currencies.isEmpty) return null;

      return await CreditPdfService.instance.render(
        currencies: result.currencies,
        rows: result.rows,
      );
    } catch (e) {
      _ui = _ui.copyWith(error: e.toString());
      notifyListeners();
      return null;
    }
  }

  // ----------------------------------------------------------------------
  // DEBIT REPORT (uses same matrix but only negative values)
  // ----------------------------------------------------------------------
  Future<File?> generateDebitReport() async {
    try {
      if (_ui.rows.isEmpty || _ui.currencies.isEmpty) {
        await loadBalanceMatrix();
      }
      if (_ui.rows.isEmpty) return null;

      return await DebitPdfService.instance.render(
        currencies: _ui.currencies,
        rows: _ui.rows,
      );
    } catch (e) {
      _ui = _ui.copyWith(error: e.toString());
      notifyListeners();
      return null;
    }
  }

  // ----------------------------------------------------------------------
  // PENDING REPORT
  // ----------------------------------------------------------------------
  Future<File?> generatePendingReport({
    required String officeName,
    required int accId,
    required int companyId,
  }) async {
    try {
      _ui = _ui.copyWith(loading: true, error: null);
      notifyListeners();

      // Fetch from PendingRepository (Drift)
      final List<PendingRow> rows = await pendingRepo.getPendingRows(
        accId: accId,
        companyId: companyId,
      );

      _ui = _ui.copyWith(
        loading: false,
        pending: rows,
      );
      notifyListeners();

      if (rows.isEmpty) return null;

      // Generate PDF
      return await PendingPdfService.instance.render(
        officeName: officeName,
        rows: rows,
      );
    } catch (e) {
      _ui = _ui.copyWith(loading: false, error: e.toString());
      notifyListeners();
      return null;
    }
  }

  // ----------------------------------------------------------------------
  // LAST CREDIT SUMMARY (future work)
  // ----------------------------------------------------------------------
  Future<File?> generateLastCreditSummary() async => null;
}