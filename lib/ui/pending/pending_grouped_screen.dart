import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/home/not_paid_view_model.dart';
import 'widgets/pending_search_bar.dart';
import 'widgets/pending_group_list.dart';
import '../../model/pending_group_row.dart';

class NotPaidGroupedScreen extends StatefulWidget {
  final String? filterCurrency; // optional currency filter

  const NotPaidGroupedScreen({
    super.key,
    this.filterCurrency,
  });

  @override
  State<NotPaidGroupedScreen> createState() => _NotPaidGroupedScreenState();
}

class _NotPaidGroupedScreenState extends State<NotPaidGroupedScreen> {
  String query = "";

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<NotPaidViewModel>(context);

    // -------------------------------------------------------------
    // 1️⃣ Make rows strongly typed from the start
    // -------------------------------------------------------------
    List<PendingGroupRow> rows = vm.rows;

    // -------------------------------------------------------------
    // 2️⃣ APPLY CURRENCY FILTER FIRST (if coming from Home tap)
    // -------------------------------------------------------------
    if (widget.filterCurrency != null) {
      rows = rows
          .where((r) =>
      (r.accTypeName ?? "").toLowerCase() ==
          widget.filterCurrency!.toLowerCase())
          .toList();
    }

    // -------------------------------------------------------------
    // 3️⃣ APPLY SEARCH FILTER
    // -------------------------------------------------------------
    final List<PendingGroupRow> filtered = rows.where((r) {
      if (query.isEmpty) return true;
      final q = query.toLowerCase();

      return r.beginDate.toLowerCase().contains(q) ||
          (r.msgNo?.toLowerCase().contains(q) ?? false) ||
          (r.sender?.toLowerCase().contains(q) ?? false) ||
          (r.receiver?.toLowerCase().contains(q) ?? false) ||
          (r.accTypeName?.toLowerCase().contains(q) ?? false) ||
          r.notPaidAmount.toString().contains(q) ||
          r.paidAmount.toString().contains(q) ||
          r.balance.toString().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,

      appBar: AppBar(
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
      ),

      body: Column(
        children: [
          PendingSearchBar(
            onChanged: (v) {
              setState(() => query = v);
              vm.toggleShowAll(v.isNotEmpty);
            },
          ),

          const SizedBox(height: 6),

          // -------------------------------------------------------------
          // FIX: Now filtered is List<PendingGroupRow>
          // -------------------------------------------------------------
          Expanded(
            child: PendingGroupList(rows: filtered),
          ),
        ],
      ),
    );
  }
}