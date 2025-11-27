import 'package:flutter/material.dart';
import '../../../viewmodel/home/home_view_model.dart';

class CashInHandCard extends StatelessWidget {
  final HomeViewModel vm;
  final bool isExpanded;
  final VoidCallback onToggle;
  final int maxVisible;

  const CashInHandCard({
    super.key,
    required this.vm,
    required this.isExpanded,
    required this.onToggle,
    this.maxVisible = 5,
  });

  @override
  Widget build(BuildContext context) {
    final rows = vm.cashInHandSummary;
    final hasData = rows.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: hasData
          ? Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleRow(),
          const SizedBox(height: 4),
          Text(
            "Summary by currency",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 16),

          // Expandable list inside card
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: Column(
              children: [
                ..._buildRows(rows),
                if (rows.length > maxVisible)
                  _buildExpandToggle(rows.length - maxVisible),
              ],
            ),
          ),
        ],
      )
          : _emptyState(),
    );
  }

  // ----------------------------------------------------------
  // Title Row
  // ----------------------------------------------------------
  Row _titleRow() {
    return Row(
      children: const [
        Icon(Icons.savings_outlined, color: Colors.deepPurple, size: 22),
        SizedBox(width: 8),
        Text(
          "JB Amount",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // Build visible/hidden rows
  // ----------------------------------------------------------
  List<Widget> _buildRows(List<dynamic> rows) {
    final int total = rows.length;
    final int visibleCount = isExpanded ? total : total.clamp(0, maxVisible);

    return List.generate(visibleCount, (i) {
      final row = rows[i];
      final isPositive = row.amount >= 0;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(row.currency,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
              row.amount.toStringAsFixed(2),
              style: TextStyle(
                color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    });
  }

  // ----------------------------------------------------------
  // Expand / Collapse toggle button
  // ----------------------------------------------------------
  Widget _buildExpandToggle(int hiddenCount) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 18,
              color: Colors.deepPurple,
            ),
            const SizedBox(width: 5),
            Text(
              isExpanded ? "Show less" : "+ $hiddenCount more",
              style: const TextStyle(
                fontSize: 13,
                color: Colors.deepPurple,
                fontWeight: FontWeight.w500,
              ),
            )
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // Empty State UI
  // ----------------------------------------------------------
  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_done_outlined,
              size: 40, color: Colors.deepPurple.shade200),
          const SizedBox(height: 8),
          const Text(
            "Database loaded",
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.deepPurple),
          ),
          const SizedBox(height: 4),
          Text(
            "Cash summary will appear once\ntransaction data is available.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // Card decoration
  // ----------------------------------------------------------
  BoxDecoration get _cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: const [
      BoxShadow(
        color: Color(0x15000000),
        blurRadius: 10,
        offset: Offset(0, 4),
      ),
    ],
    border: Border.all(color: Colors.deepPurple.shade50),
  );
}