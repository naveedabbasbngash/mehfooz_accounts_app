import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';

import 'package:mehfooz_accounts_app/theme/app_colors.dart';
import '../../model/pending_row.dart';
import '../../services/pdf/pending_pdf_service.dart';
import '../../viewmodel/home/not_paid_view_model.dart';
import '../../model/pending_group_row.dart';
import 'widgets/pending_group_list.dart';
import 'widgets/pending_search_bar.dart';

class NotPaidGroupedScreen extends StatefulWidget {
  final String? filterCurrency;

  const NotPaidGroupedScreen({super.key, this.filterCurrency});

  @override
  State<NotPaidGroupedScreen> createState() => _NotPaidGroupedScreenState();
}

class _NotPaidGroupedScreenState extends State<NotPaidGroupedScreen> {
  String query = "";
  DateTime? startDate;
  DateTime? endDate;
  String statusFilter = "ALL";

  bool selectionMode = false;
  final Set<PendingGroupRow> _selectedRows = {};

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<NotPaidViewModel>(context);
    List<PendingGroupRow> rows = vm.rows;

    // Currency Filter
    if (widget.filterCurrency != null) {
      rows = rows
          .where((r) => (r.accTypeName ?? "").toLowerCase() ==
          widget.filterCurrency!.toLowerCase())
          .toList();
    }

    // Status filter
    rows = rows.where((r) {
      if (statusFilter == "PAID") return r.balance == 0;
      if (statusFilter == "NOTPAID") return r.balance != 0;
      return true;
    }).toList();

    // Date filter
    if (startDate != null && endDate != null) {
      rows = rows.where((r) {
        final date = DateTime.tryParse(r.beginDate);
        if (date == null) return false;
        return date.isAfter(startDate!.subtract(const Duration(days: 1))) &&
            date.isBefore(endDate!.add(const Duration(days: 1)));
      }).toList();
    }

    // Search Filter
    final q = query.trim().toLowerCase();
    final isNumeric = double.tryParse(q) != null;

