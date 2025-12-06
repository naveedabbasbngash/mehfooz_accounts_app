import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';

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
  String statusFilter = "ALL"; // ALL | PAID | NOTPAID

  // NEW: selection mode
  bool selectionMode = false;
  final Set<PendingGroupRow> _selectedRows = {};



  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<NotPaidViewModel>(context);
    List<PendingGroupRow> rows = vm.rows;

    // 1️⃣ Currency filter from Home
    if (widget.filterCurrency != null) {
      rows = rows
          .where((r) =>
      (r.accTypeName ?? "").toLowerCase() ==
          widget.filterCurrency!.toLowerCase())
          .toList();
    }

    // 2️⃣ Status filter
    rows = rows.where((r) {
      if (statusFilter == "PAID") return r.balance == 0;
      if (statusFilter == "NOTPAID") return r.balance != 0;
      return true;
    }).toList();

    // 3️⃣ Date range filter
    if (startDate != null && endDate != null) {
      rows = rows.where((r) {
        final date = DateTime.tryParse(r.beginDate);
        if (date == null) return false;

        return date.isAfter(startDate!.subtract(const Duration(days: 1))) &&
            date.isBefore(endDate!.add(const Duration(days: 1)));
      }).toList();
    }

    // 4️⃣ Smart search
    final q = query.trim().toLowerCase();
    final isNumeric = double.tryParse(q) != null;

    final List<PendingGroupRow> filtered = rows.where((r) {
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
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(filtered),
      body: Column(
        children: [
          // 🔍 Search Bar
          PendingSearchBar(
            onChanged: (v) => setState(() => query = v),
          ),
          const SizedBox(height: 10),

          // LIST
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
  // APP BAR (Normal + Selection Mode)
  // ============================================================
  AppBar _buildAppBar(List<PendingGroupRow> filtered) {
    if (selectionMode) {
      // ✅ SELECTION MODE (Gmail style)
      return AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: _clearSelection,
        ),
        title: Text(
          "${_selectedRows.length} selected",
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.deepPurple),
            onPressed: _selectedRows.isEmpty ? null : () => _exportSelected(),
            tooltip: "Export selected to PDF",
          ),
        ],
      );
    }

    // ✅ NORMAL MODE
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      title: Text(
        widget.filterCurrency == null
            ? "Pending Amounts"
            : "${widget.filterCurrency} – Pending",
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.black87),
      actions: [
        // Export all (for current filtered list)
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined,
              color: Colors.deepPurple),
          onPressed:
          filtered.isEmpty ? null : () => _exportAll(filtered),
          tooltip: "Export all to PDF",
        ),

        // Existing filter button
        IconButton(
          icon: const Icon(Icons.filter_list, color: Colors.deepPurple),
          onPressed: () => _openFilterSheet(),
        ),
      ],
    );
  }

  // ============================================================
  // SELECTION HANDLERS
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

      if (_selectedRows.isEmpty) {
        selectionMode = false;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      selectionMode = false;
      _selectedRows.clear();
    });
  }



  Future<void> _exportAll(List<PendingGroupRow> groups) async {
    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No pending rows to export"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      const officeName = "Mahfooz Accounts";

      final rows = groups.map<PendingRow>((g) {
        return PendingRow(
          voucherNo: 0,                     // <-- REQUIRED
          dateIso: g.beginDate,
          pd: g.pd ?? "",
          msg: g.msgNo ?? "",
          sender: g.sender ?? "",
          receiver: g.receiver ?? "",
          description: "",                  // <-- REQUIRED
          notPaidAmount: g.notPaidAmount,
          paidAmount: g.paidAmount,
          balance: g.balance,
          currency: g.accTypeName ?? "",
        );
      }).toList();

      final file = await PendingPdfService.instance.render(
        officeName: officeName,
        rows: rows,
        title: 'Pending Amount (Grouped)',
      );

      await OpenFilex.open(file.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to generate PDF: $e"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }
  Future<void> _exportSelected() async {
    if (_selectedRows.isEmpty) return;

    try {
      const officeName = "Mahfooz Accounts";

      final rows = _selectedRows.map<PendingRow>((g) {
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
        officeName: officeName,
        rows: rows,
        title: 'Selected Pending Items',
      );

      await OpenFilex.open(file.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to generate PDF: $e"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }
  // ===========================================================================
  // 📌 FILTER BOTTOM-SHEET (unchanged from your code)
  // ===========================================================================
  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // drag handle
                  Container(
                    height: 5,
                    width: 45,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),

                  const Text(
                    "Filters",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Status Filter
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Status",
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800)),
                  ),
                  const SizedBox(height: 8),

                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: "ALL",
                        icon: Icon(Icons.all_inbox),
                        label: Text("All"),
                      ),
                      ButtonSegment(
                        value: "PAID",
                        icon: Icon(Icons.check_circle_outline),
                        label: Text("Paid"),
                      ),
                      ButtonSegment(
                        value: "NOTPAID",
                        icon: Icon(Icons.pending_actions),
                        label: Text("Not Paid"),
                      ),
                    ],
                    selected: {statusFilter},
                    onSelectionChanged: (newSet) {
                      sheetSetState(() => statusFilter = newSet.first);
                      setState(() {});
                    },
                  ),

                  const SizedBox(height: 24),

                  // Date Range Filter
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Date Range",
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800)),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.date_range,
                              color: Colors.deepPurple),
                          label: Text(
                            (startDate == null || endDate == null)
                                ? "Pick Range"
                                : "${startDate!.toString().split(' ')[0]} → "
                                "${endDate!.toString().split(' ')[0]}",
                            style:
                            const TextStyle(color: Colors.deepPurple),
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
                          icon: const Icon(Icons.close, color: Colors.red),
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

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Apply Filters",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
}