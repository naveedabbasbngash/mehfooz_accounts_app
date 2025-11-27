import 'package:flutter/material.dart';
import '../../../viewmodel/home/home_view_model.dart';

class Acc1SummaryCard extends StatelessWidget {
  final HomeViewModel vm;
  final bool isExpanded;
  final VoidCallback onToggle;
  final int maxVisible;

  const Acc1SummaryCard({
    super.key,
    required this.vm,
    required this.isExpanded,
    required this.onToggle,
    this.maxVisible = 5,
  });

  @override
  Widget build(BuildContext context) {
    final rows = vm.acc1CashSummary;
    final hasData = rows.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: _cardDecoration,
      child: hasData
          ? Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleRow(),
          const SizedBox(height: 4),
          Text(
            "Cash-in-hand only for AccID = 1",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 16),

          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: Column(
              children: [
                ..._buildRows(rows),
                if (rows.length > maxVisible)
                  _expandToggle(rows.length - maxVisible),
              ],
            ),
          ),
        ],
      )
          : _emptyState(),
    );
  }

  // ------------------------------------------------------------
  // Title Row
  // ------------------------------------------------------------
  Row _titleRow() {
    return Row(
      children: const [
        Icon(Icons.account_balance_wallet_outlined,
            color: Colors.deepPurple, size: 22),
        SizedBox(width: 8),
        Text(
          "Cash In Hand",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // Visible / hidden rows handling
  // ------------------------------------------------------------
  List<Widget> _buildRows(List<dynamic> rows) {
    final total = rows.length;
    final visibleCount = isExpanded ? total : total.clamp(0, maxVisible);

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
                color: isPositive
                    ? Colors.green.shade700
                    : Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    });
  }

  // ------------------------------------------------------------
  // Expand / collapse toggle
  // ------------------------------------------------------------
  Widget _expandToggle(int hiddenCount) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
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
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Empty state
  // ------------------------------------------------------------
  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline,
              size: 40, color: Colors.deepPurple.shade200),
          const SizedBox(height: 8),
          const Text(
            "No AccID = 1 data",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "This summary will appear after transactions\nfor AccID = 1 are imported.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Google-style card decoration
  // ------------------------------------------------------------
  BoxDecoration get _cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: const [
      BoxShadow(
        color: Color(0x14000000),
        blurRadius: 10,
        offset: Offset(0, 4),
      ),
    ],
    border: Border.all(color: Colors.deepPurple.shade50),
  );
}