    final filtered = rows.where((r) {
      if (q.isEmpty) return true;

      final sender = (r.sender ?? "").toLowerCase();
      final receiver = (r.receiver ?? "").toLowerCase();
      final msgNo = (r.msgNo ?? "").toLowerCase();
      final accType = (r.accTypeName ?? "").toLowerCase();
      final beginDate = r.beginDate.toLowerCase();
      final balance = r.balance.toStringAsFixed(2);

      if (isNumeric) {
        return balance == q || balance.startsWith(q);
      }

      return sender.startsWith(q) ||
          receiver.startsWith(q) ||
          msgNo.startsWith(q) ||
          accType.startsWith(q) ||
          beginDate.startsWith(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.app_bg,
      appBar: _buildAppBar(filtered),
      body: Column(
        children: [
          PendingSearchBar(onChanged: (v) => setState(() => query = v)),
          const SizedBox(height: 10),

          Expanded(
            child: PendingGroupList(
              rows: filtered,
              highlight: query,
              selectionMode: selectionMode,
              selectedRows: _selectedRows,
              onToggleSelection: _toggleRowSelection,
              onLongPressToSelect: _startSelectionFromRow,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================
  AppBar _buildAppBar(List<PendingGroupRow> filtered) {
    if (selectionMode) {
      return AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.close, color: AppColors.textDark),
          onPressed: _clearSelection,
        ),
        title: Text(
          "${_selectedRows.length} selected",
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: AppColors.primary),
            onPressed: _selectedRows.isEmpty ? null : _exportSelected,
          ),
        ],
      );
    }

    return AppBar(
      backgroundColor: AppColors.cardBackground,
      elevation: 1,
      title: Text(
        widget.filterCurrency == null
            ? "Pending Amounts"
            : "${widget.filterCurrency} – Pending",
        style: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: IconThemeData(color: AppColors.textDark),
      actions: [
        IconButton(
          icon: Icon(Icons.picture_as_pdf_outlined, color: AppColors.primary),
          onPressed: filtered.isEmpty ? null : () => _exportAll(filtered),
        ),
        IconButton(
          icon: Icon(Icons.filter_list, color: AppColors.primary),
          onPressed: _openFilterSheet,
        ),
      ],
    );
  }

  // ============================================================
  // SELECTION HANDLING
  // ============================================================
  void _startSelectionFromRow(PendingGroupRow row) {
    setState(() {
      selectionMode = true;
      _selectedRows.add(row);
    });
  }

  void _toggleRowSelection(PendingGroupRow row) {
    setState(() {
      if (_selectedRows.contains(row)) {
        _selectedRows.remove(row);
      } else {
        _selectedRows.add(row);
      }

      if (_selectedRows.isEmpty) selectionMode = false;
    });
  }

  void _clearSelection() {
    setState(() {
      selectionMode = false;
      _selectedRows.clear();
    });
  }

  // ============================================================
  // EXPORT ALL
  // ============================================================
  Future<void> _exportAll(List<PendingGroupRow> groups) async {
    try {
      final rows = groups.map((g) {
        return PendingRow(
          voucherNo: 0,
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

      final file = await PendingPdfService.instance.render(
        officeName: "Mahfooz Accounts",
        rows: rows,
        title: "Pending Amount (Grouped)",
      );

      await OpenFilex.open(file.path);
    } catch (e) {
      _error("Failed to generate PDF: $e");
    }
  }

  // ============================================================
  // EXPORT SELECTED
  // ============================================================
  Future<void> _exportSelected() async {
    try {
      final rows = _selectedRows.map((g) {
        return PendingRow(
          voucherNo: 0,
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

      final file = await PendingPdfService.instance.render(
        officeName: "Mahfooz Accounts",
        rows: rows,
        title: "Selected Pending Items",
      );

      await OpenFilex.open(file.path);
    } catch (e) {
      _error("Failed to generate PDF: $e");
    }
  }

  // ============================================================
  // FILTER SHEET
  // ============================================================
  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          bottom: true, // 👈 avoids touching system navigation bar
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              20,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: StatefulBuilder(
              builder: (context, sheetSetState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ---------------- DRAG HANDLE ----------------
                    Center(
                      child: Container(
                        height: 5,
                        width: 45,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),

                    // ---------------- TITLE ----------------
                    Text(
                      "Filters",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ---------------- STATUS FILTER ----------------
                    Text(
                      "Status",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),

                    const SizedBox(height: 8),

                    SegmentedButton<String>(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith(
                              (states) =>
                          states.contains(WidgetState.selected)
                              ? AppColors.primary.withOpacity(.15)
                              : AppColors.cardBackground,
                        ),
                        side: WidgetStateProperty.resolveWith(
                              (states) => BorderSide(
                            color: AppColors.primary.withOpacity(
                              states.contains(WidgetState.selected) ? 1 : 0.3,
                            ),
                            width: 1,
                          ),
                        ),
                      ),
                      segments: [
                        ButtonSegment(
                          value: "ALL",
                          label: Text("All",
                              style: TextStyle(color: AppColors.textDark)),
                        ),
                        ButtonSegment(
                          value: "PAID",
                          label: Text("Paid",
                              style: TextStyle(color: AppColors.textDark)),
                        ),
                        ButtonSegment(
                          value: "NOTPAID",
                          label: Text("Not Paid",
                              style: TextStyle(color: AppColors.textDark)),
                        ),
                      ],
                      selected: {statusFilter},
                      onSelectionChanged: (newSet) {
                        sheetSetState(() => statusFilter = newSet.first);
                        setState(() {});
                      },
                    ),

                    const SizedBox(height: 24),

                    // ---------------- DATE RANGE ----------------
                    Text(
                      "Date Range",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.date_range, color: AppColors.primary),
                            label: Text(
                              (startDate == null || endDate == null)
                                  ? "Pick Range"
                                  : "${startDate!.toString().split(' ')[0]} → ${endDate!.toString().split(' ')[0]}",
                              style: TextStyle(color: AppColors.primary),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.divider),
                              padding: const EdgeInsets.all(14),
                            ),
                            onPressed: () async {
                              final picked = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );

                              if (picked != null) {
                                sheetSetState(() {
                                  startDate = picked.start;
                                  endDate = picked.end;
                                });
                                setState(() {});
                              }
                            },
                          ),
                        ),

                        if (startDate != null && endDate != null)
                          IconButton(
                            icon: Icon(Icons.close, color: AppColors.error),
                            onPressed: () {
                              sheetSetState(() {
                                startDate = null;
                                endDate = null;
                              });
                              setState(() {});
                            },
                          ),
                      ],
                    ),

                    const SizedBox(height: 26),

                    // ---------------- APPLY BUTTON ----------------
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "Apply Filters",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white_color,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
  // ============================================================
  // ERROR SNACKBAR
  // ============================================================
  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
      ),
    );
  }
}