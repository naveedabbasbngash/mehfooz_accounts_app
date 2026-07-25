import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../model/pending_currency_summary.dart';
import '../../../model/pending_status_summary.dart';
import '../../../theme/app_colors.dart';

class PendingStatusSummaryCard extends StatefulWidget {
  final PendingStatusSummary summary;
  final bool showCurrencyBreakdown;
  final List<PendingCurrencySummary> currencySummaries;

  const PendingStatusSummaryCard({
    super.key,
    required this.summary,
    this.showCurrencyBreakdown = false,
    this.currencySummaries = const [],
  });

  @override
  State<PendingStatusSummaryCard> createState() =>
      _PendingStatusSummaryCardState();
}

class _PendingStatusSummaryCardState extends State<PendingStatusSummaryCard> {
  bool _expanded = false;
  static const double _amountColWidth = 108;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.##');
    final hasMoreThanTwo = widget.currencySummaries.length > 2;
    final firstTwo = widget.currencySummaries.take(2).toList();
    final remaining = widget.currencySummaries.skip(2).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF4FAF4),
            AppColors.cardBackground,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.showCurrencyBreakdown)
            const SizedBox(height: 12),
          if (!widget.showCurrencyBreakdown)
            Row(
              children: [
                _tile(
                  title: "Not Paid",
                  amount: fmt.format(widget.summary.notPaidAmount),
                  count: widget.summary.notPaidCount,
                  fg: const Color(0xFFB65A00),
                  bg: const Color(0xFFFFF4E8),
                ),
                const SizedBox(width: 8),
                _tile(
                  title: "Paid",
                  amount: fmt.format(widget.summary.paidAmount),
                  count: widget.summary.paidCount,
                  fg: const Color(0xFF0A8A5B),
                  bg: const Color(0xFFECFBF4),
                ),
              ],
            ),
          if (widget.showCurrencyBreakdown) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: AppColors.greyLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Currency",
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: _amountColWidth,
                    child: Text(
                      "Not Paid",
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: const Color(0xFFB65A00),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: _amountColWidth,
                    child: Text(
                      "Paid",
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: const Color(0xFF0A8A5B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            if (widget.currencySummaries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  "No currency summary available",
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ...firstTwo.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _currencyRow(
                  currency: r.currency,
                  notPaid: fmt.format(r.notPaidAmount),
                  paid: fmt.format(r.paidAmount),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOutCubic,
              child: _expanded
                  ? Column(
                      children: remaining
                          .map(
                            (r) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: _currencyRow(
                                currency: r.currency,
                                notPaid: fmt.format(r.notPaidAmount),
                                paid: fmt.format(r.paidAmount),
                              ),
                            ),
                          )
                          .toList(),
                    )
                  : const SizedBox.shrink(),
            ),
            if (hasMoreThanTwo)
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: AnimatedRotation(
                      turns: _expanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _tile({
    required String title,
    required String amount,
    required int count,
    required Color fg,
    required Color bg,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: fg.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  amount,
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "$count item${count == 1 ? '' : 's'}",
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _currencyRow({
    required String currency,
    required String notPaid,
    required String paid,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              currency,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          SizedBox(
            width: _amountColWidth,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                notPaid,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: const Color(0xFFB65A00),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _amountColWidth,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                paid,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: const Color(0xFF0A8A5B),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
