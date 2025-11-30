// lib/viewmodel/reports/pending_report_view_model.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../model/pending_row.dart';
import '../../repository/pending_repository.dart';
import '../../services/pdf/pending_pdf_service.dart';

class PendingReportViewModel extends ChangeNotifier {
  final PendingRepository repo;

  bool loading = false;
  String? error;
  List<PendingRow> rows = [];

  PendingReportViewModel(this.repo);

  Future<void> load(int accId, int companyId) async {
    try {
      loading = true;
      error = null;
      notifyListeners();

      rows = await repo.getPendingRows(accId: accId, companyId: companyId);

      loading = false;
      notifyListeners();
    } catch (e) {
      loading = false;
      error = e.toString();
      notifyListeners();
    }
  }

  Future<File?> generate({required String officeName}) async {
    if (rows.isEmpty) return null;

    return await PendingPdfService.instance.render(
      officeName: officeName,
      rows: rows,
    );
  }
}