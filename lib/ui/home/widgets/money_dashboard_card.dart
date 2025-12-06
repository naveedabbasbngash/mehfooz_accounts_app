import 'package:flutter/material.dart';

import '../../../viewmodel/home/home_view_model.dart';
import '../../commons/fade_slide.dart';

class MoneyDashboardCard extends StatelessWidget {
  final HomeViewModel vm;

  const MoneyDashboardCard({
    super.key,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    final cashRows = vm.cashInHandSummary;
    final acc1Rows = vm.acc1CashSummary;
    final pendingRows = vm.pendingAmounts;

    final double totalCash =
    _sumAmount(cashRows.map((e) => e.amount));
    final double totalAcc1 =
    _sumAmount(acc1Rows.map((e) => e.amount));
    final double totalPending =
    _sumAmount(pendingRows.map((e) => e.balance));

    // Distinct currencies (from cash rows for pills)
    final currencies = cashRows.map((e) => e.currency).toSet().toList();

    return FadeSlide(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.deepPurple.shade50),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.dashboard_outlined,
                    color: Colors.deepPurple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "Money Dashboard",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Text(
              "High-level view of cash, JB amount & pending balance.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 14),

            // Main summary numbers
            Row(
              children: [
                _statPill(
                  label: "Cash In Hand",
                  value: totalCash,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 10),
                _statPill(
                  label: "JB Amount",
                  value: totalAcc1,
                  color: Colors.blue.shade700,
                ),
              ],
            ),

            const SizedBox(height: 10),

            _statBar(
              label: "Total Pending",
              value: totalPending,
            ),

            const SizedBox(height: 10),

            // Currency tags
            if (currencies.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: currencies
                    .map(
                      (c) => Chip(
                    label: Text(
                      c,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor:
                    Colors.deepPurple.withOpacity(0.06),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 0),
                    materialTapTargetSize:
                    MaterialTapTargetSize.shrinkWrap,
                  ),
                )
                    .toList(),
              ),
            ] else
              Text(
                "Currencies will appear after cash data is available.",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _sumAmount(Iterable<num> values) {
    double sum = 0;
    for (final v in values) {
      sum += v.toDouble();
    }
    return sum;
  }

  Widget _statPill({
    required String label,
    required double value,
    required Color color,
  }) {
    final isPositive = value >= 0;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value.toStringAsFixed(2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isPositive ? color : Colors.red.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBar({
    required String label,
    required double value,
  }) {
    final bool isPositive = value >= 0;
    final double normalized =
    value == 0 ? 0.0 : (value.abs() / (value.abs() + 1)); // 0..1

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: normalized.clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              isPositive ? Colors.orange.shade700 : Colors.red.shade600,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isPositive ? Colors.orange.shade700 : Colors.red.shade700,
          ),
        ),
      ],
    );
  }
}