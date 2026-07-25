import 'package:flutter/material.dart';

import '../../../viewmodel/home/home_view_model.dart';
import '../../commons/fade_slide.dart';

const _kHomeBrandBlue = Color(0xFF1862A3);

class MoneyDashboardCard extends StatelessWidget {
  final HomeViewModel vm;

  const MoneyDashboardCard({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    final cashRows = vm.cashInHandSummary;
    final acc1Rows = vm.acc1CashSummary;

    final double totalCash = _sumAmount(cashRows.map((e) => e.amount));
    final double totalAcc1 = _sumAmount(acc1Rows.map((e) => e.amount));

    return FadeSlide(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF7FBFF)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x140F172A),
              blurRadius: 24,
              offset: Offset(0, 14),
            ),
          ],
          border: Border.all(color: const Color(0xFFD9E6F3)),
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
                    color: _kHomeBrandBlue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.dashboard_outlined,
                    color: _kHomeBrandBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "Money Dashboard",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: Color(0xFF102132),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Text(
              "High-level view of cash and Dr/Cr amounts.",
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
            ),

            const SizedBox(height: 14),

            // Main summary numbers
            Row(
              children: [
                _statPill(
                  label: "Cash In Hand",
                  value: totalCash,
                  color: _kHomeBrandBlue,
                ),
                const SizedBox(width: 10),
                _statPill(
                  label: "DR/CR Amounts",
                  value: totalAcc1,
                  color: _kHomeBrandBlue,
                ),
              ],
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
          color: color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
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
}
