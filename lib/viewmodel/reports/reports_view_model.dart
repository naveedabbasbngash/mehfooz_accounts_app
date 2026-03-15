import 'dart:io';
import 'package:flutter/material.dart';

import '../../repository/transactions_repository.dart';
import '../../model/balance_row.dart';
import '../../model/balance_matrix_result.dart';
import '../../model/pending_row.dart';
import '../../model/pending_group_row.dart';

// PDF services
import '../../services/global_state.dart';
import '../../services/pdf/balance_pdf_service.dart';
import '../../services/pdf/credit_pdf_service.dart';
import '../../services/pdf/debit_pdf_service.dart';
import '../../services/pdf/pending_pdf_service.dart';
import '../../services/pdf/subgroup_pdf_service.dart';

/// =====================================================
/// UI STATE
/// =====================================================
class ReportsUiState {
  final bool loading;
  final String? error;
  final String? activeReportKey;

  final List<String> currencies;
  final List<BalanceRow> rows;
  final List<PendingRow> pending;

  const ReportsUiState({
    this.loading = false, // ✅ idle by default
    this.error,
    this.activeReportKey,
    this.currencies = const [],
    this.rows = const [],
    this.pending = const [],
  });

  ReportsUiState copyWith({
    bool? loading,
    String? error,
    String? activeReportKey,
    List<String>? currencies,
    List<BalanceRow>? rows,
    List<PendingRow>? pending,
  }) {
    return ReportsUiState(
      loading: loading ?? this.loading,
      error: error,
      activeReportKey: activeReportKey,
      currencies: currencies ?? this.currencies,
      rows: rows ?? this.rows,
      pending: pending ?? this.pending,
    );
  }
}

/// =====================================================
/// VIEW MODEL
/// =====================================================
class ReportsViewModel extends ChangeNotifier {
  final TransactionsRepository repo;

  // ✅ FIX 1: start idle
  ReportsUiState _ui = const ReportsUiState();
  ReportsUiState get ui => _ui;

  ReportsViewModel({
    required this.repo,
  });

  // =====================================================
  // INTERNAL LOADING HELPERS (simple & safe)
  // =====================================================
  void _startLoading(String reportKey) {
    _ui = _ui.copyWith(
      loading: true,
      error: null,
      activeReportKey: reportKey,
    );
    notifyListeners();
  }

  void _stopLoading() {
    _ui = _ui.copyWith(
      loading: false,
      activeReportKey: null,
    );
    notifyListeners();
  }

  Future<void> _yieldForLoaderFrame() async {
    // Let the loading indicator paint before starting heavier work.
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }

  // =====================================================
  // LOAD BALANCE MATRIX (LAZY, ONLY WHEN NEEDED)
  // =====================================================
  Future<void> loadBalanceMatrix() async {
    final companyId = GlobalState.instance.companyId;
    if (companyId == null) {
      _ui = _ui.copyWith(error: "Please select a company first");
      return;
    }

    final BalanceMatrixResult result =
    await repo.getBalanceMatrix(companyId: companyId);

    _ui = _ui.copyWith(
      currencies: result.currencies,
      rows: result.rows,
    );
  }

  // =====================================================
  // BALANCE REPORT
  // =====================================================
  Future<File?> generateBalanceReport() async {
    try {
      _startLoading('balance');
      await _yieldForLoaderFrame();

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
      return null;
    } finally {
      _stopLoading(); // ✅ always stop
    }
  }

  // =====================================================
  // CREDIT REPORT
  // =====================================================
  Future<File?> generateCreditReport() async {
    try {
      _startLoading('credit');
      await _yieldForLoaderFrame();

      final result = await repo.getCreditMatrix();
      if (result.rows.isEmpty || result.currencies.isEmpty) return null;

      return await CreditPdfService.instance.render(
        currencies: result.currencies,
        rows: result.rows,
      );
    } catch (e) {
      _ui = _ui.copyWith(error: e.toString());
      return null;
    } finally {
      _stopLoading(); // ✅ always stop
    }
  }

  // =====================================================
  // DEBIT REPORT
  // =====================================================
  Future<File?> generateDebitReport() async {
    try {
      _startLoading('debit');
      await _yieldForLoaderFrame();

      // Ensure matrix loaded
      if (_ui.rows.isEmpty || _ui.currencies.isEmpty) {
        await loadBalanceMatrix();
      }
      if (_ui.rows.isEmpty) return null;

      // 🔥 BUILD PURE DEBIT MATRIX
      final List<BalanceRow> debitRows = [];

      for (final row in _ui.rows) {
        final Map<String, double> debitMap = {};

        row.byCurrency.forEach((cur, value) {
          if (value < 0) {
            // 🔑 convert to POSITIVE debit amount
            debitMap[cur] = value.abs();
          }
        });

        if (debitMap.isNotEmpty) {
          debitRows.add(
            BalanceRow(
              name: row.name,
              byCurrency: debitMap,
            ),
          );
        }
      }

      if (debitRows.isEmpty) return null;

      // 🔥 IMPORTANT: rebuild currencies list
      final debitCurrencies = <String>{};
      for (final r in debitRows) {
        debitCurrencies.addAll(r.byCurrency.keys);
      }

      return await DebitPdfService.instance.render(
        currencies: debitCurrencies.toList(),
        rows: debitRows,
      );
    } catch (e) {
      _ui = _ui.copyWith(error: e.toString());
      return null;
    } finally {
      _stopLoading();
    }
  }  // =====================================================
  // PENDING REPORT
  // =====================================================
  Future<File?> generatePendingReport({
    required String officeName,
    required int accId,
    required int companyId,
  }) async {
    try {
      _startLoading('pending');
      await _yieldForLoaderFrame();

      final List<PendingGroupRow> groups = await repo.getPendingGroups(
        accId: accId,
        companyId: companyId,
        statusFilter: 'NOTPAID',
      );

      final rows = groups.map((g) {
        return PendingRow(
          voucherNo: g.voucherNo,
          dateIso: g.beginDate,
          pd: g.pd ?? "",
          msg: g.msgNo ?? "",
          sender: g.sender ?? "",
          receiver: g.receiver ?? "",
          description: "",
          notPaidAmount: g.notPaidAmount,
          paidAmount: g.paidAmount,
          balance: g.balance,
          currency: g.accTypeName ?? "",
        );
      }).toList();

      if (rows.isEmpty) return null;

      return await PendingPdfService.instance.render(
        officeName: officeName,
        rows: rows,
        title: "Pending Amount (Grouped)",
      );
    } catch (e) {
      _ui = _ui.copyWith(error: e.toString());
      return null;
    } finally {
      _stopLoading(); // ✅ always stop
    }
  }

  // =====================================================
  // LAST CREDIT SUMMARY (future)
  // =====================================================
  Future<File?> generateLastCreditSummary() async => null;

  // =====================================================
  // SUBGROUP REPORT
  // =====================================================
  Future<File?> generateSubgroupReport() async {
    try {
      _startLoading('subgroup');
      await _yieldForLoaderFrame();

      final companyId = GlobalState.instance.companyId;
      if (companyId == null) {
        return null;
      }

      final rows = await repo.getSubgroupBalances(companyId: companyId);
      if (rows.isEmpty) return null;

      return await SubgroupPdfService.instance.render(rows: rows);
    } catch (e, s) {
      debugPrint("❌ Subgroup report error: $e");
      debugPrintStack(stackTrace: s);
      _ui = _ui.copyWith(error: e.toString());
      return null;
    } finally {
      _stopLoading();
    }
  }
}
